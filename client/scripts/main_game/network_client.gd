extends Node
class_name NetworkClient

signal connected_to_match(match_id: String, user_id: String)
signal authoritative_state_received(state: Dictionary)
signal character_select_state_received(state: Dictionary)
signal status_changed(message: String)
signal authenticated(user_id: String, username: String)
signal matchmaker_ticket_received(ticket: String)
signal room_joined(party_id: String)
signal room_presences_received(presences: Array, leader_id: String)
signal room_presence_changed(joins: Array, leaves: Array)
signal room_data_received(op_code: int, sender_id: String, data: String)
signal room_closed()

var client: NakamaClient
var socket: NakamaSocket
var session: NakamaSession
var match_id := ""
var user_id := ""
var reconnecting := false
var matchmaker_ticket := ""
var party_id := ""


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


func create_room() -> void:
	if socket == null or not socket.is_connected_to_host():
		status_changed.emit("Login before creating room")
		return
	status_changed.emit("Creating room")
	var party: NakamaRTAPI.Party = await socket.create_party_async(true, Config.PARTY_MAX_SIZE)
	if party.is_exception():
		status_changed.emit("Create room failed: %s" % str(party.get_exception()))
		return
	party_id = party.party_id
	status_changed.emit("Room created %s" % party_id)
	if party.presences != null and not party.presences.is_empty():
		room_presences_received.emit(party.presences, party.leader.user_id)
	room_joined.emit(party_id)


func join_room(room_code: String) -> void:
	if socket == null or not socket.is_connected_to_host():
		status_changed.emit("Login before joining room")
		return
	status_changed.emit("Joining room %s" % room_code)
	party_id = room_code
	var result = await socket.join_party_async(room_code)
	if result.is_exception():
		party_id = ""
		status_changed.emit("Join room failed: %s" % str(result.get_exception()))
		return
	status_changed.emit("Room joined %s" % party_id)
	room_joined.emit(party_id)


func leave_room() -> void:
	if not matchmaker_ticket.is_empty():
		socket.remove_matchmaker_async(matchmaker_ticket)
		matchmaker_ticket = ""
	if party_id.is_empty():
		return
	await socket.leave_party_async(party_id)
	party_id = ""


func send_room_ready(is_ready: bool, leader_id: String = "") -> void:
	if socket == null or party_id.is_empty():
		return
	var payload := JSON.stringify({"ready": is_ready, "user_id": user_id, "username": _display_name(), "leader_id": leader_id})
	socket.send_party_data_async(party_id, Config.PARTY_OP_READY, payload)


func _display_name() -> String:
	var name: String = AuthManager.username
	if not name.is_empty():
		return name
	return user_id


func start_room_matchmaking() -> void:
	push_warning("[LOG] start_room_matchmaking called ticket=%s" % matchmaker_ticket)
	if socket == null or not socket.is_connected_to_host():
		status_changed.emit("Login before matchmaking")
		return
	if party_id.is_empty():
		status_changed.emit("Not in a room")
		return
	if not matchmaker_ticket.is_empty():
		push_warning("[LOG] start_room_matchmaking SKIP: already has ticket")
		status_changed.emit("Searching for match as party")
		return
	status_changed.emit("Searching for match as party")
	var ticket = await socket.add_matchmaker_party_async(
		party_id,
		Config.MATCHMAKER_QUERY,
		Config.MATCHMAKER_MIN_PLAYERS,
		Config.MATCHMAKER_MAX_PLAYERS,
		{},
		{}
	)
	if ticket.is_exception():
		push_warning("[LOG] PartyMatchmakerAdd FAILED: %s" % str(ticket.get_exception()))
		status_changed.emit("Party matchmaker failed: %s" % str(ticket.get_exception()))
		return
	matchmaker_ticket = ticket.ticket
	push_warning("[LOG] PartyMatchmakerAdd OK ticket=%s" % matchmaker_ticket)
	status_changed.emit("Party queued for %d-%d players" % [Config.MATCHMAKER_MIN_PLAYERS, Config.MATCHMAKER_MAX_PLAYERS])


func cancel_matchmaking() -> void:
	push_warning("[LOG] cancel_matchmaking called ticket=%s" % matchmaker_ticket)
	if not matchmaker_ticket.is_empty():
		push_warning("[LOG] cancel_matchmaking REMOVE ticket=%s" % matchmaker_ticket)
		socket.remove_matchmaker_async(matchmaker_ticket)
	matchmaker_ticket = ""
	status_changed.emit("Matchmaking cancelled")


