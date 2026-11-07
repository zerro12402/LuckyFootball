## Verifies formal framing and follow behavior from camera values without inspecting rendered frames.
extends SceneTree

const Fixture = preload("res://tests/support/formal_match_fixture.gd")
const FORMAL_SCENE := "res://scenes/match/formal_match.tscn"
const FIELD_SCENE := "res://scenes/match/field_environment.tscn"
var _failures: PackedStringArray = []


## Waits for the headless tree before assembling the real production scene.
func _init() -> void:
	call_deferred("_run")


## Exercises committed snapshots, viewport resizing and the unchanged shared full-field scene.
func _run() -> void:
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i(960, 540)
	root.add_child(viewport)
	var formal := (load(FORMAL_SCENE) as PackedScene).instantiate() as FormalMatchBootstrap
	formal.autonomous_players = false
	viewport.add_child(formal)
	formal.set_process(false)
	var field := formal.get_node("FieldEnvironment") as FieldEnvironment
	var camera := field._camera
	var initial := formal.get_snapshot()
	_check(initial != null, "Formal scene publishes its initial snapshot")
	if initial != null:
		_check(is_equal_approx(camera.position.x, field.field_to_world(initial.ball.position_m).x),
			"Initial snapshot immediately centers on the kickoff ball")
		var pitch_area := 299.0 * (723.0 + 787.0) * 0.5
		var view_area := 960.0 * 540.0 / (camera.zoom.x * camera.zoom.y)
		_check(absf(view_area / pitch_area - 0.25) < 0.01, "Default frame covers a quarter of the projected pitch")
		var zoom := camera.zoom
		viewport.size = Vector2i(1280, 720)
		_check(camera.zoom.is_equal_approx(zoom * 4.0 / 3.0), "Resize scales both axes uniformly")
		viewport.size = Vector2i(960, 540)
		_check(formal.start_match(), "Formal match starts normally")
		_check_follow(formal, field, zoom)
		_check_touchlines(formal, field)
		_check_reset(formal, field)
	formal.free()
	var demo := (load(FIELD_SCENE) as PackedScene).instantiate() as FieldEnvironment
	viewport.add_child(demo)
	demo.configure(Fixture.new().field)
	_check(demo._camera.zoom == Vector2.ONE and demo._camera.position == Vector2.ZERO,
		"The shared demo field still defaults to the fixed full-field frame")
	viewport.free()
	for failure in _failures:
		push_error(failure)
	print("Field camera failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)


## Tests horizontal damping against the ground position and the art-calibrated end limits.
func _check_follow(formal: FormalMatchBootstrap, field: FieldEnvironment, zoom: Vector2) -> void:
	var ball := formal._simulation._ball_runtime_system
	var camera := field._camera
	var from_x := camera.position.x
	var point := Vector2(10.0, 3.0)
	ball.state._launch_shot(point, Vector2.RIGHT, 30.0, 3.0)
	var target_x := field.field_to_world(point).x
	field.present(formal.get_snapshot(), field.camera_follow_half_life_seconds)
	_check(is_equal_approx(camera.position.x, lerpf(from_x, target_x, 0.5)),
		"One half-life closes half the distance to the airborne ball's ground projection")
	_check(camera.position.y == 0.0 and camera.zoom == zoom, "Ball motion inside the safe frame and ball height do not move Y or zoom")
	var half_width := 480.0 / camera.zoom.x
	for side: float in [-1.0, 1.0]:
		ball.reset_ball(Vector2(side * 100.0, 0.0))
		field.present(formal.get_snapshot(), 3.0)
		var edge := camera.position.x + side * half_width
		var expected := field._camera_horizontal_bounds.x if side < 0.0 else field._camera_horizontal_bounds.y
		var goal := field._left_goal if side < 0.0 else field._right_goal
		_check(is_equal_approx(edge, expected), "End framing reaches its configured horizontal limit")
		for sprite in goal.get_children():
			var bounds: Rect2 = goal.transform * sprite.transform * sprite.get_rect()
			_check(bounds.position.x >= camera.position.x - half_width
				and bounds.end.x <= camera.position.x + half_width
				and (bounds.position.x - edge if side < 0.0 else edge - bounds.end.x) >= 15.99,
				"End framing includes the complete corresponding goal width and outer margin")


## Keeps both touchlines in view on the same frame and recenters when the ball returns.
func _check_touchlines(formal: FormalMatchBootstrap, field: FieldEnvironment) -> void:
	var ball := formal._simulation._ball_runtime_system
	var camera := field._camera
	var half_height := 270.0 / camera.zoom.y
	for side: float in [-1.0, 1.0]:
		var point := Vector2(0.0, side * field.field_definition.width_m * 0.5)
		ball.reset_ball(point)
		field.present(formal.get_snapshot())
		var y := field.field_to_world(point).y
		_check(side * camera.position.y > 0.0, "Camera moves toward the touchline")
		_check(absf(y - camera.position.y) <= half_height - 47.99,
			"The ball at either touchline is visible with padding on the same frame")
		var edge_y := camera.position.y
		ball.reset_ball(point + Vector2(0.0, side * 5.0))
		field.present(formal.get_snapshot())
		_check(camera.position.y == edge_y, "Out-of-play ball cannot drag the camera farther")
	ball.reset_ball(Vector2.ZERO)
	field.present(formal.get_snapshot())
	_check(camera.position.y == 0.0, "Camera recenters vertically when the ball returns")


## Uses a real goal settlement and checks the first published next-round frame without extra camera time.
func _check_reset(formal: FormalMatchBootstrap, field: FieldEnvironment) -> void:
	Fixture.new().launch_boundary(formal._simulation, 0.01)
	for step in range(60):
		formal._process(0.05)
		var snapshot := formal.get_snapshot()
		if snapshot.round_sequence > 1:
			_check(snapshot.home_score == 1, "Camera reset follows real goal settlement")
			_check(is_equal_approx(field._camera.position.x, field.field_to_world(snapshot.ball.position_m).x),
				"The first committed next-round frame snaps directly to the reset ball")
			return
	_check(false, "Expected a committed next round")


## Accumulates failures so a single headless run reports every camera contract violation.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
