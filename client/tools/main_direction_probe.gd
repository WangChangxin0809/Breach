extends Node

const MAIN_SCENE := preload("res://scenes/main_game/main.tscn")

var main_scene: Node

func _ready() -> void:
	main_scene = MAIN_SCENE.instantiate()
	add_child(main_scene)
	await get_tree().process_frame

	main_scene.call("_on_authenticated", "local-user", "local")
	main_scene.call("_on_connected_to_match", "probe-match", "local-user")
	main_scene.set("mouse_world_position", Vector2(520.0, 180.0))

	_apply_state(Vector2.RIGHT)
	var right_rotation := _remote_weapon_rotation()
	var right_flip := _remote_sprite_flip()
	var right_lights := _visible_remote_lights()

	_apply_state(Vector2.UP)
	var up_rotation := _remote_weapon_rotation()
	var up_flip := _remote_sprite_flip()
	var up_lights := _visible_remote_lights()

	_apply_state(Vector2.UP, Vector2(244.0, 180.0))
	var run_animation := _remote_animation()
	main_scene.call("_sync_player_visuals")
	var held_animation := _remote_animation()

	print("DIRECTION_PROBE right_rotation=%.3f up_rotation=%.3f right_flip=%s up_flip=%s right_lights=%d up_lights=%d run_animation=%s held_animation=%s" % [
		right_rotation,
		up_rotation,
		str(right_flip),
		str(up_flip),
		right_lights,
		up_lights,
		run_animation,
		held_animation,
	])

	if absf(right_rotation - up_rotation) < 0.5:
		push_error("remote weapon rotation did not follow direction")
		get_tree().quit(1)
		return
	if right_lights != 0 or up_lights != 0:
		push_error("remote lights should stay hidden")
		get_tree().quit(1)
		return
	if run_animation != "Run" or held_animation != "Run":
		push_error("remote movement animation did not stay in Run between authoritative states")
		get_tree().quit(1)
		return

	get_tree().quit(0)

func _apply_state(remote_direction: Vector2, remote_position := Vector2(220.0, 180.0)) -> void:
	var bytes := PackedByteArray()
	ProtobufCodec._write_varint_field(bytes, 1, Config.PROTOCOL_VERSION)
	ProtobufCodec._write_varint_field(bytes, 2, 1)
	ProtobufCodec._write_varint_field(bytes, 3, Config.ROUND_PLAYING)
	ProtobufCodec._write_fixed32_field(bytes, 4, 100.0)
	ProtobufCodec._write_message_field(bytes, 5, _encoded_player_state(
		"local-user",
		"local",
		Config.FACTION_ATTACKERS,
		Vector2(120.0, 180.0),
		Vector2.RIGHT
	))
	ProtobufCodec._write_message_field(bytes, 5, _encoded_player_state(
		"remote-user",
		"remote",
		Config.FACTION_DEFENDERS,
		remote_position,
		remote_direction
	))

	var state := ProtobufCodec.decode_game_state(bytes)
	for player in state["players"]:
		if player["user_id"] == "remote-user" and not bool(player.get("has_direction", false)):
			push_error("decoded remote state is missing direction")
			get_tree().quit(1)
			return
	main_scene.call("_on_authoritative_state", state)

func _encoded_player_state(user_id: String, display_name: String, faction: int, position: Vector2, direction: Vector2) -> PackedByteArray:
	var bytes := PackedByteArray()
	ProtobufCodec._write_string_field(bytes, 1, user_id)
	ProtobufCodec._write_string_field(bytes, 2, display_name)
	ProtobufCodec._write_varint_field(bytes, 3, faction)
	ProtobufCodec._write_message_field(bytes, 4, ProtobufCodec.encode_vector2(position))
	ProtobufCodec._write_varint_field(bytes, 5, 100)
	ProtobufCodec._write_varint_field(bytes, 6, 1)
	ProtobufCodec._write_message_field(bytes, 7, ProtobufCodec.encode_vector2(direction))
	return bytes

func _remote_visual() -> Node2D:
	return main_scene.get("player_visuals").get("remote-user") as Node2D

func _remote_weapon_rotation() -> float:
	var visual := _remote_visual()
	var pivot := visual.get_node("WeaponPivot") as Node2D
	return pivot.rotation

func _remote_sprite_flip() -> bool:
	var visual := _remote_visual()
	var sprite := visual.get_node("AnimatedSprite2D") as AnimatedSprite2D
	return sprite.flip_h

func _remote_animation() -> String:
	var visual := _remote_visual()
	var sprite := visual.get_node("AnimatedSprite2D") as AnimatedSprite2D
	return str(sprite.animation)

func _visible_remote_lights() -> int:
	var count := 0
	for raw_light in _remote_visual().find_children("*", "PointLight2D", true, false):
		var light := raw_light as PointLight2D
		if light != null and light.visible:
			count += 1
	return count
