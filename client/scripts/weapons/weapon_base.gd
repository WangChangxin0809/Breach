extends Node2D
class_name WeaponBase

@export var weapon_id := "weapon"
@export var sprite_node_path := NodePath("WeaponSprite")
@export var base_x_offset := -1.0

@onready var weapon_sprite: Sprite2D = get_node_or_null(sprite_node_path) as Sprite2D

func _ready() -> void:
	if base_x_offset < 0.0:
		base_x_offset = absf(position.x)

func set_facing(facing: Vector2) -> void:
	if facing.length_squared() <= 0.001:
		return
	var direction := facing.normalized()
	var faces_left := direction.x < -0.01
	position.x = -base_x_offset if faces_left else base_x_offset
	rotation = direction.angle()
	if weapon_sprite:
		weapon_sprite.flip_v = faces_left

func set_lights_visible(enabled: bool) -> void:
	for raw_light in find_children("*", "PointLight2D", true, false):
		var light := raw_light as PointLight2D
		if light:
			light.visible = enabled

func set_light_color(color: Color) -> void:
	for raw_light in find_children("*", "PointLight2D", true, false):
		var light := raw_light as PointLight2D
		if light:
			light.color = color

func set_weapon_texture(texture: Texture2D) -> void:
	if weapon_sprite:
		weapon_sprite.texture = texture
