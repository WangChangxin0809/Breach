extends Node2D

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

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
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
	_setup_input_actions()
	health_changed.emit(current_health, max_health)

func _physics_process(delta: float) -> void:
	if not local_movement_enabled or is_dead:
		return
	var direction := Input.get_vector("left", "right", "up", "down")
	if direction == Vector2.ZERO:
		return
	position = (position + direction * Config.PLAYER_MOVE_SPEED * delta)

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
