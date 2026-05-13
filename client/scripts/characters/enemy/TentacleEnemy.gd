extends Node2D

@export_category("Tentacle Properties")
@export var segment_count: int = 15        # 触手分段数
@export var segment_length: float = 20.0   # 每段的长度
@export var move_speed: float = 8.0        # 追踪玩家的速度

@export_category("Idle Squirming")
@export var squirm_speed: float = 2.0        # 蠕动频率
@export var squirm_radius: float = 120.0     # 蠕动范围

@export_category("Snap Back")
@export var snap_speed: float = 25.0         # 弹回时的极快速度
@export var max_stretch_ratio: float = 0.9   # 最大拉伸比例（0.9表示达到90%长度就断开）

var is_snapping: bool = false
var max_length: float = 0.0

@onready var line: Line2D = $Line2D
@onready var detect_area: Area2D = $DetectionArea

var points: Array[Vector2] = []
var target_pos: Vector2
var base_pos: Vector2
var time: float = 0.0

# 状态管理
var player_target: Node2D = null

func _ready() -> void:
	# 确保线条独立于父节点的变换
	line.top_level = true 
	
	# 绑定侦测信号
	detect_area.body_entered.connect(_on_body_entered)
	detect_area.body_exited.connect(_on_body_exited)
	
	# 初始化触手点集
	base_pos = global_position
	target_pos = base_pos
	for i in range(segment_count):
		points.append(base_pos + Vector2(0, i * segment_length))
	
	line.points = points
	
	max_length = segment_count * segment_length

func _process(delta: float) -> void:
	time += delta
	base_pos = global_position # 锚定根部位置
	
	var dist_to_base = target_pos.distance_to(base_pos)

	# 1. 如果正在弹回，且还没弹回到根部附近
	if is_snapping:
		target_pos = target_pos.lerp(base_pos, delta * snap_speed)
		if dist_to_base < squirm_radius:
			is_snapping = false
			
	# 2. 如果锁定了玩家，且没有在弹回
	elif is_instance_valid(player_target):
		if dist_to_base > max_length * max_stretch_ratio:
			player_target = null
			is_snapping = true
		else:
			target_pos = target_pos.lerp(player_target.global_position, delta * move_speed)
			
	# 3. 闲置蠕动
	else:
		var noise_x = sin(time * squirm_speed) * squirm_radius
		var noise_y = cos(time * squirm_speed * 0.8) * squirm_radius
		var idle_target = base_pos + Vector2(noise_x, noise_y)
		target_pos = target_pos.lerp(idle_target, delta * (move_speed * 0.3))

	# --- 2. 运算逆运动学 (FABRIK) ---
	resolve_ik()
	
	# --- 3. 更新画面 ---
	line.points = points

func resolve_ik() -> void:
	# 步骤A：末端对齐目标 (Backward Pass)
	points[segment_count - 1] = target_pos
	for i in range(segment_count - 2, -1, -1):
		var dir = (points[i] - points[i + 1]).normalized()
		points[i] = points[i + 1] + dir * segment_length

	# 步骤B：根部锚定并重新约束距离 (Forward Pass)
	points[0] = base_pos
	for i in range(1, segment_count):
		var dir = (points[i] - points[i - 1]).normalized()
		points[i] = points[i - 1] + dir * segment_length

# --- 信号回调 ---
func _on_body_entered(body: Node2D) -> void:
	# 假设你的玩家节点在 "Player" 分组中
	if body.is_in_group("Player"):
		player_target = body

func _on_body_exited(body: Node2D) -> void:
	if body == player_target:
		player_target = null
		is_snapping = true
