class_name Room
extends Control

enum Mode { CREATE, JOIN }
enum State { LOBBY, MATCHMAKING }

static var mode := Mode.CREATE
static var join_target := ""

const LOBBY_SCENE: String = "res://scenes/main_game/lobby.tscn"
const CHARACTER_SELECT_SCENE: String = "res://scenes/main_game/character_select.tscn"

const COLOR_TEXT := Color(0.93, 0.94, 0.88)
const COLOR_MUTED := Color(0.65, 0.68, 0.72)
const COLOR_READY := Color(0.35, 0.86, 0.45)
const COLOR_NOT_READY := Color(1.0, 0.76, 0.35)
const COLOR_HOST := Color(1.0, 0.76, 0.35)
const COLOR_AVATAR := Color(0.28, 0.72, 0.82)
const COLOR_EMPTY_AVATAR := Color(0.34, 0.37, 0.42)

var is_ready: bool = false
var remote_ready_states: Dictionary = {}
var members: Array[Dictionary] = []
var leader_id: String = ""
var room_state: State = State.LOBBY

@onready var back_button: Button = $RootMargin/MainVBox/Header/BackButton
@onready var room_id_label: Label = $RootMargin/MainVBox/Header/RoomIdContainer/RoomIdLabel
@onready var copy_room_button: Button = $RootMargin/MainVBox/Header/RoomIdContainer/CopyRoomButton
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
	copy_room_button.pressed.connect(_on_copy_room_pressed)
	_connect_invite_buttons()
	_connect_network_signals()
	if mode == Mode.CREATE:
		_create_room()
	else:
		_setup_join_mode()
	_update_buttons()


func _connect_invite_buttons() -> void:
	for slot: PanelContainer in slots:
		var slot_name: String = slot.name.trim_prefix("Slot")
		var invite_button: Button = slot.get_node("Slot%sHBox/InviteButton" % slot_name)
		invite_button.pressed.connect(_on_invite_pressed)


func _connect_network_signals() -> void:
	var network := AuthManager.network
	if not network.connected_to_match.is_connected(_on_connected_to_match):
		network.connected_to_match.connect(_on_connected_to_match)
	if not network.room_joined.is_connected(_on_room_joined):
		network.room_joined.connect(_on_room_joined)
	if not network.room_join_failed.is_connected(_on_room_join_failed):
		network.room_join_failed.connect(_on_room_join_failed)
	if not network.room_presences_received.is_connected(_on_room_presences_received):
		network.room_presences_received.connect(_on_room_presences_received)
	if not network.room_presence_changed.is_connected(_on_room_presence_changed):
		network.room_presence_changed.connect(_on_room_presence_changed)
	if not network.room_data_received.is_connected(_on_room_data_received):
		network.room_data_received.connect(_on_room_data_received)
	if not network.room_closed.is_connected(_on_room_closed):
		network.room_closed.connect(_on_room_closed)
	if not network.status_changed.is_connected(_on_network_status_changed):
		network.status_changed.connect(_on_network_status_changed)


func _create_room() -> void:
	if AuthManager.is_logged_in():
		AuthManager.network.create_room()


func _setup_join_mode() -> void:
	if not AuthManager.network.party_id.is_empty():
		Room.join_target = ""
		_on_room_joined(AuthManager.network.party_id)
		return
	if not join_target.is_empty():
		var code := join_target
		join_target = ""
		status_label.text = "正在加入房间..."
		members.clear()
		remote_ready_states.clear()
		AuthManager.network.join_room(code)
		return
	status_label.text = "加入模式：缺少房间码"


func _on_room_joined(pid: String) -> void:
	room_id_label.text = "房间号：%s" % pid
	status_label.text = "已进入房间，等待成员加入"


func _on_room_join_failed(message: String) -> void:
	if mode != Mode.JOIN:
		status_label.text = message
		return
	Room.mode = Mode.CREATE
	Room.join_target = ""
	status_label.text = message
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_room_presences_received(new_presences: Array, new_leader_id: String) -> void:
	print("[UI] presences_received leader=%s" % new_leader_id)
	leader_id = new_leader_id
	for presence in new_presences:
		_upsert_presence(presence)
	_refresh_slots()
	_update_buttons()


