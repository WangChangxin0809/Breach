extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_game/main.tscn")

var main_scene: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main_scene = MAIN_SCENE.instantiate()
	root.add_child(main_scene)
	await process_frame

	var movement_obstacles: Array = main_scene.get("movement_obstacles")
	var vision_obstacles: Array = main_scene.get("vision_obstacles")
	var generated_occluders := main_scene.get_node_or_null("GeneratedVisionOccluders")
	var low_cover := _find_obstacle(movement_obstacles, "ArtWorld/LowCoverCrate/CollisionShape2D")

	print("MAP_GEOMETRY_PROBE movement=%d vision=%d generated_occluders=%d low_cover_blocks_vision=%s" % [
		movement_obstacles.size(),
		vision_obstacles.size(),
		generated_occluders.get_child_count() if generated_occluders else -1,
		str(low_cover.get("blocks_vision", null)),
	])

	if movement_obstacles.is_empty():
		push_error("main scene did not load movement obstacles")
		quit(1)
		return
	if vision_obstacles.is_empty():
		push_error("main scene did not load vision obstacles")
		quit(1)
		return
	if low_cover.is_empty() or bool(low_cover.get("blocks_vision", true)):
		push_error("low cover should remain movement-only in main scene geometry")
		quit(1)
		return
	if generated_occluders == null or generated_occluders.get_child_count() == 0:
		push_error("main scene did not generate light occluders for exported vision blockers")
		quit(1)
		return
	if not bool(main_scene.call("_is_valid_local_position", Vector2(320.0, 120.0))):
		push_error("local spawn should be walkable after map geometry load")
		quit(1)
		return
	if bool(main_scene.call("_is_valid_local_position", Vector2(160.0, 168.0))):
		push_error("low cover center should block movement")
		quit(1)
		return

	quit(0)

func _find_obstacle(obstacles: Array, source_path: String) -> Dictionary:
	for raw_obstacle in obstacles:
		var obstacle: Dictionary = raw_obstacle
		if str(obstacle.get("source_path", "")) == source_path:
			return obstacle
	return {}
