extends SceneTree

const TIMEOUT_SEC := 35.0

var _scene: Node
var _network: Node
var _connected := false
var _received_state := false
var _received_two_players := false
var _status_messages: Array[String] = []

func _initialize() -> void:
	var packed_scene := load("res://scenes/main.tscn")
	if packed_scene == null:
		push_error("Failed to load main scene")
		quit(1)
		return

	_scene = packed_scene.instantiate()
	root.add_child(_scene)
	await process_frame

	_network = _scene.get("network")
	if _network == null:
		push_error("Main scene did not expose a network client")
		quit(1)
		return

	_network.connected_to_match.connect(_on_connected_to_match)
	_network.authoritative_state_received.connect(_on_authoritative_state)
	_network.status_changed.connect(_on_status_changed)

	var email_input: LineEdit = _scene.get("email_input")
	var password_input: LineEdit = _scene.get("password_input")
	email_input.text = _arg_value("--email", "mcp-test-1@breach.local")
	password_input.text = "breach-local-password"
	_scene.call("_on_login_pressed")

	await _wait_until_ready_for_matchmaking()
	_scene.call("_on_match_pressed")

	await create_timer(TIMEOUT_SEC).timeout

	if not _connected:
		push_error("Timed out before joining Nakama match. Status: %s" % ", ".join(_status_messages))
		quit(1)
		return
	if not _received_state:
		push_error("Timed out before receiving authoritative game state. Status: %s" % ", ".join(_status_messages))
		quit(1)
		return
	if _arg_value("--expect-players", "1").to_int() > 1 and not _received_two_players:
		push_error("Timed out before receiving two-player authoritative state. Status: %s" % ", ".join(_status_messages))
		quit(1)
		return

	print("Godot smoke test passed: joined match and received authoritative state")
	quit(0)

func _on_connected_to_match(match_id: String, user_id: String) -> void:
	print("Smoke test connected_to_match match_id=%s user_id=%s" % [match_id, user_id])
	_connected = true

func _on_authoritative_state(state: Dictionary) -> void:
	print("Smoke test received state tick=%s players=%d" % [state["tick"], state["players"].size()])
	_received_state = true
	if state["players"].size() >= 2:
		_received_two_players = true

func _on_status_changed(message: String) -> void:
	_status_messages.append(message)
	print("Smoke test status: %s" % message)

func _wait_until_ready_for_matchmaking() -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(TIMEOUT_SEC * 1000.0):
		var socket: Variant = _network.get("socket")
		if _network.get("session") != null and socket != null and socket.is_connected_to_host():
			return
		await process_frame

func _arg_value(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
		if args[index].begins_with(name + "="):
			return args[index].trim_prefix(name + "=")
	return fallback
