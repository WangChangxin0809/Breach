extends Control

# 测试大厅 / 主菜单：提供进入测试地图、联网原型以及退出的入口。
# 仅负责场景切换，不做任何联网或游戏状态处理。

const TEST_MAP_SCENE := "res://scenes/test/test_map.tscn"
const ONLINE_PROTO_SCENE := "res://scenes/main.tscn"

@onready var test_map_button: Button = get_node_or_null("CenterContainer/VBoxContainer/TestMapButton")
@onready var online_proto_button: Button = get_node_or_null("CenterContainer/VBoxContainer/OnlineProtoButton")
@onready var quit_button: Button = get_node_or_null("CenterContainer/VBoxContainer/QuitButton")

func _ready() -> void:
	if test_map_button:
		test_map_button.pressed.connect(_on_test_map_pressed)
	if online_proto_button:
		online_proto_button.pressed.connect(_on_online_proto_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _on_test_map_pressed() -> void:
	get_tree().change_scene_to_file(TEST_MAP_SCENE)

func _on_online_proto_pressed() -> void:
	get_tree().change_scene_to_file(ONLINE_PROTO_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()
