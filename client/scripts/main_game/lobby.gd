extends Control

const ROOM_SCENE := "res://scenes/main_game/room.tscn"
const GAME_TITLE_SCENE := "res://scenes/main_game/game_title.tscn"

@onready var create_room_button: Button = $Center/MenuVBox/CreateRoomButton
@onready var join_room_button: Button = $Center/MenuVBox/JoinRoomButton
@onready var back_button: Button = $Center/MenuVBox/BackButton
@onready var status_label: Label = $Center/MenuVBox/StatusLabel

@onready var join_overlay: ColorRect = $JoinOverlay
@onready var party_id_input: LineEdit = $JoinOverlay/JoinCenter/JoinPanel/JoinVBox/PartyIdInput
@onready var confirm_button: Button = $JoinOverlay/JoinCenter/JoinPanel/JoinVBox/JoinButtons/ConfirmButton
@onready var cancel_button: Button = $JoinOverlay/JoinCenter/JoinPanel/JoinVBox/JoinButtons/CancelButton
@onready var join_status_label: Label = $JoinOverlay/JoinCenter/JoinPanel/JoinVBox/JoinStatusLabel


func _ready() -> void:
	create_room_button.pressed.connect(_on_create_room_pressed)
	join_room_button.pressed.connect(_on_join_room_pressed)
	back_button.pressed.connect(_on_back_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	_update_account_label()


func _update_account_label() -> void:
	if not AuthManager.is_logged_in():
		status_label.text = "未登录"
		return
	var display_name := AuthManager.username
	if display_name.is_empty():
		display_name = AuthManager.email.get_slice("@", 0)
	status_label.text = "账号：%s" % display_name


func _on_create_room_pressed() -> void:
	if not AuthManager.is_logged_in():
		status_label.text = "请先登录"
		return
	Room.mode = Room.Mode.CREATE
	get_tree().change_scene_to_file(ROOM_SCENE)


func _on_join_room_pressed() -> void:
	if not AuthManager.is_logged_in():
		status_label.text = "请先登录"
		return
	join_overlay.visible = true
	join_status_label.text = ""
	party_id_input.text = ""
	party_id_input.grab_focus()


func _on_confirm_pressed() -> void:
	var entered := party_id_input.text.strip_edges()
	if entered.is_empty():
		join_status_label.text = "请输入房间码"
		return
	Room.mode = Room.Mode.JOIN
	Room.join_target = entered
	get_tree().change_scene_to_file(ROOM_SCENE)


func _on_cancel_pressed() -> void:
	join_overlay.visible = false


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(GAME_TITLE_SCENE)