func join_game_match(game_match_id: String) -> void:
	if socket == null or game_match_id.is_empty():
		return
	if not party_id.is_empty():
		await socket.leave_party_async(party_id)
		party_id = ""
	status_changed.emit("Joining game match")
	var joined = await socket.join_match_async(game_match_id)
	if joined.is_exception():
		status_changed.emit("Join game match failed: %s" % str(joined.get_exception()))
		return
	match_id = joined.match_id
	matchmaker_ticket = ""
	status_changed.emit("Joined game %s" % match_id)
	connected_to_match.emit(match_id, user_id)


func send_idle(client_tick: int, position: Vector2, facing: Vector2) -> void:
	if socket == null or match_id.is_empty():
		return
	var payload := ProtobufCodec.encode_move_command(client_tick, position, facing)
	socket.send_match_state_raw_async(match_id, Config.OP_MOVE, payload)


func send_move(client_tick: int, position: Vector2, direction: Vector2) -> void:
	if socket == null or match_id.is_empty():
		return
	var payload := ProtobufCodec.encode_move_command(client_tick, position, direction)
	socket.send_match_state_raw_async(match_id, Config.OP_MOVE, payload)


func send_character_select(character_id: String) -> void:
	if socket == null or match_id.is_empty():
		status_changed.emit("Cannot lock character before joining match")
		return
	var payload := ProtobufCodec.encode_character_select(character_id)
	socket.send_match_state_raw_async(match_id, Config.OP_CHARACTER_SELECT, payload)


func _connect_socket() -> void:
	status_changed.emit("Connecting socket")
	socket = Nakama.create_socket_from(client)
	socket.received_match_state.connect(_on_match_state)
	socket.received_matchmaker_matched.connect(_on_matchmaker_matched)
	socket.received_party_presence.connect(_on_party_presence)
	socket.received_party_data.connect(_on_party_data)
	socket.received_party_close.connect(_on_party_close)
	socket.closed.connect(_on_socket_closed)
	var result = await socket.connect_async(session)
	if result.is_exception():
		status_changed.emit("Socket failed: %s" % str(result.get_exception()))
		return
	status_changed.emit("Socket connected")


func _on_party_presence(event: NakamaRTAPI.PartyPresenceEvent) -> void:
	if event.party_id != party_id:
		return
	room_presence_changed.emit(event.joins, event.leaves)


func _on_party_data(data: NakamaRTAPI.PartyData) -> void:
	if data.party_id != party_id:
		return
	room_data_received.emit(int(data.op_code), data.presence.user_id, data.data as String)


func _on_party_close(close_event) -> void:
	if close_event.party_id != party_id:
		return
	party_id = ""
	room_closed.emit()


func _on_matchmaker_matched(matched: NakamaRTAPI.MatchmakerMatched) -> void:
	status_changed.emit("Match found")
	if not party_id.is_empty():
		await socket.leave_party_async(party_id)
		party_id = ""
	var joined_match = await socket.join_matched_async(matched)
	if joined_match.is_exception():
		status_changed.emit("Join matched failed: %s" % str(joined_match.get_exception()))
		return
	matchmaker_ticket = ""
	match_id = joined_match.match_id
	status_changed.emit("Joined %s" % match_id)
	connected_to_match.emit(match_id, user_id)


func _on_match_state(match_state: NakamaRTAPI.MatchData) -> void:
	match match_state.op_code:
		Config.OP_GAME_STATE:
			authoritative_state_received.emit(ProtobufCodec.decode_game_state(match_state.binary_data))
		Config.OP_CHARACTER_SELECT_STATE:
			character_select_state_received.emit(ProtobufCodec.decode_character_select_state(match_state.binary_data))


func _on_socket_closed() -> void:
	if reconnecting or session == null:
		return
	reconnecting = true
	var was_matchmaking := not matchmaker_ticket.is_empty()
	status_changed.emit("Reconnecting")
	while reconnecting:
		await get_tree().create_timer(1.5).timeout
		await _connect_socket()
		if socket != null and socket.is_connected_to_host():
			if was_matchmaking:
				matchmaker_ticket = ""
				await start_room_matchmaking()
			reconnecting = false
