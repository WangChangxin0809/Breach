extends RefCounted
class_name FlowField

# 流场寻路：从目标点向外做 Dijkstra 扩散，每个格子记录指向最佳邻居的方向。
# 适用场景：大量单位向同一目标移动时，只需计算一次流场，所有单位查表即可。

const NEIGHBORS := [
	Vector2i( 0, -1),   # 上
	Vector2i( 1, -1),   # 右上
	Vector2i( 1,  0),   # 右
	Vector2i( 1,  1),   # 右下
	Vector2i( 0,  1),   # 下
	Vector2i(-1,  1),   # 左下
	Vector2i(-1,  0),   # 左
	Vector2i(-1, -1),   # 左上
]

var _grid_width: int
var _grid_height: int
var _cell_size: float
var _map_origin: Vector2
var _costs: PackedInt32Array       # -1 = 障碍物, >=0 = 到目标距离
var _flow: PackedVector2Array      # 归一化流向

func build(
	map_size: Vector2,
	cell_size: float,
	target: Vector2,
	obstacles: Array,
	player_radius: float
) -> void:
	_cell_size = cell_size
	_grid_width = ceili(map_size.x / cell_size)
	_grid_height = ceili(map_size.y / cell_size)
	_map_origin = Vector2.ZERO
	var total := _grid_width * _grid_height

	_costs.resize(total)
	_costs.fill(-1)
	_flow.resize(total)
	_flow.fill(Vector2.ZERO)

	for gy in _grid_height:
		for gx in _grid_width:
			var idx := gy * _grid_width + gx
			var center := _cell_center(gx, gy)
			if _cell_blocked(center, player_radius, obstacles):
				_costs[idx] = -1
			else:
				_costs[idx] = 0x7FFFFFFF  # 大数代表未访问

	var target_idx := _cell_index_at(target)
	if target_idx < 0:
		target_idx = _closest_walkable(target, player_radius, obstacles)
		if target_idx < 0:
			return

	_costs[target_idx] = 0

	_dijkstra()
	_build_flow()

func get_flow(world_position: Vector2) -> Vector2:
	var idx := _cell_index_at(world_position)
	if idx < 0 or _costs[idx] <= 0 or _costs[idx] == 0x7FFFFFFF:
		return Vector2.ZERO
	return _flow[idx]

func get_distance(world_position: Vector2) -> float:
	var idx := _cell_index_at(world_position)
	if idx < 0 or _costs[idx] < 0 or _costs[idx] == 0x7FFFFFFF:
		return INF
	return float(_costs[idx]) * _cell_size

func is_reachable(world_position: Vector2) -> bool:
	var idx := _cell_index_at(world_position)
	return idx >= 0 and _costs[idx] >= 0 and _costs[idx] != 0x7FFFFFFF

func _dijkstra() -> void:
	var open: Array[Vector2i] = []
	for gy in _grid_height:
		for gx in _grid_width:
			var idx := gy * _grid_width + gx
			if _costs[idx] == 0:
				open.append(Vector2i(gx, gy))

	while not open.is_empty():
		var min_i := _min_distance_index(open)
		var cell := open[min_i]
		open.remove_at(min_i)
		var current_idx := cell.y * _grid_width + cell.x
		var current_cost := _costs[current_idx]

		for dir in NEIGHBORS:
			var nx: int = cell.x + dir.x
			var ny: int = cell.y + dir.y
			if nx < 0 or ny < 0 or nx >= _grid_width or ny >= _grid_height:
				continue
			var ni: int = ny * _grid_width + nx
			if _costs[ni] < 0:
				continue
			var step_cost: int = 14 if dir.x != 0 and dir.y != 0 else 10
			var new_cost: int = current_cost + step_cost
			if new_cost < _costs[ni]:
				_costs[ni] = new_cost
				open.append(Vector2i(nx, ny))

func _build_flow() -> void:
	for gy in _grid_height:
		for gx in _grid_width:
			var idx := gy * _grid_width + gx
			var cost := _costs[idx]
			if cost < 0 or cost == 0x7FFFFFFF:
				_flow[idx] = Vector2.ZERO
				continue
			var best_dir := Vector2.ZERO
			var best_cost := cost
			for dir in NEIGHBORS:
				var nx: int = gx + dir.x
				var ny: int = gy + dir.y
				if nx < 0 or ny < 0 or nx >= _grid_width or ny >= _grid_height:
					continue
				var neighbor_idx: int = ny * _grid_width + nx
				var neighbor_cost: int = _costs[neighbor_idx]
				if neighbor_cost < 0 or neighbor_cost == 0x7FFFFFFF:
					continue
				if neighbor_cost < best_cost:
					best_cost = neighbor_cost
					best_dir = Vector2(dir)
			_flow[idx] = best_dir.normalized()

