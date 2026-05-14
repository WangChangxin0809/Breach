extends Control

const START_MENU_SCENE := "res://scenes/main_game/start_menu.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/main_game/character_select.tscn"
const MAX_PARTY_SIZE := 3

const COLOR_TEXT := Color(0.93, 0.94, 0.88)
const COLOR_MUTED := Color(0.65, 0.68, 0.72)
const COLOR_READY := Color(0.35, 0.86, 0.45)
const COLOR_NOT_READY := Color(1.0, 0.76, 0.35)
const COLOR_HOST := Color(1.0, 0.76, 0.35)
const COLOR_AVATAR := Color(0.28, 0.72, 0.82)
const COLOR_EMPTY_AVATAR := Color(0.34, 0.37, 0.42)

var party_members: Array[Dictionary] = [
	{
		"name": "玩家1",
		"is_host": true,
		"is_ready": false,
	},
]

@onready var back_button: Button = $RootMargin/MainVBox/Header/BackButton
@onready var account_label: Label = $RootMargin/MainVBox/Header/AccountLabel
@onready var party_title_label: Label = $RootMargin/MainVBox/ContentCenter/ContentVBox/PartyPanel/PartyVBox/PartyTitleLabel
@onready var status_label: Label = $RootMargin/MainVBox/ContentCenter/ContentVBox/StatusLabel
@onready var ready_button: Button = $RootMargin/MainVBox/ContentCenter/ContentVBox/FooterButtons/ReadyButton
@onready var start_match_button: Button = $RootMargin/MainVBox/ContentCenter/ContentVBox/FooterButtons/StartMatchButton
@onready var slots: Array[PanelContainer] = [
	$RootMargin/MainVBox/ContentCenter/ContentVBox/PartyPanel/PartyVBox/Slot1,
	$RootMargin/MainVBox/ContentCenter/ContentVBox/PartyPanel/PartyVBox/Slot2,
	$RootMargin/MainVBox/ContentCenter/ContentVBox/PartyPanel/PartyVBox/Slot3,
]

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	start_match_button.pressed.connect(_on_start_match_pressed)
	AuthManager.network.connected_to_match.connect(_on_connected_to_match)
	AuthManager.network.status_changed.connect(_on_network_status_changed)
	_connect_invite_buttons()
	_apply_logged_in_player()
	_refresh_room()

func set_party_members(members: Array[Dictionary]) -> void:
	party_members = members.slice(0, MAX_PARTY_SIZE)
	_refresh_room()

func _apply_logged_in_player() -> void:
	if not AuthManager.is_logged_in():
		account_label.text = "账号：未登录"
		return
	var display_name := AuthManager.username
	if display_name.is_empty():
		display_name = AuthManager.email.get_slice("@", 0)
	account_label.text = "账号：%s" % display_name
	party_members[0]["name"] = display_name

func _connect_invite_buttons() -> void:
	for slot in slots:
		var invite_button := slot.get_node("Slot%sHBox/InviteButton" % slot.name.trim_prefix("Slot")) as Button
		invite_button.pressed.connect(_on_invite_pressed)

func _refresh_room() -> void:
	party_title_label.text = "小队 %d/%d" % [party_members.size(), MAX_PARTY_SIZE]
	for index in range(slots.size()):
		var member := {}
		if index < party_members.size():
			member = party_members[index]
		_refresh_slot(slots[index], member)
	_update_buttons()

func _refresh_slot(slot: PanelContainer, member: Dictionary) -> void:
	var slot_index := slot.name.trim_prefix("Slot")
	var slot_root := slot.get_node("Slot%sHBox" % slot_index)
	var avatar := slot_root.get_node("Avatar") as ColorRect
	var name_label := slot_root.get_node("NameLabel") as Label
	var role_label := slot_root.get_node("RoleLabel") as Label
	var status := slot_root.get_node("StatusLabel") as Label
	var invite_button := slot_root.get_node("InviteButton") as Button

	if member.is_empty():
		avatar.color = COLOR_EMPTY_AVATAR
		name_label.text = "空位"
		name_label.add_theme_color_override("font_color", COLOR_MUTED)
		role_label.text = ""
		status.text = ""
		invite_button.visible = true
		return

	avatar.color = COLOR_AVATAR
	name_label.text = member.get("name", "玩家")
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	role_label.text = "房主" if member.get("is_host", false) else ""
	role_label.add_theme_color_override("font_color", COLOR_HOST)
	status.text = "已准备" if member.get("is_ready", false) else "未准备"
	status.add_theme_color_override("font_color", COLOR_READY if member.get("is_ready", false) else COLOR_NOT_READY)
	invite_button.visible = false

func _update_buttons() -> void:
	var local_ready := false
	if not party_members.is_empty():
		local_ready = party_members[0].get("is_ready", false)
	ready_button.text = "取消准备" if local_ready else "准备"
	start_match_button.disabled = not local_ready

func _on_ready_pressed() -> void:
	if party_members.is_empty():
		return
	party_members[0]["is_ready"] = not party_members[0].get("is_ready", false)
	status_label.text = "已准备，等待开始匹配" if party_members[0]["is_ready"] else "已取消准备"
	_refresh_room()

func _on_start_match_pressed() -> void:
	start_match_button.disabled = true
	status_label.text = "正在开始匹配..."
	AuthManager.network.start_matchmaking()

func _on_invite_pressed() -> void:
	status_label.text = "邀请功能稍后接入"

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(START_MENU_SCENE)

func _on_connected_to_match(_match_id: String, _user_id: String) -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

func _on_network_status_changed(message: String) -> void:
	status_label.text = message
	if message.begins_with("Matchmaker failed") or message.begins_with("Join matched failed"):
		start_match_button.disabled = false
