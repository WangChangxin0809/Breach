extends Node2D

const ART_TEST_SCENE := preload("res://scenes/test/art_test.tscn")
const LOCAL_PREVIEW_ID := "__local_preview"
const NETWORK_PLAYERS_ROOT_NAME := "NetworkPlayers"
const GENERATED_OCCLUDERS_ROOT_NAME := "GeneratedVisionOccluders"
const HEALTH_BAR_WIDTH := 44.0
const HEALTH_BAR_HEIGHT := 5.0
const HEALTH_BAR_OFFSET := Vector2(-22.0, -58.0)
const ATTACKER_COLOR := Color(0.45, 0.78, 1.0, 1.0)
const DEFENDER_COLOR := Color(1.0, 0.42, 0.27, 1.0)
const ATTACKER_LIGHT_COLOR := Color(0.44, 0.72, 1.0, 1.0)
const DEFENDER_LIGHT_COLOR := Color(1.0, 0.48, 0.28, 1.0)
const REMOTE_MOVEMENT_ANIMATION_HOLD_MS := 160
const CIRCLE_OCCLUDER_SEGMENTS := 16
const CAPSULE_OCCLUDER_HALF_SEGMENTS := 8

var network: NetworkClient
var players: Dictionary = {}
var player_visuals: Dictionary = {}
var previous_player_positions: Dictionary = {}
var player_visual_directions: Dictionary = {}
var player_visual_moving_until_ms: Dictionary = {}
var movement_obstacles: Array[Dictionary] = []
var vision_obstacles: Array[Dictionary] = []
var my_user_id := ""
var my_match_id := ""
var local_position := Vector2(320.0, 120.0)
var client_tick := 0
var idle_heartbeat := 0
var latest_round_state := Config.ROUND_WAITING
var latest_round_time := 0.0
var last_local_move_direction := Vector2.RIGHT
var local_authoritative_position_ready := false
var local_visual_moving := false

var mouse_world_position := Vector2.ZERO

var art_world: Node2D
var player_template: Node2D
var network_players_root: Node2D
var generated_vision_occluders: Node2D
var vision_overlay: Node2D
var vision_cone: Polygon2D
var vision_radius: Polygon2D
var camera: Camera2D
var hud: CanvasLayer
var status_label: Label
var identity_label: Label
var match_label: Label
var round_label: Label
var player_list: Label

func _ready() -> void:
	var auth_manager := get_node("/root/AuthManager")
	network = auth_manager.network
	network.authenticated.connect(_on_authenticated)
	network.connected_to_match.connect(_on_connected_to_match)
	network.authoritative_state_received.connect(_on_authoritative_state)
	network.status_changed.connect(_on_status_changed)
	_setup_input_actions()
	_setup_art_world()
	_load_map_geometry()
	_sync_generated_vision_occluders()
	_setup_vision_overlay()
	_setup_world_camera()
	_setup_ui()
	if auth_manager.is_logged_in():
		_on_authenticated(auth_manager.user_id, auth_manager.username)
	if not network.match_id.is_empty():
		_on_connected_to_match(network.match_id, network.user_id)
	_on_status_changed("已进入战局")
	_sync_player_visuals()
	_update_vision_overlay()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_world_position = get_global_mouse_position()

func _physics_process(delta: float) -> void:
	mouse_world_position = get_global_mouse_position()
	var direction := _movement_input_vector()
	var can_move_locally := _can_update_local_position()
	var can_send_to_match := _can_send_local_state()
	var moved_locally := false

	if direction == Vector2.ZERO:
		if can_send_to_match:
			idle_heartbeat += 1
			if idle_heartbeat >= 5:
				idle_heartbeat = 0
				network.send_idle(client_tick, local_position, _local_facing_vector())
				client_tick += 1
		else:
			idle_heartbeat = 0
	elif can_move_locally:
		idle_heartbeat = 0
		last_local_move_direction = direction.normalized()
		var predicted_position := local_position + direction * Config.PLAYER_MOVE_SPEED * delta
		if _is_valid_local_position(predicted_position):
			local_position = predicted_position
			moved_locally = true
			if can_send_to_match:
				network.send_move(client_tick, local_position, _local_facing_vector())
				client_tick += 1
	else:
		idle_heartbeat = 0

	local_visual_moving = moved_locally
	_sync_player_visuals()
	_update_vision_overlay()
	_update_camera(delta)

