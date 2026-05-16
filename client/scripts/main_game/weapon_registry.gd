extends RefCounted

const DEFAULT_WEAPON_ID := "default_sidearm"
const SIDEARM_GUN_SCENE := preload("res://scenes/weapons/sidearm_gun.tscn")

static func default_weapon_id() -> String:
	return DEFAULT_WEAPON_ID

static func weapon_scene(weapon_id: String) -> PackedScene:
	var info := weapon_info(weapon_id)
	var scene := info["scene"] as PackedScene
	return scene

static func weapon_info(weapon_id: String) -> Dictionary:
	match weapon_id:
		"default_sidearm", "sidearm_gun":
			return _entry(DEFAULT_WEAPON_ID, "Default Sidearm", "sidearm", SIDEARM_GUN_SCENE)
		_:
			return _entry(DEFAULT_WEAPON_ID, "Default Sidearm", "sidearm", SIDEARM_GUN_SCENE)

static func _entry(weapon_id: String, display_name: String, slot: String, scene: PackedScene) -> Dictionary:
	return {
		"id": weapon_id,
		"name": display_name,
		"slot": slot,
		"scene": scene,
	}
