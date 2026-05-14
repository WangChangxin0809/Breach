extends Node2D

const PLAYER_SIZE := Vector2(32.0, 32.0)

var network: NetworkClient
var players: Dictionary = {}
var my_user_id := ""
var my_match_id := ""
var local_position := Vector2(120.0, 180.0)
var client_tick := 0
var idle_heartbeat := 0
var latest_round_state := Config.ROUND_WAITING
var latest_round_time := 0.0

var mouse_world_position := Vector2.ZERO

var camera: Camera2D
var hud: CanvasLayer
var status_label: Label
var identity_label: Label
var match_label: Label
var round_label: Label
var player_list: Label

func _ready() -> void:
	network = AuthManager.network
	network.authenticated.connect(_on_authenticated)
	network.connected_to_match.connect(_on_connected_to_match)
	network.authoritative_state_received.connect(_on_authoritative_state)
	network.status_changed.connect(_on_status_changed)
	_setup_input_actions()
	_setup_world_camera()
	_setup_ui()
	if AuthManager.is_logged_in():
		_on_authenticated(AuthManager.user_id, AuthManager.username)
	if not network.match_id.is_empty():
		_on_connected_to_match(network.match_id, network.user_id)
	_on_status_changed("已进入战局")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_world_position = get_global_mouse_position()

func _physics_process(delta: float) -> void:
	var direction := _movement_input_vector()
	if direction == Vector2.ZERO:
		idle_heartbeat += 1
		if idle_heartbeat >= 5:
			idle_heartbeat = 0
			var facing := Vector2.RIGHT
			if mouse_world_position != Vector2.ZERO:
				var to_mouse := (mouse_world_position - local_position)
				if to_mouse.length_squared() > 1.0:
					facing = to_mouse.normalized()
			network.send_idle(client_tick, local_position, facing)
			client_tick += 1
		return
	idle_heartbeat = 0
	var predicted_position := local_position + direction * Config.PLAYER_MOVE_SPEED * delta
	if _is_valid_local_position(predicted_position):
		local_position = predicted_position
		if _is_connected_to_authoritative_match():
			network.send_move(client_tick, local_position, direction)
			client_tick += 1
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Config.MAP_SIZE), Color(0.08, 0.09, 0.1), true)
	for obstacle in Config.SOLID_OBSTACLES:
		draw_rect(obstacle, Color(0.27, 0.29, 0.31), true)

	var my_pos := local_position
	var my_facing := Vector2.RIGHT
	var my_direction_raw := Vector2.RIGHT
	if players.has(my_user_id):
		if players[my_user_id].has("direction"):
			my_direction_raw = players[my_user_id]["direction"]

	if mouse_world_position != Vector2.ZERO:
		var to_mouse := (mouse_world_position - my_pos)
		if to_mouse.length_squared() > 1.0:
			my_facing = to_mouse.normalized()
	else:
		my_facing = my_direction_raw.normalized()
		if my_facing == Vector2.ZERO:
			my_facing = Vector2.RIGHT

	_draw_vision_cone(my_pos, my_facing, Color(1, 1, 1, 0.06))

	if not players.has(my_user_id):
		draw_rect(Rect2(local_position - PLAYER_SIZE * 0.5, PLAYER_SIZE), Color(0.45, 0.78, 1.0), true)
	for player_id in players:
		var player: Dictionary = players[player_id]
		if not player["connected"]:
			continue
		var color := Color(0.2, 0.65, 1.0)
		if player["faction"] == Config.FACTION_DEFENDERS:
			color = Color(1.0, 0.42, 0.27)
		var position: Vector2 = player["position"]
		if player_id != my_user_id:
			if not _is_in_my_vision(my_pos, my_facing, position):
				continue
		if player_id == my_user_id:
			position = local_position
			color = color.lightened(0.25)
		draw_rect(Rect2(position - PLAYER_SIZE * 0.5, PLAYER_SIZE), color, true)
		draw_rect(Rect2(position + Vector2(-18.0, -28.0), Vector2(36.0, 5.0)), Color(0.1, 0.1, 0.1), true)
		draw_rect(Rect2(position + Vector2(-18.0, -28.0), Vector2(36.0 * clampf(float(player["health"]) / 100.0, 0.0, 1.0), 5.0)), Color(0.1, 0.85, 0.3), true)

