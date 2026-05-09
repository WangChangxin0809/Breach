extends Node
class_name NetworkClient

signal connected_to_match(match_id: String, user_id: String)
signal authoritative_state_received(state: Dictionary)
signal status_changed(message: String)
signal authenticated(user_id: String, username: String)
signal matchmaker_ticket_received(ticket: String)

var client: NakamaClient
var socket: NakamaSocket
var session: NakamaSession
var match_id := ""
var user_id := ""
var reconnecting := false
var matchmaker_ticket := ""

func _ready() -> void:
	client = Nakama.create_client(Config.SERVER_KEY, Config.SERVER_HOST, Config.SERVER_PORT, "http")

func login(email: String, password: String) -> void:
	status_changed.emit("Authenticating")
	session = await client.authenticate_email_async(email, password, email.get_slice("@", 0), true)
	if session.is_exception():
		status_changed.emit("Auth failed: %s" % str(session.get_exception()))
		return
	user_id = session.user_id
	await _connect_socket()
	if socket == null or not socket.is_connected_to_host():
		return
	status_changed.emit("Authenticated as %s" % session.username)
	authenticated.emit(user_id, session.username)

func start_matchmaking() -> void:
	if socket == null or not socket.is_connected_to_host():
		status_changed.emit("Login before matchmaking")
		return
	if not matchmaker_ticket.is_empty():
		status_changed.emit("Already in matchmaker queue")
		return
	status_changed.emit("Searching for match")
	var ticket = await socket.add_matchmaker_async(
		Config.MATCHMAKER_QUERY,
		Config.MATCHMAKER_MIN_PLAYERS,
		Config.MATCHMAKER_MAX_PLAYERS,
		{},
		{}
	)
	if ticket.is_exception():
		status_changed.emit("Matchmaker failed: %s" % str(ticket.get_exception()))
		return
	matchmaker_ticket = ticket.ticket
	status_changed.emit("Queued for %d-%d players" % [Config.MATCHMAKER_MIN_PLAYERS, Config.MATCHMAKER_MAX_PLAYERS])
	matchmaker_ticket_received.emit(matchmaker_ticket)

func send_move(client_tick: int, position: Vector2, direction: Vector2) -> void:
	if socket == null or match_id.is_empty():
		return
	var payload := ProtobufCodec.encode_move_command(client_tick, position, direction)
	socket.send_match_state_raw_async(match_id, Config.OP_MOVE, payload)

func _connect_socket() -> void:
	status_changed.emit("Connecting socket")
	socket = Nakama.create_socket_from(client)
	socket.received_match_state.connect(_on_match_state)
	socket.received_matchmaker_matched.connect(_on_matchmaker_matched)
	socket.closed.connect(_on_socket_closed)
	var result = await socket.connect_async(session)
	if result.is_exception():
		status_changed.emit("Socket failed: %s" % str(result.get_exception()))
		return
	status_changed.emit("Socket connected")

func _on_matchmaker_matched(matched) -> void:
	status_changed.emit("Match found")
	var joined_match = await socket.join_matched_async(matched)
	if joined_match.is_exception():
		status_changed.emit("Join matched failed: %s" % str(joined_match.get_exception()))
		return
	matchmaker_ticket = ""
	match_id = joined_match.match_id
	status_changed.emit("Joined %s" % match_id)
	connected_to_match.emit(match_id, user_id)

func _join_authoritative_match() -> void:
	status_changed.emit("Creating authoritative match")
	var rpc_result = await client.rpc_async(session, Config.RPC_CREATE_MATCH, "{}")
	if rpc_result.is_exception():
		status_changed.emit("Create match failed: %s" % str(rpc_result.get_exception()))
		return
	var parsed: Variant = JSON.parse_string(rpc_result.payload)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("match_id"):
		status_changed.emit("Create match failed: bad RPC payload")
		return

	status_changed.emit("Joining match")
	var joined_match = await socket.join_match_async(parsed["match_id"])
	if joined_match.is_exception():
		status_changed.emit("Join failed: %s" % str(joined_match.get_exception()))
		return
	match_id = joined_match.match_id
	status_changed.emit("Joined %s" % match_id)
	connected_to_match.emit(match_id, user_id)

func _on_match_state(match_state) -> void:
	if match_state.op_code != Config.OP_GAME_STATE:
		return
	authoritative_state_received.emit(ProtobufCodec.decode_game_state(match_state.binary_data))

func _on_socket_closed() -> void:
	if reconnecting or session == null:
		return
	reconnecting = true
	status_changed.emit("Reconnecting")
	while reconnecting:
		await get_tree().create_timer(1.5).timeout
		await _connect_socket()
		if socket != null and socket.is_connected_to_host():
			if not matchmaker_ticket.is_empty():
				matchmaker_ticket = ""
				await start_matchmaking()
			reconnecting = false
