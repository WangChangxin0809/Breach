extends RefCounted

const WeaponRegistry = preload("res://scripts/main_game/weapon_registry.gd")

const DEFAULT_CHARACTER_ID := "recruit"
const PLAYER_CHARACTER_SCENE := preload("res://scenes/characters/player_character.tscn")

const FURA_PORTRAIT := preload("res://assets/spiritframes/01.png")
const ISAAC_PORTRAIT := preload("res://assets/spiritframes/issac.png")
const MORGAN_PORTRAIT := preload("res://assets/spiritframes/mogan.png")

static func selectable_characters() -> Array[Dictionary]:
	return [
		character_info("fura"),
		character_info("isaac"),
		character_info("morgan"),
	]

static func character_info(character_id: String) -> Dictionary:
	match character_id:
		"fura":
			return _entry("fura", "芙拉", "近距离突破", "大快朵颐", "野性觉醒", FURA_PORTRAIT)
		"isaac":
			return _entry("isaac", "艾萨克", "视野与情报", "精密探测", "全域封锁", ISAAC_PORTRAIT)
		"morgan":
			return _entry("morgan", "莫甘", "狡诈与重生", "鬼影迷踪", "唤灵戏法", MORGAN_PORTRAIT)
		"recruit", "":
			return _entry("recruit", "Recruit", "测试角色", "未配置", "未配置", FURA_PORTRAIT)
		_:
			return character_info(DEFAULT_CHARACTER_ID)

static func character_scene(character_id: String) -> PackedScene:
	var scene := character_info(character_id).get("scene") as PackedScene
	return scene

static func default_weapon_id(character_id: String) -> String:
	return str(character_info(character_id)["default_weapon_id"])

static func _entry(
	character_id: String,
	display_name: String,
	role: String,
	skill: String,
	ultimate: String,
	portrait: Texture2D,
	default_weapon_id: String = WeaponRegistry.DEFAULT_WEAPON_ID,
	scene: PackedScene = null
) -> Dictionary:
	var character_scene := scene
	if character_scene == null:
		character_scene = PLAYER_CHARACTER_SCENE
	return {
		"id": character_id,
		"name": display_name,
		"role": role,
		"skill": skill,
		"ultimate": ultimate,
		"portrait": portrait,
		"scene": character_scene,
		"default_weapon_id": default_weapon_id,
	}