func _on_authenticated(user_id: String, username: String) -> void:
	my_user_id = user_id
	identity_label.text = "账号：%s\nID：%s" % [username, user_id]

func _on_connected_to_match(match_id: String, user_id: String) -> void:
	my_user_id = user_id
	my_match_id = match_id
	match_label.text = "Match: %s\nMatchmaker: query '%s', %d-%d players" % [
		match_id,
		Config.MATCHMAKER_QUERY,
		Config.MATCHMAKER_MIN_PLAYERS,
		Config.MATCHMAKER_MAX_PLAYERS,
	]

func _on_authoritative_state(state: Dictionary) -> void:
	latest_round_state = state["round_state"]
	latest_round_time = state["round_time_remaining"]
	for player in state["players"]:
		players[player["user_id"]] = player
		if player["user_id"] == my_user_id:
			local_position = player["position"]
	_update_match_ui()
	queue_redraw()

func _on_status_changed(message: String) -> void:
	status_label.text = message

func _setup_world_camera() -> void:
	camera = Camera2D.new()
	camera.position = Config.MAP_SIZE * 0.5
	camera.zoom = Vector2(0.75, 0.75)
	camera.enabled = true
	add_child(camera)

func _setup_ui() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	status_label = Label.new()
	status_label.position = Vector2(18.0, 18.0)
	status_label.custom_minimum_size = Vector2(520.0, 30.0)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(status_label)

	identity_label = Label.new()
	identity_label.position = Vector2(18.0, 52.0)
	identity_label.custom_minimum_size = Vector2(420.0, 72.0)
	hud.add_child(identity_label)

	match_label = Label.new()
	match_label.position = Vector2(18.0, 128.0)
	match_label.custom_minimum_size = Vector2(520.0, 62.0)
	hud.add_child(match_label)

	round_label = Label.new()
	round_label.position = Vector2(18.0, 194.0)
	hud.add_child(round_label)

	player_list = Label.new()
	player_list.position = Vector2(18.0, 222.0)
	player_list.custom_minimum_size = Vector2(520.0, 180.0)
	hud.add_child(player_list)

func _update_match_ui() -> void:
	round_label.text = "Round %s  %.1fs  Players %d" % [_round_name(latest_round_state), latest_round_time, players.size()]
	var lines: Array[String] = []
	for player_id in players:
		var player: Dictionary = players[player_id]
		var tag := "ATK"
		if player["faction"] == Config.FACTION_DEFENDERS:
			tag = "DEF"
		var marker := ""
		if player_id == my_user_id:
			marker = " <- you"
		lines.append("%s  hp:%d  pos:(%.0f, %.0f)%s" % [
			tag,
			player["health"],
			player["position"].x,
			player["position"].y,
			marker,
		])
	player_list.text = "\n".join(lines)

func _setup_input_actions() -> void:
	_add_key_action("ui_left", KEY_A)
	_add_key_action("ui_right", KEY_D)
	_add_key_action("ui_up", KEY_W)
	_add_key_action("ui_down", KEY_S)
	_add_key_action("left", KEY_A)
	_add_key_action("left", KEY_LEFT)
	_add_key_action("right", KEY_D)
	_add_key_action("right", KEY_RIGHT)
	_add_key_action("up", KEY_W)
	_add_key_action("up", KEY_UP)
	_add_key_action("down", KEY_S)
	_add_key_action("down", KEY_DOWN)

func _add_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _movement_input_vector() -> Vector2:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction == Vector2.ZERO:
		direction = Input.get_vector("left", "right", "up", "down")
	return direction

func _is_connected_to_authoritative_match() -> bool:
	return not my_user_id.is_empty() and not my_match_id.is_empty()

