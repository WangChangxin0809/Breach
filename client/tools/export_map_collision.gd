extends SceneTree

const DEFAULT_SCENE := "res://scenes/main_game/main.tscn"
const DEFAULT_OUTPUT := "../server/modules/config/data/maps/dev_map_collision.json"
const DEFAULT_WIDTH := 1600.0
const DEFAULT_HEIGHT := 960.0
const MAP_VERSION := 1

var _exit_code := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var options := _parse_options()
	var scene_path: String = options.get("scene", DEFAULT_SCENE)
	var output_path: String = options.get("output", DEFAULT_OUTPUT)
	var map_width := float(options.get("width", DEFAULT_WIDTH))
	var map_height := float(options.get("height", DEFAULT_HEIGHT))
	var include_tilemaps := bool(options.get("include_tilemaps", false))
	var allow_empty := bool(options.get("allow_empty", false))

	var packed_scene := load(scene_path)
	if not packed_scene is PackedScene:
		_fail("Could not load scene: %s" % scene_path)
		return

	var scene_root: Node = packed_scene.instantiate()
	root.add_child(scene_root)
	await process_frame
	await process_frame

	var collision_shapes: Array = []
	_collect_collision_shapes(scene_root, scene_root, collision_shapes)
	if include_tilemaps:
		_collect_tilemap_rects(scene_root, scene_root, collision_shapes)
	collision_shapes.sort_custom(_sort_by_source_path)
	if collision_shapes.is_empty() and not allow_empty:
		_fail("Scene %s has no exported collision shapes. Pass --allow-empty to write an empty map." % scene_path)
		return

	var payload := {
		"version": MAP_VERSION,
		"source_scene": scene_path,
		"map": {
			"width": map_width,
			"height": map_height,
			"collision_shapes": collision_shapes,
			"spawn_points": _collect_spawn_points(scene_root),
		},
	}

	if not _write_json(output_path, payload):
		return
	print("Exported %d collision shapes to %s" % [collision_shapes.size(), output_path])
	quit(_exit_code)

