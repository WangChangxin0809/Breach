extends Control

const GAME_SCENE := "res://scenes/main_game/main.tscn"
const ROOM_SCENE := "res://scenes/main_game/room.tscn"
const CharacterRegistry = preload("res://scripts/main_game/character_registry.gd")

const COLOR_TEXT := Color(0.93, 0.94, 0.88)
const COLOR_MUTED := Color(0.65, 0.68, 0.72)
const COLOR_ACCENT := Color(0.28, 0.72, 0.82)
const COLOR_PRIMARY := Color(1.0, 0.76, 0.35)

var selected_index := 0
var locked := false
var characters: Array[Dictionary] = []

@onready var back_button: Button = $RootMargin/MainVBox/Header/BackButton
@onready var account_label: Label = $RootMargin/MainVBox/Header/AccountLabel
@onready var cards: Array[Button] = [
	$RootMargin/MainVBox/ContentHBox/CardGrid/AssaultCard,
	$RootMargin/MainVBox/ContentHBox/CardGrid/ScoutCard,
	$RootMargin/MainVBox/ContentHBox/CardGrid/SupportCard,
]
@onready var portrait_block: TextureRect = $RootMargin/MainVBox/ContentHBox/DetailPanel/DetailVBox/PortraitBlock
@onready var name_label: Label = $RootMargin/MainVBox/ContentHBox/DetailPanel/DetailVBox/NameLabel
@onready var role_label: Label = $RootMargin/MainVBox/ContentHBox/DetailPanel/DetailVBox/RoleLabel
@onready var skill_label: Label = $RootMargin/MainVBox/ContentHBox/DetailPanel/DetailVBox/SkillLabel
@onready var ultimate_label: Label = $RootMargin/MainVBox/ContentHBox/DetailPanel/DetailVBox/UltimateLabel
@onready var confirm_button: Button = $RootMargin/MainVBox/Footer/ConfirmButton
@onready var status_label: Label = $RootMargin/MainVBox/Footer/StatusLabel

func _ready() -> void:
	characters = CharacterRegistry.selectable_characters()
	back_button.pressed.connect(_on_back_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	AuthManager.network.character_select_state_received.connect(_on_character_select_state_received)
	AuthManager.network.status_changed.connect(_on_network_status_changed)
	for index in range(cards.size()):
		cards[index].pressed.connect(_on_card_pressed.bind(index))
	_update_account_label()
	_select_character(0)

func _update_account_label() -> void:
	if not AuthManager.is_logged_in():
		account_label.text = "账号：未登录"
		return
	var display_name := AuthManager.username
	if display_name.is_empty():
		display_name = AuthManager.email.get_slice("@", 0)
	account_label.text = "账号：%s" % display_name

func _on_card_pressed(index: int) -> void:
	if locked:
		return
	_select_character(index)

func _select_character(index: int) -> void:
	selected_index = index
	var character := characters[selected_index]
	portrait_block.texture = character["portrait"]
	name_label.text = character["name"]
	role_label.text = character["role"]
	skill_label.text = "技能：%s" % character["skill"]
	ultimate_label.text = "终极：%s" % character["ultimate"]
	status_label.text = "已选择 %s" % character["name"]
	for card_index in range(cards.size()):
		var color := COLOR_PRIMARY if card_index == selected_index else COLOR_TEXT
		cards[card_index].add_theme_color_override("font_color", color)

func _on_confirm_pressed() -> void:
	var character := characters[selected_index]
	locked = true
	confirm_button.disabled = true
	for card in cards:
		card.disabled = true
	status_label.text = "已锁定 %s，等待其他玩家..." % character["name"]
	AuthManager.network.send_character_select(character["id"])

func _on_back_pressed() -> void:
	if locked:
		status_label.text = "已锁定角色，不能返回"
		return
	get_tree().change_scene_to_file(ROOM_SCENE)

func _on_character_select_state_received(state: Dictionary) -> void:
	var locked_count := 0
	for player in state["players"]:
		if player["locked"]:
			locked_count += 1
	status_label.text = "已锁定 %d/%d，等待其他玩家..." % [locked_count, state["players"].size()]
	if state["all_locked"]:
		status_label.text = "双方选择完成，进入游戏..."
		get_tree().change_scene_to_file(GAME_SCENE)

func _on_network_status_changed(message: String) -> void:
	if locked:
		status_label.text = message