func _is_valid_local_position(position: Vector2) -> bool:
	var radius := Config.PLAYER_RADIUS
	if position.x < radius or position.y < radius:
		return false
	if position.x > Config.MAP_SIZE.x - radius or position.y > Config.MAP_SIZE.y - radius:
		return false
	for obstacle in Config.SOLID_OBSTACLES:
		if _circle_rect_intersects(position, radius, obstacle):
			return false
	return true

func _circle_rect_intersects(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.position.x + rect.size.x),
		clampf(center.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return center.distance_to(closest) < radius

func _round_name(round_state: int) -> String:
	match round_state:
		Config.ROUND_PLAYING:
			return "Playing"
		Config.ROUND_ENDED:
			return "Ended"
		_:
			return "Waiting"

func _is_in_my_vision(my_pos: Vector2, my_facing: Vector2, target_pos: Vector2) -> bool:
	var dx := target_pos.x - my_pos.x
	var dy := target_pos.y - my_pos.y
	var dist := sqrt(dx * dx + dy * dy)

	if dist > Config.VISION_CONE:
		return false

	if _line_blocked_by_obstacles(my_pos, target_pos):
		return false

	if dist <= Config.VISION_RADIUS:
		return true

	var target_dir := Vector2(dx / dist, dy / dist)
	var dot := my_facing.dot(target_dir)
	return dot >= cos(Config.VISION_CONE_HALF_ANGLE)

func _line_blocked_by_obstacles(a: Vector2, b: Vector2) -> bool:
	for raw in Config.SOLID_OBSTACLES:
		var obs: Rect2 = raw
		if _point_in_rect(a, obs) or _point_in_rect(b, obs):
			return true
		var top_left: Vector2 = obs.position
		var top_right: Vector2 = Vector2(obs.end.x, obs.position.y)
		var bottom_left: Vector2 = Vector2(obs.position.x, obs.end.y)
		var bottom_right: Vector2 = obs.end
		if _segments_intersect(a, b, top_left, top_right):
			return true
		if _segments_intersect(a, b, top_right, bottom_right):
			return true
		if _segments_intersect(a, b, bottom_left, bottom_right):
			return true
		if _segments_intersect(a, b, top_left, bottom_left):
			return true
	return false

func _point_in_rect(p: Vector2, rect: Rect2) -> bool:
	return p.x >= rect.position.x and p.x <= rect.end.x \
	   and p.y >= rect.position.y and p.y <= rect.end.y

func _segments_intersect(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	var d1 := _orient(q1, q2, p1)
	var d2 := _orient(q1, q2, p2)
	var d3 := _orient(p1, p2, q1)
	var d4 := _orient(p1, p2, q2)

	if d1 * d2 < 0.0 and d3 * d4 < 0.0:
		return true

	if d1 == 0.0 and _on_segment(q1, q2, p1):
		return true
	if d2 == 0.0 and _on_segment(q1, q2, p2):
		return true
	if d3 == 0.0 and _on_segment(p1, p2, q1):
		return true
	if d4 == 0.0 and _on_segment(p1, p2, q2):
		return true

	return false

func _orient(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

func _on_segment(a: Vector2, b: Vector2, c: Vector2) -> bool:
	return minf(a.x, b.x) <= c.x and c.x <= maxf(a.x, b.x) \
	   and minf(a.y, b.y) <= c.y and c.y <= maxf(a.y, b.y)

func _draw_vision_cone(origin: Vector2, facing: Vector2, color: Color) -> void:
	var segments := 16
	var half_angle := Config.VISION_CONE_HALF_ANGLE
	var cone_len := Config.VISION_CONE
	var base_angle := atan2(facing.y, facing.x)

	var points := PackedVector2Array()
	points.append(origin)
	for i in range(segments + 1):
		var angle := base_angle - half_angle + (2.0 * half_angle * float(i) / float(segments))
		points.append(origin + Vector2(cos(angle), sin(angle)) * cone_len)
	draw_polygon(points, [color])

	draw_circle(origin, Config.VISION_RADIUS, Color(1, 1, 1, 0.03))
