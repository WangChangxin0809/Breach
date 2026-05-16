extends CharacterBody2D
class_name CharacterBase

# 角色通用基座：所有具体角色（scout/medic/bomber ...）都继承本场景。
# 职责：
#   1. 持有共用组件（Health / HealthBar / Movement / Vision 等）—— 第 2 周起陆续挂载
#   2. 承接服务器权威状态（位置、阵营、血量）并 apply 到本地节点
#   3. 提供两个技能挂载槽（Basic / Ultimate），由子角色场景挂具体技能脚本
# 原则：不写死任何数值；权威数值由服务器 characters.go 决定。

signal health_changed(current: int, maximum: int)
signal died()
signal respawned()

@export var local_movement_enabled := false
@export var movement_bounds := Rect2(Vector2.ZERO, Config.MAP_SIZE)
@export var max_health := 100
@export var respawn_delay := 1.5
@export var move_speed := Config.PLAYER_MOVE_SPEED
@export var push_force := 50.0
@export var sprite_node_path := NodePath("AnimatedSprite2D")
@export var weapon_node_path := NodePath("WeaponPivot")
@export var idle_animation: StringName = &"Idle"
@export var run_animation: StringName = &"Run"
@export var default_facing := Vector2.RIGHT
@export var use_custom_cursor := false
@export var custom_cursor: Texture2D
@export var custom_cursor_hotspot := Vector2(16.0, 16.0)

@onready var sprite: AnimatedSprite2D = get_node_or_null(sprite_node_path) as AnimatedSprite2D
@onready var weapon: Node2D = get_node_or_null(weapon_node_path) as Node2D
@onready var ability_basic: Node = get_node_or_null("AbilitySlot/Basic")
@onready var ability_ultimate: Node = get_node_or_null("AbilitySlot/Ultimate")

var user_id: String = ""
var faction: int = 0
var current_health := 100
var is_dead := false
var alive_modulate := Color.WHITE

func _ready() -> void:
	current_health = max_health
	if sprite:
		alive_modulate = sprite.modulate
	if use_custom_cursor and custom_cursor:
		Input.set_custom_mouse_cursor(custom_cursor, Input.CURSOR_ARROW, custom_cursor_hotspot)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_input_actions()
	set_facing(default_facing)
	health_changed.emit(current_health, max_health)

func _physics_process(delta: float) -> void:
	if not local_movement_enabled or is_dead:
		return
	var direction := _movement_input_vector()
	_apply_local_movement(direction, delta)
	if direction != Vector2.ZERO:
		default_facing = direction.normalized()
	face_position(get_global_mouse_position())
	set_moving(direction != Vector2.ZERO)

# 服务器权威状态回调：由网络层在收到广播后调用。
# state 键暂定：position / user_id / faction / health（后续随 proto 扩展）。
func apply_authoritative_state(state: Dictionary) -> void:
	if state.has("position"):
		position = state["position"]
	if state.has("user_id"):
		user_id = state["user_id"]
	if state.has("faction"):
		faction = state["faction"]
	if state.has("health"):
		set_health(state["health"])

func face_position(world_position: Vector2) -> void:
	set_facing(world_position - global_position)

func set_facing(facing: Vector2) -> void:
	if facing.length_squared() <= 0.001:
		return
	default_facing = facing.normalized()
	var faces_left := default_facing.x < -0.01
	if sprite:
		sprite.flip_h = not faces_left
	if weapon:
		if weapon.has_method("set_facing"):
			weapon.call("set_facing", default_facing)
		else:
			_apply_legacy_weapon_facing(weapon, default_facing, faces_left)

func set_moving(moving: bool) -> void:
	if moving:
		_play_animation(run_animation, idle_animation)
	else:
		_play_animation(idle_animation, run_animation)

func set_body_modulate(color: Color) -> void:
	if sprite:
		sprite.modulate = color

func set_lights_visible(enabled: bool) -> void:
	for raw_light in find_children("*", "PointLight2D", true, false):
		var light := raw_light as PointLight2D
		if light:
			light.visible = enabled

func set_light_color(color: Color) -> void:
	for raw_light in find_children("*", "PointLight2D", true, false):
		var light := raw_light as PointLight2D
		if light:
			light.color = color

func set_weapon_light_color(color: Color) -> void:
	if weapon and weapon.has_method("set_light_color"):
		weapon.call("set_light_color", color)

func equip_weapon(weapon_scene: PackedScene) -> Node2D:
	if weapon_scene == null:
		return null
	if weapon and is_instance_valid(weapon):
		weapon.queue_free()
	weapon = weapon_scene.instantiate() as Node2D
	if weapon == null:
		return null
	weapon.name = str(weapon_node_path)
	add_child(weapon)
	set_facing(default_facing)
	return weapon

func set_health(value: int) -> void:
	var previous_health := current_health
	current_health = clampi(value, 0, max_health)
	health_changed.emit(current_health, max_health)
	if current_health == 0 and previous_health > 0:
		_set_dead(true)
	elif current_health > 0 and is_dead:
		_set_dead(false)

func apply_damage(amount: int) -> void:
	if amount <= 0 or is_dead:
		return
	set_health(current_health - amount)

func apply_heal(amount: int) -> void:
	if amount <= 0:
		return
	set_health(current_health + amount)

func simulate_death() -> void:
	set_health(0)

func respawn_in_place() -> void:
	set_health(max_health)
	respawned.emit()

func _set_dead(dead: bool) -> void:
	is_dead = dead
	if sprite:
		if is_dead:
			sprite.modulate = Color(0.65, 0.65, 0.65, 0.45)
		else:
			sprite.modulate = alive_modulate
	if is_dead:
		died.emit()

func _apply_local_movement(direction: Vector2, delta: float) -> void:
	if direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		return
	velocity = direction * move_speed
	if get_child_count() > 0:
		move_and_slide()
		_push_rigid_body_colliders()
	else:
		position = _clamp_to_movement_bounds(position + velocity * delta)

func _push_rigid_body_colliders() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is RigidBody2D:
			(collider as RigidBody2D).apply_central_impulse(velocity.normalized() * push_force)

func _movement_input_vector() -> Vector2:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction == Vector2.ZERO:
		direction = Input.get_vector("left", "right", "up", "down")
	return direction

func _play_animation(primary: StringName, fallback: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var animation := primary
	if not sprite.sprite_frames.has_animation(animation):
		animation = fallback
	if not sprite.sprite_frames.has_animation(animation):
		return
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)

func _apply_legacy_weapon_facing(weapon_node: Node2D, facing: Vector2, faces_left: bool) -> void:
	var weapon_sprite := weapon_node.get_node_or_null("WeaponSprite") as Sprite2D
	if weapon_sprite:
		weapon_sprite.flip_v = faces_left
	var pivot_offset := float(weapon_node.get_meta("base_x_offset", absf(weapon_node.position.x)))
	weapon_node.position.x = -pivot_offset if faces_left else pivot_offset
	weapon_node.rotation = facing.angle()

func _clamp_to_movement_bounds(next_position: Vector2) -> Vector2:
	return Vector2(
		clampf(next_position.x, movement_bounds.position.x, movement_bounds.position.x + movement_bounds.size.x),
		clampf(next_position.y, movement_bounds.position.y, movement_bounds.position.y + movement_bounds.size.y)
	)

func _setup_input_actions() -> void:
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