func _parse_options() -> Dictionary:
	var options := {}
	for arg in OS.get_cmdline_user_args():
		if arg == "--include-tilemaps":
			options["include_tilemaps"] = true
			continue
		if arg == "--allow-empty":
			options["allow_empty"] = true
			continue
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var pair := arg.trim_prefix("--").split("=", false, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	return options

func _collect_collision_shapes(scene_root: Node, current: Node, out: Array) -> void:
	if current is CollisionShape2D and _is_server_static_collision(current):
		var shape_data := _shape_to_data(scene_root, current)
		if not shape_data.is_empty():
			out.append(shape_data)
	elif current is CollisionPolygon2D and _is_server_static_collision(current):
		var polygon_data := _polygon_to_data(scene_root, current)
		if not polygon_data.is_empty():
			out.append(polygon_data)

	for child in current.get_children():
		_collect_collision_shapes(scene_root, child, out)

func _is_server_static_collision(node: Node) -> bool:
	var parent := node.get_parent()
	while parent:
		if parent is StaticBody2D:
			return true
		if parent is CharacterBody2D or parent is RigidBody2D or parent is Area2D:
			return false
		parent = parent.get_parent()
	return false

func _shape_to_data(scene_root: Node, node: CollisionShape2D) -> Dictionary:
	if node.disabled or node.shape == null:
		return {}

	var source_path := _relative_path(scene_root, node)
	var base := {
		"id": _stable_id(source_path),
		"name": node.name,
		"source_path": source_path,
	}

	if node.shape is RectangleShape2D:
		var rect_shape := node.shape as RectangleShape2D
		var half := rect_shape.size * 0.5
		var points := [
			node.global_transform * Vector2(-half.x, -half.y),
			node.global_transform * Vector2(half.x, -half.y),
			node.global_transform * Vector2(half.x, half.y),
			node.global_transform * Vector2(-half.x, half.y),
		]
		base["type"] = "polygon"
		base["points"] = _serialize_points(points)
		return base

	if node.shape is CircleShape2D:
		var circle_shape := node.shape as CircleShape2D
		var scale := _average_scale(node.global_transform)
		base["type"] = "circle"
		base["x"] = node.global_position.x
		base["y"] = node.global_position.y
		base["radius"] = circle_shape.radius * scale
		return base

	if node.shape is CapsuleShape2D:
		var capsule_shape := node.shape as CapsuleShape2D
		var scale := _average_scale(node.global_transform)
		var segment_half := maxf((capsule_shape.height * 0.5) - capsule_shape.radius, 0.0)
		base["type"] = "capsule"
		base["radius"] = capsule_shape.radius * scale
		base["a"] = _serialize_point(node.global_transform * Vector2(0.0, -segment_half))
		base["b"] = _serialize_point(node.global_transform * Vector2(0.0, segment_half))
		return base

	_fail("Unsupported CollisionShape2D shape at %s: %s" % [source_path, node.shape.get_class()])
	return {}

func _polygon_to_data(scene_root: Node, node: CollisionPolygon2D) -> Dictionary:
	if node.disabled or node.polygon.size() < 3:
		return {}

	var source_path := _relative_path(scene_root, node)
	var points := []
	for point in node.polygon:
		points.append(node.global_transform * point)

	return {
		"id": _stable_id(source_path),
		"name": node.name,
		"source_path": source_path,
		"type": "polygon",
		"points": _serialize_points(points),
	}

func _collect_tilemap_rects(scene_root: Node, out_root: Node, out: Array) -> void:
	if out_root is TileMapLayer and _should_export_tilemap(out_root):
		var layer := out_root as TileMapLayer
		var tile_size := Vector2(layer.tile_set.tile_size) if layer.tile_set else Vector2(16, 16)
		for cell in layer.get_used_cells():
			var top_left := layer.to_global(layer.map_to_local(cell) - tile_size * 0.5)
			var bottom_right := layer.to_global(layer.map_to_local(cell) + tile_size * 0.5)
			var source_path := "%s:%s,%s" % [_relative_path(scene_root, layer), cell.x, cell.y]
			out.append({
				"id": _stable_id(source_path),
				"name": layer.name,
				"source_path": source_path,
				"type": "rect",
				"x": minf(top_left.x, bottom_right.x),
				"y": minf(top_left.y, bottom_right.y),
				"w": absf(bottom_right.x - top_left.x),
				"h": absf(bottom_right.y - top_left.y),
			})

	for child in out_root.get_children():
		_collect_tilemap_rects(scene_root, child, out)

func _should_export_tilemap(layer: TileMapLayer) -> bool:
	return layer.is_in_group("server_collision") or layer.get_meta("export_server_collision", false)

func _collect_spawn_points(scene_root: Node) -> Dictionary:
	var spawn_points := {
		"attackers": [],
		"defenders": [],
	}
	_collect_spawn_points_recursive(scene_root, spawn_points)
	return spawn_points

func _collect_spawn_points_recursive(current: Node, spawn_points: Dictionary) -> void:
	if current is Node2D:
		var node_2d := current as Node2D
		if current.is_in_group("spawn_attackers") or current.name.begins_with("AttackersSpawn"):
			spawn_points["attackers"].append(_serialize_point(node_2d.global_position))
		if current.is_in_group("spawn_defenders") or current.name.begins_with("DefendersSpawn"):
			spawn_points["defenders"].append(_serialize_point(node_2d.global_position))

	for child in current.get_children():
		_collect_spawn_points_recursive(child, spawn_points)

func _write_json(output_path: String, payload: Dictionary) -> bool:
	var absolute_path := ProjectSettings.globalize_path(output_path)
	var base_dir := absolute_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(base_dir) != OK:
		_fail("Could not create output directory: %s" % base_dir)
		return false

	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not open output file: %s" % absolute_path)
		return false

	file.store_string(JSON.stringify(payload, "  ", true))
	file.store_string("\n")
	return true

func _relative_path(scene_root: Node, node: Node) -> String:
	var root_path := str(scene_root.get_path())
	var node_path := str(node.get_path())
	if node_path.begins_with(root_path + "/"):
		return node_path.trim_prefix(root_path + "/")
	return node_path

func _serialize_points(points: Array) -> Array:
	var serialized := []
	for point in points:
		serialized.append(_serialize_point(point))
	return serialized

func _serialize_point(point: Vector2) -> Dictionary:
	return {
		"x": snappedf(point.x, 0.001),
		"y": snappedf(point.y, 0.001),
	}

func _stable_id(value: String) -> String:
	return value.to_snake_case().replace("/", "_").replace(":", "_").replace(",", "_")

func _average_scale(transform: Transform2D) -> float:
	return (transform.x.length() + transform.y.length()) * 0.5

func _sort_by_source_path(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("source_path", "")) < str(b.get("source_path", ""))

func _fail(message: String) -> void:
	push_error(message)
	_exit_code = 1
	quit(_exit_code)
