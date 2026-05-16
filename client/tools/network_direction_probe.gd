extends Node

const PASSWORD := "breach-local-password"
const TIMEOUT_SEC := 30.0

var client_a: NetworkClient
var client_b: NetworkClient
var states_a: Array[Dictionary] = []
var states_b: Array[Dictionary] = []
var connected_count := 0

func _ready() -> void:
	client_a = _make_client("A")
	client_b = _make_client("B")
	add_child(client_a)
	add_child(client_b)

	client_a.connected_to_match.connect(_on_connected_to_match)
	client_b.connected_to_match.connect(_on_connected_to_match)
	client_a.authoritative_state_received.connect(func(state: Dictionary) -> void: states_a.append(state))
	client_b.authoritative_state_received.connect(func(state: Dictionary) -> void: states_b.append(state))
	client_a.status_changed.connect(func(message: String) -> void: print("NETWORK_DIRECTION_PROBE A status: %s" % message))
	client_b.status_changed.connect(func(message: String) -> void: print("NETWORK_DIRECTION_PROBE B status: %s" % message))

	client_a.login("direction-probe-a@breach.local", PASSWORD)
	client_b.login("direction-probe-b@breach.local", PASSWORD)

	if not await _wait_for(func() -> bool: return _socket_ready(client_a) and _socket_ready(client_b), "socket ready"):
		return

	client_a.start_matchmaking()
	client_b.start_matchmaking()

	if not await _wait_for(func() -> bool: return connected_count >= 2, "both clients joined match"):
		return
	if not await _wait_for(func() -> bool: return _latest_with_players(states_a).size() >= 2 and _latest_with_players(states_b).size() >= 2, "two-player state"):
		return

	var local_a := _player_state(_latest_with_players(states_a), client_a.user_id)
	var local_b := _player_state(_latest_with_players(states_b), client_b.user_id)
	client_a.send_idle(1, local_a["position"], Vector2.UP)
	client_b.send_idle(1, local_b["position"], Vector2.LEFT)

	if not await _wait_for(func() -> bool: return _observed_remote_direction(states_a, client_b.user_id, Vector2.LEFT) and _observed_remote_direction(states_b, client_a.user_id, Vector2.UP), "remote directions"):
		return

	var observed_a := _player_state(_latest_with_players(states_a), client_b.user_id)
	var observed_b := _player_state(_latest_with_players(states_b), client_a.user_id)
	print("NETWORK_DIRECTION_PROBE remote_in_a=%s remote_in_b=%s" % [
		str(observed_a.get("direction", Vector2.ZERO)),
		str(observed_b.get("direction", Vector2.ZERO)),
	])
	get_tree().quit(0)

func _make_client(label: String) -> NetworkClient:
	var client := NetworkClient.new()
	client.name = "NetworkDirectionProbe%s" % label
	return client

func _on_connected_to_match(match_id: String, user_id: String) -> void:
	connected_count += 1
	print("NETWORK_DIRECTION_PROBE connected match_id=%s user_id=%s" % [match_id, user_id])

func _socket_ready(client: NetworkClient) -> bool:
	return client.session != null and client.socket != null and client.socket.is_connected_to_host()

func _latest_with_players(states: Array[Dictionary]) -> Dictionary:
	for i in range(states.size() - 1, -1, -1):
		if states[i]["players"].size() >= 2:
			return states[i]
	return {}

func _player_state(state: Dictionary, user_id: String) -> Dictionary:
	for raw_player in state.get("players", []):
		var player: Dictionary = raw_player
		if player["user_id"] == user_id:
			return player
	return {}

func _observed_remote_direction(states: Array[Dictionary], remote_user_id: String, expected: Vector2) -> bool:
	for state in states:
		var player := _player_state(state, remote_user_id)
		if player.is_empty() or not bool(player.get("has_direction", false)):
			continue
		var direction: Vector2 = player.get("direction", Vector2.ZERO)
		if direction.distance_to(expected) < 0.05:
			return true
	return false

func _wait_for(predicate: Callable, label: String) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(TIMEOUT_SEC * 1000.0):
		if predicate.call():
			return true
		await get_tree().process_frame
	push_error("Timed out waiting for %s" % label)
	get_tree().quit(1)
	return false