func _on_room_presence_changed(joins: Array, leaves: Array) -> void:
	for presence in joins:
		_upsert_presence(presence)
	for presence in leaves:
		_remove_presence(presence)
	if not joins.is_empty():
		AuthManager.network.send_room_ready(is_ready, leader_id)
	_refresh_slots()
	_update_buttons()


func _on_room_data_received(op_code: int, sender_id: String, data: String) -> void:
	if op_code == Config.PARTY_OP_MATCHMAKING:
		if sender_id == AuthManager.network.user_id:
			return
		var parsed: Variant = JSON.parse_string(data)
		if typeof(parsed) != TYPE_DICTIONARY:
			return
		var active: bool = parsed.get("matchmaking", false)
		if active:
			_enter_state(State.MATCHMAKING)
			status_label.text = "正在匹配..."
		else:
			_enter_state(State.LOBBY)
			status_label.text = "匹配已取消"
		return
	if op_code != Config.PARTY_OP_READY or sender_id == AuthManager.network.user_id:
		return
	var parsed: Variant = JSON.parse_string(data)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("ready"):
		return
	var member_ready: bool = parsed["ready"]
	remote_ready_states[sender_id] = member_ready
	var username: String = str(parsed.get("username", sender_id))
	_upsert_member(sender_id, username)
	var broadcast_leader: String = str(parsed.get("leader_id", ""))
	if not broadcast_leader.is_empty() and broadcast_leader != leader_id:
		print("[UI] leader updated from=%s to=%s by=%s" % [leader_id, broadcast_leader, username])
		leader_id = broadcast_leader
	if not member_ready and room_state == State.MATCHMAKING:
		print("[LOG] remote unready triggers cancel sender=%s" % sender_id)
		_enter_state(State.LOBBY)
		status_label.text = username + " 取消了准备，匹配退出"
		AuthManager.network.cancel_matchmaking()
		AuthManager.network.send_room_matchmaking(false)
	_refresh_slots()
	_update_buttons()


func _upsert_member(user_id: String, username: String) -> void:
	if user_id == AuthManager.network.user_id:
		return
	for i in range(members.size()):
		if members[i].get("user_id", "") == user_id:
			members[i]["username"] = username
			return
	members.append({"user_id": user_id, "username": username})


func _upsert_presence(presence) -> void:
	if presence == null:
		return
	var presence_user_id: String = str(presence.user_id)
	if presence_user_id.is_empty() or presence_user_id == AuthManager.network.user_id:
		return
	var username: String = str(presence.username)
	if username.is_empty():
		username = presence_user_id
	_upsert_member(presence_user_id, username)


func _remove_presence(presence) -> void:
	if presence == null:
		return
	var presence_user_id: String = str(presence.user_id)
	for i in range(members.size() - 1, -1, -1):
		if members[i].get("user_id", "") == presence_user_id:
			members.remove_at(i)
	remote_ready_states.erase(presence_user_id)


func _on_room_closed() -> void:
	status_label.text = "房间已解散"
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_copy_room_pressed() -> void:
	var pid: String = AuthManager.network.party_id
	if pid.is_empty():
		return
	DisplayServer.clipboard_set(pid)
	status_label.text = "房间号已复制到剪贴板"


func _refresh_slots() -> void:
	var player_count: int = mini(Config.PARTY_MAX_SIZE, members.size() + 1)
	party_title_label.text = "小队 %d/%d" % [player_count, Config.PARTY_MAX_SIZE]
	_refresh_local_slot(slots[0])
	for index: int in range(1, slots.size()):
		var remote_index: int = index - 1
		var member: Dictionary = members[remote_index] if remote_index < members.size() else {}
		_refresh_remote_slot(slots[index], member)


func _refresh_local_slot(slot: PanelContainer) -> void:
	var slot_root := slot.get_node("Slot1HBox")
	var avatar: ColorRect = slot_root.get_node("Avatar")
	var name_label: Label = slot_root.get_node("NameLabel")
	var role_label: Label = slot_root.get_node("RoleLabel")
	var status_label_node: Label = slot_root.get_node("StatusLabel")
	var invite_button: Button = slot_root.get_node("InviteButton")

	avatar.color = COLOR_AVATAR
	name_label.text = _local_display_name()
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	role_label.text = "房主" if AuthManager.network.user_id == leader_id else ""
	role_label.add_theme_color_override("font_color", COLOR_HOST)
	status_label_node.text = "已准备" if is_ready else "未准备"
	status_label_node.add_theme_color_override("font_color", COLOR_READY if is_ready else COLOR_NOT_READY)
	invite_button.visible = false


