extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_game/main.tscn")
const PLAYER_SCENE := preload("res://scenes/characters/player_character.tscn")
const WEAPON_SCENE := preload("res://scenes/weapons/sidearm_gun.tscn")

var main_scene: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var standalone_player := PLAYER_SCENE.instantiate() as Node2D
	root.add_child(standalone_player)
	await process_frame

	_assert(standalone_player.has_method("set_facing"), "player scene should inherit CharacterBase facing API")
	_assert(standalone_player.has_method("set_moving"), "player scene should inherit CharacterBase animation API")
	_assert(standalone_player.has_method("equip_weapon"), "player scene should inherit CharacterBase equipment API")
	_assert(standalone_player.get_node_or_null("Camera2D") != null, "standalone player scene should keep its camera")

	var standalone_weapon := standalone_player.get_node_or_null("WeaponPivot") as Node2D
	_assert(standalone_weapon != null, "player scene should include a weapon mount")
	_assert(standalone_weapon.has_method("set_facing"), "player weapon should inherit WeaponBase facing API")
	_assert(standalone_weapon.has_method("set_weapon_texture"), "player weapon should inherit WeaponBase texture API")

	standalone_player.queue_free()

	main_scene = MAIN_SCENE.instantiate()
	root.add_child(main_scene)
	await process_frame

	var template := main_scene.get("player_template") as Node2D
	_assert(template != null, "main scene should expose a player template")
	_assert(template.has_method("set_facing"), "main player template should keep CharacterBase API")
	_assert(template.get_node_or_null("Camera2D") == null, "main player template cameras should be stripped for network visuals")

	var template_weapon := template.get_node_or_null("WeaponPivot") as Node2D
	_assert(template_weapon != null, "main player template should keep a weapon node")
	_assert(template_weapon.has_method("set_facing"), "main player template weapon should keep WeaponBase API")

	var replacement_weapon := WEAPON_SCENE.instantiate() as Node2D
	_assert(replacement_weapon.has_method("set_facing"), "weapon scene should instantiate with WeaponBase API")
	replacement_weapon.queue_free()

	print("Character/weapon base probe passed")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