func _cell_index_at(world_position: Vector2) -> int:
	var gx := int((world_position.x - _map_origin.x) / _cell_size)
	var gy := int((world_position.y - _map_origin.y) / _cell_size)
	if gx < 0 or gy < 0 or gx >= _grid_width or gy >= _grid_height:
		return -1
	return gy * _grid_width + gx

func _cell_center(gx: int, gy: int) -> Vector2:
	return Vector2(
		_map_origin.x + (float(gx) + 0.5) * _cell_size,
		_map_origin.y + (float(gy) + 0.5) * _cell_size,
	)

func _cell_blocked(center: Vector2, radius: float, obstacles: Array) -> bool:
	for obstacle in obstacles:
		if _shape_overlaps_cell(center, radius, obstacle):
			return true
	return false

func _shape_overlaps_cell(cell_center: Vector2, radius: float, obstacle: Dictionary) -> bool:
	match str(obstacle.get("type", "")):
		"rect":
			return _circle_rect_overlap(cell_center, radius,
				Vector2(obstacle["x"], obstacle["y"]),
				Vector2(obstacle["w"], obstacle["h"]))
		"circle":
			var obs_center := Vector2(obstacle["x"], obstacle["y"])
			var obs_r := float(obstacle.get("radius", 0.0))
			return cell_center.distance_to(obs_center) < radius + obs_r
		"capsule":
			return _circle_capsule_overlap(cell_center, radius,
				_point(obstacle.get("a")), _point(obstacle.get("b")),
				float(obstacle.get("radius", 0.0)))
		"polygon":
			return _circle_polygon_overlap(cell_center, radius, obstacle.get("points", []))
	return false

func _circle_rect_overlap(circle_center: Vector2, r: float, rect_pos: Vector2, rect_size: Vector2) -> bool:
	var closest := Vector2(
		clampf(circle_center.x, rect_pos.x, rect_pos.x + rect_size.x),
		clampf(circle_center.y, rect_pos.y, rect_pos.y + rect_size.y),
	)
	return circle_center.distance_to(closest) < r

func _circle_capsule_overlap(circle_center: Vector2, r: float, a: Vector2, b: Vector2, cap_r: float) -> bool:
	var dist := _point_to_segment_distance(circle_center, a, b)
	return dist < r + cap_r

func _circle_polygon_overlap(circle_center: Vector2, r: float, raw_points: Array) -> bool:
	var points: Array[Vector2] = []
	for raw in raw_points:
		points.append(_point(raw))
	if points.size() < 3:
		return false
	if _point_in_polygon(circle_center, points):
		return true
	for i in points.size():
		if _point_to_segment_distance(circle_center, points[i], points[(i + 1) % points.size()]) < r:
			return true
	return false

func _closest_walkable(target: Vector2, radius: float, obstacles: Array) -> int:
	var tx := int((target.x - _map_origin.x) / _cell_size)
	var ty := int((target.y - _map_origin.y) / _cell_size)
	for layer in range(12):
		if layer == 0:
			var idx := _idx(tx, ty)
			if idx >= 0 and not _cell_blocked(_cell_center(tx, ty), radius, obstacles):
				return idx
			continue
		for dx in range(-layer, layer + 1):
			for dy in [-layer, layer]:
				var idx := _idx(tx + dx, ty + dy)
				if idx >= 0 and not _cell_blocked(_cell_center(tx + dx, ty + dy), radius, obstacles):
					return idx
		for dy in range(-(layer - 1), layer):
			for dx in [-layer, layer]:
				var idx := _idx(tx + dx, ty + dy)
				if idx >= 0 and not _cell_blocked(_cell_center(tx + dx, ty + dy), radius, obstacles):
					return idx
	return -1

func _idx(gx: int, gy: int) -> int:
	if gx < 0 or gy < 0 or gx >= _grid_width or gy >= _grid_height:
		return -1
	return gy * _grid_width + gx

func _min_distance_index(array: Array[Vector2i]) -> int:
	if array.is_empty():
		return -1
	var best := 0
	var best_cost := _costs[array[0].y * _grid_width + array[0].x]
	for i in range(1, array.size()):
		var cost := _costs[array[i].y * _grid_width + array[i].x]
		if cost < best_cost:
			best = i
			best_cost = cost
	return best

func _point_to_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq == 0.0:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _point_in_polygon(p: Vector2, polygon: Array[Vector2]) -> bool:
	var inside := false
	var j := polygon.size() - 1
	for i in polygon.size():
		if (polygon[i].y > p.y) != (polygon[j].y > p.y):
			var x_at := (polygon[j].x - polygon[i].x) * (p.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x
			if p.x < x_at:
				inside = not inside
		j = i
	return inside

func _point(raw) -> Vector2:
	if typeof(raw) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)))
