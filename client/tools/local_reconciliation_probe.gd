extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_game/main.tscn")
const LOCAL_USER_ID := "local-user"

var main_scene: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main_scene = MAIN_SCENE.instantiate()
	root.add_child(main_scene)
	await process_frame

	main_scene.call("_on_authenticated", LOCAL_USER_ID, "local")
	main_scene.call("_on_connected_to_match", "probe-match", LOCAL_USER_ID)

	_apply_local_state(Vector2(320.0, 120.0))
	_assert_vector_close(main_scene.get("local_position"), Vector2(320.0, 120.0), 0.01, "initial authoritative position should seed local prediction")

	main_scene.set("local_position", Vector2(330.0, 120.0))
	_apply_local_state(Vector2(324.0, 120.0))
	_assert_vector_close(main_scene.get("local_position"), Vector2(330.0, 120.0), 0.01, "deadzone correction should preserve local prediction")

	main_scene.set("local_position", Vector2(400.0, 120.0))
	_apply_local_state(Vector2(360.0, 120.0))
	var smooth_expected := Vector2(400.0, 120.0).lerp(Vector2(360.0, 120.0), Config.LOCAL_RECONCILE_SMOOTH_WEIGHT)
	_assert_vector_close(main_scene.get("local_position"), smooth_expected, 0.01, "medium correction should smooth toward authority")

	main_scene.set("local_position", Vector2(700.0, 120.0))
	_apply_local_state(Vector2(320.0, 120.0))
	_assert_vector_close(main_scene.get("local_position"), Vector2(320.0, 120.0), 0.01, "large correction should snap to authority")

	var camera: Camera2D = main_scene.get("camera")
	camera.position = Vector2(200.0, 200.0)
	_apply_local_state(Vector2(324.0, 120.0))
	_assert_vector_close(camera.position, Vector2(200.0, 200.0), 0.01, "authoritative callback should not snap the camera")

	main_scene.set("local_visual_moving", true)
	_apply_local_state(Vector2(324.0, 120.0))
	_assert_equal(_local_animation(), "Run", "local movement animation should survive authoritative visual sync")

	main_scene.set("local_visual_moving", false)
	main_scene.call("_sync_player_visuals")
	_assert_equal(_local_animation(), "Idle", "local movement animation should stop when local input stops")

	print("Local reconciliation probe passed")
	quit(0)

func _apply_local_state(position: Vector2) -> void:
	main_scene.call("_on_authoritative_state", {
		"round_state": Config.ROUND_PLAYING,
		"round_time_remaining": 100.0,
		"players": [
			{
				"user_id": LOCAL_USER_ID,
				"display_name": "local",
				"faction": Config.FACTION_ATTACKERS,
				"position": position,
				"health": 100,
				"connected": true,
			},
		],
	})

func _assert_vector_close(actual: Vector2, expected: Vector2, tolerance: float, message: String) -> void:
	if actual.distance_to(expected) <= tolerance:
		return
	push_error("%s: expected %s got %s" % [message, str(expected), str(actual)])
	quit(1)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	push_error("%s: expected %s got %s" % [message, str(expected), str(actual)])
	quit(1)

func _local_animation() -> String:
	var visual := main_scene.get("player_visuals").get(LOCAL_USER_ID) as Node2D
	var sprite := visual.get_node("AnimatedSprite2D") as AnimatedSprite2D
	return str(sprite.animation)
