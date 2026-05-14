extends Control

const SINGLE_PRACTICE_SCENE := "res://scenes/test/art_test.tscn"
const ROOM_SCENE := "res://scenes/main_game/room.tscn"

@onready var single_practice_button: Button = $Center/MenuVBox/SinglePracticeButton
@onready var multiplayer_button: Button = $Center/MenuVBox/MultiplayerButton
@onready var settings_button: Button = $Center/MenuVBox/SettingsButton
@onready var status_label: Label = $Center/MenuVBox/StatusLabel
@onready var login_overlay: ColorRect = $LoginOverlay
@onready var email_input: LineEdit = $LoginOverlay/LoginCenter/LoginPanel/LoginVBox/EmailInput
@onready var password_input: LineEdit = $LoginOverlay/LoginCenter/LoginPanel/LoginVBox/PasswordInput
@onready var login_button: Button = $LoginOverlay/LoginCenter/LoginPanel/LoginVBox/LoginButtons/LoginButton
@onready var cancel_login_button: Button = $LoginOverlay/LoginCenter/LoginPanel/LoginVBox/LoginButtons/CancelButton
@onready var login_status_label: Label = $LoginOverlay/LoginCenter/LoginPanel/LoginVBox/LoginStatusLabel

func _ready() -> void:
	single_practice_button.pressed.connect(_on_single_practice_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	login_button.pressed.connect(_on_login_pressed)
	cancel_login_button.pressed.connect(_on_cancel_login_pressed)
	AuthManager.login_succeeded.connect(_on_login_succeeded)
	AuthManager.login_failed.connect(_on_login_failed)
	AuthManager.status_changed.connect(_on_auth_status_changed)
	email_input.text = AuthManager.email if not AuthManager.email.is_empty() else AuthManager.default_email()
	password_input.text = AuthManager.default_password()

func _on_single_practice_pressed() -> void:
	get_tree().change_scene_to_file(SINGLE_PRACTICE_SCENE)

func _on_multiplayer_pressed() -> void:
	if AuthManager.is_logged_in():
		get_tree().change_scene_to_file(ROOM_SCENE)
		return
	_show_login_prompt()

func _on_settings_pressed() -> void:
	status_label.text = "设置功能稍后接入"

func _show_login_prompt() -> void:
	login_overlay.visible = true
	login_status_label.text = "多人对战需要先登录"
	login_button.disabled = false
	email_input.grab_focus()

func _on_login_pressed() -> void:
	login_button.disabled = true
	login_status_label.text = "正在登录..."
	AuthManager.login(email_input.text, password_input.text)

func _on_cancel_login_pressed() -> void:
	login_overlay.visible = false
	login_button.disabled = false

func _on_login_succeeded(_user_id: String, _username: String) -> void:
	get_tree().change_scene_to_file(ROOM_SCENE)

func _on_login_failed(message: String) -> void:
	login_button.disabled = false
	login_status_label.text = message

func _on_auth_status_changed(message: String) -> void:
	if login_overlay.visible:
		login_status_label.text = message
