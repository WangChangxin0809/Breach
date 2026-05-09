extends Node2D

# 仅提供一张可视的网格占位地图 + 屏幕固定的返回按钮。
# 联网、玩家、生命值等后续由对应模块负责人接入，本文件不处理联网状态清理。

const START_MENU_SCENE := "res://scenes/start_menu.tscn"
const MAP_SIZE := Vector2(1600.0, 1200.0)
const GRID_STEP := 64.0
const GRID_COLOR := Color(0.42, 0.46, 0.52, 1.0)
const BG_COLOR := Color(0.12, 0.13, 0.16, 1.0)
const GRID_LINE_WIDTH := 2.0

@onready var back_button: Button = get_node_or_null("UILayer/BackButton")
@onready var camera: Camera2D = get_node_or_null("Camera2D")

func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	queue_redraw()

func _draw() -> void:
	var zoom_factor: float = 1.0
	if camera and camera.zoom.x > 0.0:
		zoom_factor = 1.0 / camera.zoom.x
	var grid_width: float = GRID_LINE_WIDTH * zoom_factor
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), BG_COLOR, true)
	var x := 0.0
	while x <= MAP_SIZE.x:
		draw_line(Vector2(x, 0.0), Vector2(x, MAP_SIZE.y), GRID_COLOR, grid_width)
		x += GRID_STEP
	var y := 0.0
	while y <= MAP_SIZE.y:
		draw_line(Vector2(0.0, y), Vector2(MAP_SIZE.x, y), GRID_COLOR, grid_width)
		y += GRID_STEP

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(START_MENU_SCENE)
