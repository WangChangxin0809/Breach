extends Camera2D

# --- 参数配置 ---
@export var follow_smooth_speed: float = 5.0  # 相机平滑移动的速度
@export var max_mouse_offset: float = 120.0   # 相机最多允许偏离角色多少像素

func _process(delta: float) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var player_pos: Vector2 = get_parent().global_position
	var offset_vector: Vector2 = mouse_pos - player_pos
	var target_position: Vector2 = offset_vector.limit_length(max_mouse_offset)
	
	# 因为 Camera2D 是 Player 的子节点，它的 position 本身就是相对于 Player 的局部坐标
	# 所以我们直接让相机的局部 position 向 target_position 进行 Lerp（线性插值）平滑移动
	position = position.lerp(target_position, follow_smooth_speed * delta)