func _on_authenticated(user_id: String, username: String) -> void:
	my_user_id = user_id
	if identity_label:
		identity_label.text = "账号：%s\nID：%s" % [username, user_id]
	_sync_player_visuals()

func _on_connected_to_match(match_id: String, user_id: String) -> void:
	my_user_id = user_id
	my_match_id = match_id
	local_authoritative_position_ready = false
	local_visual_moving = false
	idle_heartbeat = 0
	client_tick = 0
	if match_label:
		match_label.text = "Match: %s\nMatchmaker: query '%s', %d-%d players" % [
			match_id,
			Config.MATCHMAKER_QUERY,
			Config.MATCHMAKER_MIN_PLAYERS,
			Config.MATCHMAKER_MAX_PLAYERS,
		]
	_sync_player_visuals()

func _on_authoritative_state(state: Dictionary) -> void:
	latest_round_state = state["round_state"]
	latest_round_time = state["round_time_remaining"]

	var active_player_ids := {}
	for raw_player in state["players"]:
		var player: Dictionary = raw_player
		var player_id: String = player["user_id"]
		active_player_ids[player_id] = true
		players[player_id] = player
		_cache_authoritative_direction(player_id, player)
		if player_id == my_user_id:
			_reconcile_local_position(player["position"])

	for player_id in players.keys():
		if not active_player_ids.has(player_id):
			players.erase(player_id)

	_update_match_ui()
	_sync_player_visuals()
	_update_vision_overlay()

func _on_status_changed(message: String) -> void:
	if status_label:
		status_label.text = message

func _setup_art_world() -> void:
	art_world = get_node_or_null("ArtWorld") as Node2D
	if art_world == null:
		art_world = ART_TEST_SCENE.instantiate() as Node2D
		art_world.name = "ArtWorld"
		add_child(art_world)
		move_child(art_world, 0)

	art_world.y_sort_enabled = true
	player_template = art_world.get_node_or_null("Player") as Node2D
	if player_template:
		player_template.visible = false
		_prepare_player_visual(player_template)

	var sample_player := art_world.get_node_or_null("Player_02")
	if sample_player:
		_deactivate_sample_node(sample_player)

	network_players_root = art_world.get_node_or_null(NETWORK_PLAYERS_ROOT_NAME) as Node2D
	if network_players_root == null:
		network_players_root = Node2D.new()
		network_players_root.name = NETWORK_PLAYERS_ROOT_NAME
		network_players_root.y_sort_enabled = true
		art_world.add_child(network_players_root)

func _setup_world_camera() -> void:
	camera = Camera2D.new()
	camera.position = local_position
	camera.zoom = Vector2(1.15, 1.15)
	camera.enabled = true
	add_child(camera)
	camera.make_current()

