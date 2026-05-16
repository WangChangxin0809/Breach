extends StaticBody2D  # 假设你的“障碍”节点是 StaticBody2D

@export var export_to_server := true
@export var blocks_movement := true
@export var blocks_vision := true

func _ready():
	# 遍历“障碍”节点下的所有子节点
	for child in get_children():
		# 如果发现这个子节点是 Polygon2D 类型
		if child is Polygon2D:
			# 1. 在内存中动态新建一个碰撞多边形节点
			var collision = CollisionPolygon2D.new()
			collision.name = "%sCollision" % child.name
			
			# 2. 把画好的图形数据复制给它
			collision.polygon = child.polygon
			
			# 3. 复制位置、旋转和缩放（防止你移动过某块具体的石头）
			collision.transform = child.transform
			
			# 4. 把生成好的碰撞体作为子节点添加到“障碍”中，让它真正生效
			add_child(collision)
