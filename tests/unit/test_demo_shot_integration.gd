## Exercises K-key shooting through demo bootstrap without any rendering.
extends SceneTree

var _snapshot: MatchStateSnapshot
var _shot_event_count: int = 0
var _shot_aim: ShotAim
var _failures: PackedStringArray = []


## Waits until nodes can enter the tree before building a demo match.
func _init() -> void:
	call_deferred("_run_test")


## Moves above the center line, then checks K shoots toward its locked right-goal target.
func _run_test() -> void:
	var bootstrap := GameBootstrap.new()
	var keyboard := KeyboardPlayerInputAdapter.new()
	keyboard.name = "KeyboardPlayerInputAdapter"
	bootstrap.add_child(keyboard)
	bootstrap.presentation_frame_ready.connect(_record_frame)
	root.add_child(bootstrap)
	_expect(_snapshot != null, "Demo did not publish its initial state")
	if _snapshot == null:
		bootstrap.queue_free()
		_finish()
		return
	var repository := DataRepository.new()
	_expect(repository.load_all(), "Demo data failed to load")
	var shooter_id := repository.player_definitions[0].player_id
	bootstrap.queue_action(MatchAction.new(shooter_id, MatchAction.Type.MOVE, Vector2.RIGHT))
	for step_index in range(60):
		bootstrap._process(bootstrap.fixed_delta_seconds)
		if _snapshot.ball.owner_player_id == shooter_id:
			break
	_expect(_snapshot.ball.owner_player_id == shooter_id,
		"Demo player did not acquire the ball")
	bootstrap.queue_action(MatchAction.new(shooter_id, MatchAction.Type.MOVE, Vector2.UP))
	for step_index in range(12):
		bootstrap._process(bootstrap.fixed_delta_seconds)
	bootstrap.queue_action(MatchAction.new(shooter_id, MatchAction.Type.MOVE, Vector2.ZERO))
	bootstrap._process(bootstrap.fixed_delta_seconds)
	var shot_origin_m := _snapshot.get_player(shooter_id).position_m
	var field_definition := repository.get_field_by_id("demo_field")
	var goal_center_m := Vector2(field_definition.length_m * 0.5, 0.0)
	var expected_direction := (goal_center_m - shot_origin_m).normalized()
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_K
	key_event.pressed = true
	keyboard._unhandled_key_input(key_event)
	for step_index in range(20):
		bootstrap._process(bootstrap.fixed_delta_seconds)
	_expect(_shot_event_count == 1, "Demo K key did not produce one BALL_SHOT event")
	_expect(_snapshot.ball.owner_player_id.is_empty(), "Demo shot retained ball ownership")
	_expect(_snapshot.ball.velocity_mps.length() > 0.0,
		"Demo shot did not launch the ball")
	_expect(_shot_aim != null, "Shot must expose its locked goal target")
	if _shot_aim != null:
		expected_direction = (_shot_aim.point_m - shot_origin_m).normalized()
	_expect(_snapshot.ball.velocity_mps.normalized().is_equal_approx(expected_direction),
		"Demo shot did not aim at its locked opponent-goal target")
	bootstrap.queue_free()
	_finish()


## Collects the newest snapshot and counts release events across fixed steps.
func _record_frame(
	snapshot: MatchStateSnapshot,
	events: Array[MatchEvent],
	_interpolation_alpha: float,
) -> void:
	_snapshot = snapshot
	for event in events:
		if event.event_type == MatchEvent.Type.BALL_SHOT:
			_shot_aim = event.shot_aim
			_shot_event_count += 1


## Records an integration failure while later assertions can still run.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Reports all integration failures at process exit.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
