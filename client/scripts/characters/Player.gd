extends CharacterBody2D

# --- 属性 ---
@export var move_speed: float = 200.0

# 【新增】用来记录武器轴心的水平偏移距离
var pivot_x_offset: float = 0.0

# --- 节点引用 ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_pivot: Node2D = $WeaponPivot
# 注意你代码里节点名叫 Sprite2D，这里保持一致
@onready var weapon_sprite: Sprite2D = $WeaponPivot/WeaponSprite

func _ready() -> void:
	pivot_x_offset = abs(weapon_pivot.position.x)
	
	var cursor_texture := preload("res://assets/UI/Cursor.png") 
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, Vector2(16, 16))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(_delta: float) -> void:
	handle_movement()
	handle_animation()
	handle_weapon_rotation()

# 1. 基础八向移动
func handle_movement() -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * move_speed
	move_and_slide()

# 2. Idle/Run 动画切换
func handle_animation() -> void:
	if velocity.length() > 0:
		animated_sprite.play("Run")
	else:
		animated_sprite.play("Idle")

# 3. 武器跟随鼠标旋转 & 角色翻转 & 轴心位移
func handle_weapon_rotation() -> void:
	var mouse_pos := get_global_mouse_position()
	
	# 让武器轴心始终准确看向鼠标
	weapon_pivot.look_at(mouse_pos)
	
	if mouse_pos.x < global_position.x:
		# --- 鼠标在左侧 ---
		animated_sprite.flip_h = false  
		weapon_sprite.flip_v = true     
		# 【新增】将武器轴心移到角色左侧 (相当于 X = -4.0)
		weapon_pivot.position.x = -pivot_x_offset 
	else:
		# --- 鼠标在右侧 ---
		animated_sprite.flip_h = true   
		weapon_sprite.flip_v = false    
		# 【新增】将武器轴心移到角色右侧 (相当于 X = 4.0)
		weapon_pivot.position.x = pivot_x_offset
