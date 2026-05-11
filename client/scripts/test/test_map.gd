extends Node2D

# 仅提供一张可视的网格占位地图 + 屏幕固定的返回按钮。
# 联网、玩家、生命值等后续由对应模块负责人接入，本文件不处理联网状态清理。

const START_MENU_SCENE := "res://scenes/start_menu.tscn"
const MAP_SIZE := Vector2(1600.0, 1200.0)
const GRID_STEP := 64.0
const GRID_COLOR := Color(0.42, 0.46, 0.52, 1.0)
const BG_COLOR := Color(0.12, 0.13, 0.16, 1.0)
const GRID_LINE_WIDTH := 2.0
const TEST_HEALTH_DELTA := 25

@onready var back_button: Button = get_node_or_null("UILayer/BackButton")
@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var test_character = get_node_or_null("TestCharacter")
@onready var hud_health_bar = get_node_or_null("HudHealthBar")
@onready var damage_button: Button = get_node_or_null("UILayer/HealthControls/DamageButton")
@onready var heal_button: Button = get_node_or_null("UILayer/HealthControls/HealButton")
@onready var death_button: Button = get_node_or_null("UILayer/HealthControls/DeathButton")
@onready var respawn_button: Button = get_node_or_null("UILayer/HealthControls/RespawnButton")

func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if damage_button:
		damage_button.pressed.connect(_on_damage_button_pressed)
	if heal_button:
		heal_button.pressed.connect(_on_heal_button_pressed)
	if death_button:
		death_button.pressed.connect(_on_death_button_pressed)
	if respawn_button:
		respawn_button.pressed.connect(_on_respawn_button_pressed)
	if test_character:
		test_character.movement_bounds = Rect2(Vector2.ZERO, MAP_SIZE)
		test_character.health_changed.connect(_on_character_health_changed)
		test_character.died.connect(_on_character_died)
	queue_redraw()

func _draw() -> void:
	pass
	

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(START_MENU_SCENE)

func _on_damage_button_pressed() -> void:
	if test_character:
		test_character.apply_damage(TEST_HEALTH_DELTA)

func _on_heal_button_pressed() -> void:
	if test_character:
		test_character.apply_heal(TEST_HEALTH_DELTA)

func _on_death_button_pressed() -> void:
	if test_character:
		test_character.simulate_death()

func _on_respawn_button_pressed() -> void:
	if test_character:
		test_character.respawn_in_place()

func _on_character_health_changed(current: int, maximum: int) -> void:
	if hud_health_bar:
		hud_health_bar.set_health(current, maximum)

func _on_character_died() -> void:
	await get_tree().create_timer(test_character.respawn_delay).timeout
	if test_character and test_character.is_dead:
		test_character.respawn_in_place()
