extends "res://scripts/characters/character_base.gd"
class_name PlayerCharacter

const CURSOR_TEXTURE := preload("res://assets/ui/Cursor.png")

func _ready() -> void:
	custom_cursor = CURSOR_TEXTURE
	use_custom_cursor = true
	super()
