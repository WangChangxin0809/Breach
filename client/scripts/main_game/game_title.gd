extends Control

const SINGLE_PRACTICE_SCENE := "res://scenes/test/art_test.tscn"
const ROOM_SCENE := "res://scenes/main_game/room.tscn"

@onready var single_practice_button: Button = $Center/MenuVBox/SinglePracticeButton
@onready var multiplayer_button: Button = $Center/MenuVBox/MultiplayerButton
@onready var settings_button: Button = $Center/MenuVBox/SettingsButton
@onready var status_label: Label = $Center/MenuVBox/StatusLabel

func _ready() -> void:
	single_practice_button.pressed.connect(_on_single_practice_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

func _on_single_practice_pressed() -> void:
	get_tree().change_scene_to_file(SINGLE_PRACTICE_SCENE)

func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file(ROOM_SCENE)

func _on_settings_pressed() -> void:
	status_label.text = "设置功能稍后接入"
