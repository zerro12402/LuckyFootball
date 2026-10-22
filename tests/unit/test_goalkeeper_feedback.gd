## Reproduces initial-facing, low-lane projection and premature-save feedback without rendering.
extends SceneTree

var _failures: PackedStringArray = []

## Waits until the test tree can host the existing shared scene.
func _init() -> void:
	call_deferred("_run")

## Samples actual snapshots and projected positions before contact and before the goal line.
func _run() -> void:
	var bootstrap := (load("res://scenes/main/game_bootstrap.tscn") as PackedScene).instantiate() as GameBootstrap
	bootstrap.demo_mode = GameBootstrap.DemoMode.GOALKEEPER_TEST
	bootstrap.keeper_lane = ShotAim.Lane.LOWER
	bootstrap.keeper_sample = 0.50
	root.add_child(bootstrap)
	bootstrap.set_process(false)
	var snapshot := bootstrap._match_simulation.create_snapshot()
	_check(snapshot.get_player(bootstrap.demo_opponent_id).facing_direction.x < 0.0,
		"Right-side keeper must initially face the attacking player, not the back net")
	bootstrap.select_keeper_preset()
	bootstrap.set_process(false)
	var first_save_gap := -1.0
	var last_pre_goal_height := -1.0
	var last_pre_goal_y := 0.0
	var config := bootstrap.data_repository.get_match_config_by_id("demo_match")
	var field := bootstrap.data_repository.get_field_by_id("demo_field")
	var projection := FieldArtProjection.create_default(field)
	var sample_near_goal := false
	for step in range(150):
		bootstrap._process(bootstrap.fixed_delta_seconds)
		snapshot = bootstrap._match_simulation.create_snapshot()
		var keeper := snapshot.get_player(bootstrap.demo_opponent_id)
		if first_save_gap < 0.0 and keeper.action_state == PlayerMatchState.ActionState.SAVING:
			first_save_gap = keeper.position_m.distance_to(snapshot.ball.position_m)
			var maximum_lead := (config.keeper_hand_forward_m + config.keeper_contact_radius_m
				+ config.ball_radius_m + snapshot.ball.velocity_mps.length() * bootstrap.fixed_delta_seconds)
			_check(first_save_gap <= maximum_lead,
				"Save pose must start near physical arrival, not immediately after shot release")
		if snapshot.ball.flight_kind == BallMatchState.FlightKind.SHOT and snapshot.ball.position_m.x < 25.0:
			last_pre_goal_height = snapshot.ball.height_m
			var point := projection.field_to_world(snapshot.ball.position_m)
			var pixels_per_meter := point.distance_to(projection.field_to_world(snapshot.ball.position_m + Vector2.RIGHT))
			last_pre_goal_y = point.y - snapshot.ball.height_m * pixels_per_meter
			if snapshot.ball.position_m.x > 24.5:
				sample_near_goal = true
		if snapshot.right_goal_count > 0:
			break
	_check(first_save_gap >= 0.0, "Lower shot must exercise a real save")
	_check(sample_near_goal, "Must sample lower shot before crossing")
	var lower_target_y := projection.field_to_world(Vector2(25.0, 1.0)).y
	_check(last_pre_goal_y > lower_target_y * 0.65,
		"Lower shot must visibly approach the lower goal point instead of the center")
	print("Feedback evidence: first save gap=", first_save_gap,
		"; pre-goal ball height=", last_pre_goal_height,
		"; displayed y=", last_pre_goal_y, "; target y=", lower_target_y)
	bootstrap._match_simulation.advance_fixed_step(0.01, [MatchAction.new("", MatchAction.Type.RESET_ROUND)])
	snapshot = bootstrap._match_simulation.create_snapshot()
	_check(snapshot.get_player(bootstrap.demo_opponent_id).facing_direction.x < 0.0,
		"Round reset must restore the keeper's field-facing direction")
	bootstrap.free()
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)

## Collects independent reproductions to show all three original failures together.
func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