func _local_display_name() -> String:
	var name: String = AuthManager.username
	if not name.is_empty():
		return name
	return AuthManager.email.get_slice("@", 0)


func _refresh_remote_slot(slot: PanelContainer, member: Dictionary) -> void:
	var slot_index: String = str(slot.name.trim_prefix("Slot"))
	var slot_root := slot.get_node("Slot%sHBox" % slot_index)
	var avatar: ColorRect = slot_root.get_node("Avatar")
	var name_label: Label = slot_root.get_node("NameLabel")
	var role_label: Label = slot_root.get_node("RoleLabel")
	var status_label_node: Label = slot_root.get_node("StatusLabel")
	var invite_button: Button = slot_root.get_node("InviteButton")

	if member.is_empty():
		avatar.color = COLOR_EMPTY_AVATAR
		name_label.text = "空位"
		name_label.add_theme_color_override("font_color", COLOR_MUTED)
		role_label.text = ""
		status_label_node.text = ""
		invite_button.visible = members.size() + 1 < Config.PARTY_MAX_SIZE
		return

	var user_id: String = member.get("user_id", "")
	var member_ready: bool = remote_ready_states.get(user_id, false)
	avatar.color = COLOR_AVATAR
	name_label.text = member.get("username", "玩家")
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	role_label.text = "房主" if user_id == leader_id else ""
	role_label.add_theme_color_override("font_color", COLOR_HOST)
	status_label_node.text = "已准备" if member_ready else "未准备"
	status_label_node.add_theme_color_override("font_color", COLOR_READY if member_ready else COLOR_NOT_READY)
	invite_button.visible = false


func _update_buttons() -> void:
	ready_button.text = "取消准备" if is_ready else "准备"
	start_match_button.disabled = not _can_start_match()


func _can_start_match() -> bool:
	if room_state != State.LOBBY:
		return false
	if AuthManager.network.user_id != leader_id:
		return false
	if not is_ready:
		return false
	for member: Dictionary in members:
		if not remote_ready_states.get(member.get("user_id", ""), false):
			return false
	return true


func _enter_state(new_state: State) -> void:
	room_state = new_state
	var locked := new_state == State.MATCHMAKING
	back_button.disabled = locked
	ready_button.disabled = locked
	start_match_button.disabled = locked
	for slot: PanelContainer in slots:
		var slot_name: String = slot.name.trim_prefix("Slot")
		var invite: Button = slot.get_node("Slot%sHBox/InviteButton" % slot_name)
		invite.disabled = locked
	if not locked:
		_update_buttons()


func _on_ready_pressed() -> void:
	is_ready = not is_ready
	print("[LOG] ready pressed is_ready=%s room_state=%d" % [str(is_ready), room_state])
	AuthManager.network.send_room_ready(is_ready, leader_id)
	if not is_ready and room_state == State.MATCHMAKING:
		_cancel_matchmaking()
	status_label.text = "已准备，等待开始匹配" if is_ready else "已取消准备"
	_refresh_slots()
	_update_buttons()


func _on_start_match_pressed() -> void:
	print("[LOG] start_match pressed room_state=%d" % room_state)
	if room_state != State.LOBBY:
		return
	start_match_button.disabled = true
	_enter_state(State.MATCHMAKING)
	status_label.text = "正在匹配..."
	AuthManager.network.send_room_matchmaking(true)
	AuthManager.network.start_room_matchmaking()


func _cancel_matchmaking() -> void:
	print("[LOG] cancel_matchmaking room_state=%d" % room_state)
	_enter_state(State.LOBBY)
	status_label.text = "匹配已取消"
	AuthManager.network.send_room_matchmaking(false)
	AuthManager.network.cancel_matchmaking()
	_update_buttons()


func _on_invite_pressed() -> void:
	status_label.text = "邀请功能暂未实现"


func _on_back_pressed() -> void:
	AuthManager.network.leave_room()
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_connected_to_match(_match_id: String, _user_id: String) -> void:
	_enter_state(State.LOBBY)
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


func _on_network_status_changed(message: String) -> void:
	status_label.text = message
	if message.begins_with("Party matchmaker failed"):
		_enter_state(State.LOBBY)
		start_match_button.disabled = false
		AuthManager.network.send_room_matchmaking(false)