func _setup_vision_overlay() -> void:
	vision_overlay = Node2D.new()
	vision_overlay.name = "VisionOverlay"
	vision_overlay.z_index = 500
	add_child(vision_overlay)

	vision_cone = Polygon2D.new()
	vision_cone.name = "Cone"
	vision_cone.color = Color(1.0, 1.0, 1.0, 0.05)
	vision_overlay.add_child(vision_cone)

	vision_radius = Polygon2D.new()
	vision_radius.name = "ShortRange"
	vision_radius.color = Color(1.0, 1.0, 1.0, 0.03)
	vision_overlay.add_child(vision_radius)

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
	if round_label == null or player_list == null:
		return
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
		var direction_label := "dir:(--, --)"
		if bool(player.get("has_direction", false)):
			var direction: Vector2 = player.get("direction", Vector2.ZERO)
			direction_label = "dir:(%.2f, %.2f)" % [direction.x, direction.y]
		lines.append("%s  hp:%d  pos:(%.0f, %.0f)  %s%s" % [
			tag,
			player["health"],
			player["position"].x,
			player["position"].y,
			direction_label,
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
	return network != null and not my_user_id.is_empty() and not my_match_id.is_empty()

func _can_update_local_position() -> bool:
	return not _is_connected_to_authoritative_match() or local_authoritative_position_ready

func _can_send_local_state() -> bool:
	return _is_connected_to_authoritative_match() and local_authoritative_position_ready

func _reconcile_local_position(authoritative_position: Vector2) -> void:
	if not local_authoritative_position_ready:
		local_position = authoritative_position
		local_authoritative_position_ready = true
		return

	var correction_delta := authoritative_position - local_position
	var correction_distance := correction_delta.length()
	if correction_distance <= Config.LOCAL_RECONCILE_DEADZONE and _is_valid_local_position(local_position):
		return

	if correction_distance <= Config.LOCAL_RECONCILE_SMOOTH_DISTANCE and _is_valid_local_position(local_position):
		local_position = local_position.lerp(authoritative_position, Config.LOCAL_RECONCILE_SMOOTH_WEIGHT)
		return

	local_position = authoritative_position

func _sync_player_visuals() -> void:
	if network_players_root == null or player_template == null:
		return

	var active_visual_ids := {}
	for player in _current_render_states():
		var player_id: String = player["user_id"]
		if player_id.is_empty():
			continue
		active_visual_ids[player_id] = true
		var visual := player_visuals.get(player_id, null) as Node2D
		if visual == null or not is_instance_valid(visual):
			visual = _create_player_visual(player_id)
		if visual:
			_apply_player_visual_state(visual, player_id, player)

	for player_id in player_visuals.keys():
		if active_visual_ids.has(player_id):
			continue
		var stale_visual := player_visuals[player_id] as Node2D
		if is_instance_valid(stale_visual):
			stale_visual.queue_free()
		player_visuals.erase(player_id)
		previous_player_positions.erase(player_id)
		player_visual_directions.erase(player_id)
		player_visual_moving_until_ms.erase(player_id)

func _current_render_states() -> Array:
	var states: Array = []
	for player_id in players:
		states.append(players[player_id])

	var preview_id := my_user_id
	if preview_id.is_empty():
		preview_id = LOCAL_PREVIEW_ID
	if not players.has(preview_id):
		states.append({
			"user_id": preview_id,
			"display_name": "Local",
			"faction": Config.FACTION_ATTACKERS,
			"position": local_position,
			"health": 100,
			"connected": true,
		})
	return states

func _create_player_visual(player_id: String) -> Node2D:
	var visual := player_template.duplicate() as Node2D
	visual.name = "PlayerVisual_%s" % str(abs(player_id.hash()))
	visual.visible = true
	visual.position = local_position
	_prepare_player_visual(visual)
	visual.add_to_group("Player")
	network_players_root.add_child(visual)
	player_visuals[player_id] = visual
	return visual

func _prepare_player_visual(visual: Node2D) -> void:
	if visual.get_script() != null:
		visual.set_script(null)
	visual.remove_from_group("Player")
	_disable_visual_collisions(visual)
	_remove_visual_cameras(visual)
	_ensure_health_bar(visual)

	var weapon_pivot := visual.get_node_or_null("WeaponPivot") as Node2D
	if weapon_pivot:
		weapon_pivot.set_meta("base_x_offset", absf(weapon_pivot.position.x))

func _disable_visual_collisions(node: Node) -> void:
	if node is CollisionObject2D:
		var collision_object := node as CollisionObject2D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if node is CollisionShape2D:
		var collision_shape := node as CollisionShape2D
		collision_shape.disabled = true
	if node is CollisionPolygon2D:
		var collision_polygon := node as CollisionPolygon2D
		collision_polygon.disabled = true
	for child in node.get_children():
		_disable_visual_collisions(child)

func _remove_visual_cameras(visual: Node) -> void:
	for raw_camera in visual.find_children("*", "Camera2D", true, false):
		var camera_node := raw_camera as Camera2D
		if camera_node == null:
			continue
		var parent := camera_node.get_parent()
		if parent:
			parent.remove_child(camera_node)
		camera_node.free()

func _deactivate_sample_node(node: Node) -> void:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		canvas_item.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_disable_visual_collisions(node)

func _ensure_health_bar(visual: Node2D) -> void:
	if visual.get_node_or_null("HealthBar"):
		return
	var bar := Node2D.new()
	bar.name = "HealthBar"
	bar.position = HEALTH_BAR_OFFSET
	bar.z_index = 100
	visual.add_child(bar)

	var background := Line2D.new()
	background.name = "Background"
	background.width = HEALTH_BAR_HEIGHT
	background.default_color = Color(0.05, 0.06, 0.07, 0.82)
	background.points = PackedVector2Array([Vector2.ZERO, Vector2(HEALTH_BAR_WIDTH, 0.0)])
	bar.add_child(background)

	var fill := Line2D.new()
	fill.name = "Fill"
	fill.width = HEALTH_BAR_HEIGHT
	fill.default_color = Color(0.1, 0.85, 0.3, 1.0)
	fill.points = PackedVector2Array([Vector2.ZERO, Vector2(HEALTH_BAR_WIDTH, 0.0)])
	bar.add_child(fill)

func _apply_player_visual_state(visual: Node2D, player_id: String, player: Dictionary) -> void:
	var is_local := player_id == my_user_id or player_id == LOCAL_PREVIEW_ID
	var position: Vector2 = player["position"]
	if is_local:
		position = local_position

	visual.position = position
	_set_visual_lights_visible(visual, is_local)

	if not bool(player.get("connected", true)):
		visual.visible = false
		return

	if not is_local and not _is_in_my_vision(local_position, _local_facing_vector(), position):
		visual.visible = false
		return

	visual.visible = true
	var previous_position: Vector2 = previous_player_positions.get(player_id, position)
	var movement_delta := position - previous_position
	var moving := _visual_is_moving(player_id, is_local, movement_delta)
	previous_player_positions[player_id] = position

	var facing := _visual_facing_direction(player_id, is_local, movement_delta, bool(player.get("has_direction", false)))
	_apply_visual_facing(visual, facing)
	_apply_visual_animation(visual, moving)
	_apply_visual_faction(visual, int(player.get("faction", Config.FACTION_ATTACKERS)), is_local, int(player.get("health", 100)))
	_apply_visual_health(visual, int(player.get("health", 100)))

func _visual_is_moving(player_id: String, is_local: bool, movement_delta: Vector2) -> bool:
	if is_local:
		return local_visual_moving
	if movement_delta.length_squared() > 0.25:
		player_visual_moving_until_ms[player_id] = Time.get_ticks_msec() + REMOTE_MOVEMENT_ANIMATION_HOLD_MS
		return true
	return int(player_visual_moving_until_ms.get(player_id, 0)) > Time.get_ticks_msec()

func _cache_authoritative_direction(player_id: String, player: Dictionary) -> void:
	if not bool(player.get("has_direction", false)):
		return
	var raw_direction: Variant = player.get("direction", Vector2.ZERO)
	if not raw_direction is Vector2:
		return
	var direction := (raw_direction as Vector2)
	if direction.length_squared() <= 0.001:
		return
	player_visual_directions[player_id] = direction.normalized()

func _visual_facing_direction(player_id: String, is_local: bool, movement_delta: Vector2, has_authoritative_direction: bool) -> Vector2:
	if is_local:
		var facing := _local_facing_vector()
		player_visual_directions[player_id] = facing
		return facing
	if has_authoritative_direction and player_visual_directions.has(player_id):
		return player_visual_directions[player_id]
	if movement_delta.length_squared() > 0.25:
		var direction := movement_delta.normalized()
		player_visual_directions[player_id] = direction
		return direction
	return player_visual_directions.get(player_id, Vector2.RIGHT)

func _local_facing_vector() -> Vector2:
	if mouse_world_position != Vector2.ZERO:
		var to_mouse := mouse_world_position - local_position
		if to_mouse.length_squared() > 1.0:
			return to_mouse.normalized()
	if last_local_move_direction.length_squared() > 0.0:
		return last_local_move_direction.normalized()
	return Vector2.RIGHT

func _apply_visual_facing(visual: Node2D, facing: Vector2) -> void:
	if facing.length_squared() <= 0.001:
		return

	var sprite := visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var weapon_pivot := visual.get_node_or_null("WeaponPivot") as Node2D
	var weapon_sprite: Sprite2D
	if weapon_pivot:
		weapon_sprite = weapon_pivot.get_node_or_null("WeaponSprite") as Sprite2D

	var faces_left := facing.x < -0.01
	if sprite:
		sprite.flip_h = not faces_left
	if weapon_sprite:
		weapon_sprite.flip_v = faces_left
	if weapon_pivot:
		var pivot_offset := float(weapon_pivot.get_meta("base_x_offset", absf(weapon_pivot.position.x)))
		weapon_pivot.position.x = -pivot_offset if faces_left else pivot_offset
		weapon_pivot.rotation = facing.angle()

func _apply_visual_animation(visual: Node2D, moving: bool) -> void:
	var sprite := visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return

	var animation := &"Idle"
	if moving and sprite.sprite_frames.has_animation(&"Run"):
		animation = &"Run"
	elif not sprite.sprite_frames.has_animation(animation):
		return

	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)

func _apply_visual_faction(visual: Node2D, faction: int, is_local: bool, health: int) -> void:
	var body_color := _faction_color(faction)
	if is_local:
		body_color = body_color.lightened(0.18)
	if health <= 0:
		body_color = Color(0.55, 0.55, 0.55, 0.48)

	var sprite := visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.modulate = body_color

	for raw_light in visual.find_children("*", "PointLight2D", true, false):
		var light := raw_light as PointLight2D
		if light:
			light.color = _faction_light_color(faction)

func _apply_visual_health(visual: Node2D, health: int) -> void:
	var ratio := clampf(float(health) / 100.0, 0.0, 1.0)
	var fill := visual.get_node_or_null("HealthBar/Fill") as Line2D
	if fill:
		fill.points = PackedVector2Array([Vector2.ZERO, Vector2(HEALTH_BAR_WIDTH * ratio, 0.0)])
		fill.default_color = Color(0.1, 0.85, 0.3, 1.0) if ratio > 0.3 else Color(0.92, 0.23, 0.18, 1.0)

func _set_visual_lights_visible(visual: Node2D, enabled: bool) -> void:
	for raw_light in visual.find_children("*", "PointLight2D", true, false):
		var light := raw_light as PointLight2D
		if light:
			light.visible = enabled

func _faction_color(faction: int) -> Color:
	if faction == Config.FACTION_DEFENDERS:
		return DEFENDER_COLOR
	return ATTACKER_COLOR

func _faction_light_color(faction: int) -> Color:
	if faction == Config.FACTION_DEFENDERS:
		return DEFENDER_LIGHT_COLOR
	return ATTACKER_LIGHT_COLOR

func _update_camera(delta: float) -> void:
	if camera == null:
		return
	if delta <= 0.0:
		return
	camera.position = camera.position.lerp(local_position, clampf(delta * 8.0, 0.0, 1.0))

func _update_vision_overlay() -> void:
	if vision_cone == null or vision_radius == null:
		return

	var facing := _local_facing_vector()
	var cone_points := PackedVector2Array()
	var cone_segments := 16
	var half_angle := Config.VISION_CONE_HALF_ANGLE
	var base_angle := atan2(facing.y, facing.x)
	cone_points.append(local_position)
	for i in range(cone_segments + 1):
		var angle := base_angle - half_angle + (2.0 * half_angle * float(i) / float(cone_segments))
		cone_points.append(local_position + Vector2(cos(angle), sin(angle)) * Config.VISION_CONE)
	vision_cone.polygon = cone_points

	var radius_points := PackedVector2Array()
	var radius_segments := 32
	for i in range(radius_segments):
		var angle := TAU * float(i) / float(radius_segments)
		radius_points.append(local_position + Vector2(cos(angle), sin(angle)) * Config.VISION_RADIUS)
	vision_radius.polygon = radius_points

func _is_valid_local_position(position: Vector2) -> bool:
	var radius := Config.PLAYER_RADIUS
	if position.x < radius or position.y < radius:
		return false
	if position.x > Config.MAP_SIZE.x - radius or position.y > Config.MAP_SIZE.y - radius:
		return false
	for obstacle in movement_obstacles:
		if _circle_shape_intersects(position, radius, obstacle):
			return false
	return true

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
	for obstacle in vision_obstacles:
		if _segment_intersects_shape(a, b, obstacle):
			return true
	return false

func _sync_generated_vision_occluders() -> void:
	generated_vision_occluders = get_node_or_null(GENERATED_OCCLUDERS_ROOT_NAME) as Node2D
	if generated_vision_occluders == null:
		generated_vision_occluders = Node2D.new()
		generated_vision_occluders.name = GENERATED_OCCLUDERS_ROOT_NAME
		add_child(generated_vision_occluders)

	for child in generated_vision_occluders.get_children():
		generated_vision_occluders.remove_child(child)
		child.free()

	for obstacle in vision_obstacles:
		if _obstacle_has_existing_light_occluder(obstacle):
			continue
		var polygon := _occluder_polygon_for_shape(obstacle)
		if polygon.size() < 3:
			continue

		var occluder_polygon := OccluderPolygon2D.new()
		occluder_polygon.polygon = polygon

		var occluder := LightOccluder2D.new()
		occluder.name = "VisionOccluder_%s" % str(obstacle.get("id", generated_vision_occluders.get_child_count()))
		occluder.occluder = occluder_polygon
		occluder.set_meta("source_path", str(obstacle.get("source_path", "")))
		generated_vision_occluders.add_child(occluder)

func _obstacle_has_existing_light_occluder(obstacle: Dictionary) -> bool:
	var source_path := str(obstacle.get("source_path", ""))
	if source_path.is_empty():
		return false
	var source_node := get_node_or_null(source_path)
	if source_node == null:
		return false
	return _has_light_occluder_near_scene_node(source_node)

func _has_light_occluder_near_scene_node(node: Node) -> bool:
	var current := node
	while current != null and current != self:
		for child in current.get_children():
			if child is LightOccluder2D:
				return true

		var parent := current.get_parent()
		if parent:
			for sibling in parent.get_children():
				if sibling is LightOccluder2D:
					return true
		current = parent
	return false

func _occluder_polygon_for_shape(shape: Dictionary) -> PackedVector2Array:
	match str(shape.get("type", "")):
		"rect":
			var x := float(shape.get("x", 0.0))
			var y := float(shape.get("y", 0.0))
			var w := float(shape.get("w", 0.0))
			var h := float(shape.get("h", 0.0))
			if w <= 0.0 or h <= 0.0:
				return PackedVector2Array()
			return PackedVector2Array([
				Vector2(x, y),
				Vector2(x + w, y),
				Vector2(x + w, y + h),
				Vector2(x, y + h),
			])
		"circle":
			var center := Vector2(float(shape.get("x", 0.0)), float(shape.get("y", 0.0)))
			return _circle_occluder_polygon(center, float(shape.get("radius", 0.0)))
		"capsule":
			var a := _point_dict_to_vector(shape.get("a", {}))
			var b := _point_dict_to_vector(shape.get("b", {}))
			return _capsule_occluder_polygon(a, b, float(shape.get("radius", 0.0)))
		"segment":
			var a := _point_dict_to_vector(shape.get("a", {}))
			var b := _point_dict_to_vector(shape.get("b", {}))
			return _segment_occluder_polygon(a, b, maxf(float(shape.get("radius", 1.0)), 1.0))
		"polygon":
			return PackedVector2Array(_shape_points(shape))
	return PackedVector2Array()

func _circle_occluder_polygon(center: Vector2, radius: float) -> PackedVector2Array:
	if radius <= 0.0:
		return PackedVector2Array()
	var points := PackedVector2Array()
	for i in range(CIRCLE_OCCLUDER_SEGMENTS):
		var angle := TAU * float(i) / float(CIRCLE_OCCLUDER_SEGMENTS)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _capsule_occluder_polygon(a: Vector2, b: Vector2, radius: float) -> PackedVector2Array:
	if radius <= 0.0:
		return PackedVector2Array()
	if a.distance_squared_to(b) <= 0.001:
		return _circle_occluder_polygon(a, radius)

	var axis := (b - a).normalized()
	var normal := Vector2(-axis.y, axis.x)
	var normal_angle := normal.angle()
	var points := PackedVector2Array([a + normal * radius, b + normal * radius])

	for i in range(1, CAPSULE_OCCLUDER_HALF_SEGMENTS + 1):
		var angle := normal_angle + PI * float(i) / float(CAPSULE_OCCLUDER_HALF_SEGMENTS)
		points.append(b + Vector2(cos(angle), sin(angle)) * radius)
	points.append(a - normal * radius)
	for i in range(1, CAPSULE_OCCLUDER_HALF_SEGMENTS + 1):
		var angle := normal_angle + PI + PI * float(i) / float(CAPSULE_OCCLUDER_HALF_SEGMENTS)
		points.append(a + Vector2(cos(angle), sin(angle)) * radius)

	return points

func _segment_occluder_polygon(a: Vector2, b: Vector2, half_width: float) -> PackedVector2Array:
	if a.distance_squared_to(b) <= 0.001 or half_width <= 0.0:
		return PackedVector2Array()
	var axis := (b - a).normalized()
	var normal := Vector2(-axis.y, axis.x) * half_width
	return PackedVector2Array([a + normal, b + normal, b - normal, a - normal])

func _load_map_geometry() -> void:
	movement_obstacles.clear()
	vision_obstacles.clear()

	var file := FileAccess.open(Config.MAP_GEOMETRY_PATH, FileAccess.READ)
	if file == null:
		_load_legacy_obstacles()
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_load_legacy_obstacles()
		return

	var map_data: Dictionary = (parsed as Dictionary).get("map", {})
	var obstacles: Array = map_data.get("obstacles", [])
	if obstacles.is_empty():
		obstacles = _legacy_obstacle_dicts(map_data.get("collision_shapes", []))
	if obstacles.is_empty():
		_load_legacy_obstacles()
		return

	for raw_obstacle in obstacles:
		var obstacle: Dictionary = raw_obstacle
		if bool(obstacle.get("blocks_movement", false)):
			movement_obstacles.append(obstacle)
		if bool(obstacle.get("blocks_vision", false)):
			vision_obstacles.append(obstacle)

func _load_legacy_obstacles() -> void:
	movement_obstacles = []
	vision_obstacles = []
	for rect in Config.SOLID_OBSTACLES:
		var obstacle := _rect_to_shape(rect)
		movement_obstacles.append(obstacle)
		vision_obstacles.append(obstacle)

func _legacy_obstacle_dicts(shapes: Array) -> Array:
	var obstacles := []
	for raw_shape in shapes:
		var shape: Dictionary = raw_shape
		shape["blocks_movement"] = true
		shape["blocks_vision"] = true
		obstacles.append(shape)
	return obstacles

func _rect_to_shape(rect: Rect2) -> Dictionary:
	return {
		"type": "rect",
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
	}

func _circle_shape_intersects(center: Vector2, radius: float, shape: Dictionary) -> bool:
	match str(shape.get("type", "")):
		"rect":
			return _circle_rect_intersects(center, radius, Rect2(
				Vector2(float(shape.get("x", 0.0)), float(shape.get("y", 0.0))),
				Vector2(float(shape.get("w", 0.0)), float(shape.get("h", 0.0)))
			))
		"circle":
			return center.distance_to(Vector2(float(shape.get("x", 0.0)), float(shape.get("y", 0.0)))) < radius + float(shape.get("radius", 0.0))
		"capsule":
			var a := _point_dict_to_vector(shape.get("a", {}))
			var b := _point_dict_to_vector(shape.get("b", {}))
			return _distance_point_to_segment(center, a, b) < radius + float(shape.get("radius", 0.0))
		"segment":
			var a := _point_dict_to_vector(shape.get("a", {}))
			var b := _point_dict_to_vector(shape.get("b", {}))
			return _distance_point_to_segment(center, a, b) < radius
		"polygon":
			return _circle_polygon_intersects(center, radius, _shape_points(shape))
	return false

func _circle_rect_intersects(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.position.x + rect.size.x),
		clampf(center.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return center.distance_to(closest) < radius

func _circle_polygon_intersects(center: Vector2, radius: float, points: Array[Vector2]) -> bool:
	if points.size() < 3:
		return false
	if _point_in_polygon(center, points):
		return true
	for i in range(points.size()):
		if _distance_point_to_segment(center, points[i], points[(i + 1) % points.size()]) < radius:
			return true
	return false

func _segment_intersects_shape(a: Vector2, b: Vector2, shape: Dictionary) -> bool:
	match str(shape.get("type", "")):
		"rect":
			return _segment_intersects_rect(a, b, Rect2(
				Vector2(float(shape.get("x", 0.0)), float(shape.get("y", 0.0))),
				Vector2(float(shape.get("w", 0.0)), float(shape.get("h", 0.0)))
			))
		"circle":
			var center := Vector2(float(shape.get("x", 0.0)), float(shape.get("y", 0.0)))
			return _distance_point_to_segment(center, a, b) <= float(shape.get("radius", 0.0))
		"capsule":
			var p1 := _point_dict_to_vector(shape.get("a", {}))
			var p2 := _point_dict_to_vector(shape.get("b", {}))
			return _segments_intersect(a, b, p1, p2) or _distance_segment_to_segment(a, b, p1, p2) <= float(shape.get("radius", 0.0))
		"segment":
			return _segments_intersect(a, b, _point_dict_to_vector(shape.get("a", {})), _point_dict_to_vector(shape.get("b", {})))
		"polygon":
			return _segment_intersects_polygon(a, b, _shape_points(shape))
	return false

func _segment_intersects_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if _point_in_rect(a, rect) or _point_in_rect(b, rect):
		return true
	var top_left: Vector2 = rect.position
	var top_right: Vector2 = Vector2(rect.end.x, rect.position.y)
	var bottom_left: Vector2 = Vector2(rect.position.x, rect.end.y)
	var bottom_right: Vector2 = rect.end
	return _segments_intersect(a, b, top_left, top_right) \
		or _segments_intersect(a, b, top_right, bottom_right) \
		or _segments_intersect(a, b, bottom_left, bottom_right) \
		or _segments_intersect(a, b, top_left, bottom_left)

func _segment_intersects_polygon(a: Vector2, b: Vector2, points: Array[Vector2]) -> bool:
	if points.size() < 3:
		return false
	if _point_in_polygon(a, points) or _point_in_polygon(b, points):
		return true
	for i in range(points.size()):
		if _segments_intersect(a, b, points[i], points[(i + 1) % points.size()]):
			return true
	return false

func _shape_points(shape: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for raw_point in shape.get("points", []):
		points.append(_point_dict_to_vector(raw_point))
	return points

func _point_dict_to_vector(raw_point: Variant) -> Vector2:
	if typeof(raw_point) != TYPE_DICTIONARY:
		return Vector2.ZERO
	var point: Dictionary = raw_point
	return Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0)))

func _point_in_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	var inside := false
	var j := polygon.size() - 1
	for i in range(polygon.size()):
		var pi := polygon[i]
		var pj := polygon[j]
		if (pi.y > point.y) != (pj.y > point.y):
			var x_at_y := (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x
			if point.x < x_at_y:
				inside = not inside
		j = i
	return inside

func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared == 0.0:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_to(a + ab * t)

func _distance_segment_to_segment(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if _segments_intersect(a, b, c, d):
		return 0.0
	return minf(
		minf(_distance_point_to_segment(a, c, d), _distance_point_to_segment(b, c, d)),
		minf(_distance_point_to_segment(c, a, b), _distance_point_to_segment(d, a, b))
	)

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
