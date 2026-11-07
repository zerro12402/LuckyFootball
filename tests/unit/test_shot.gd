## Verifies deterministic shooting rules without scenes or rendering.
extends SceneTree

const SHOOTER_ID := "shooter"
const CONFIG_ID := "demo_match"
const FIXED_DELTA := 0.1

var _failures: PackedStringArray = []
var _config: MatchConfigDefinition
var _right_goal_center_m: Vector2


## Loads production CSV rules and runs focused shot behavior checks.
func _init() -> void:
	var repository := DataRepository.new()
	_expect(repository.load_all(), "Expected all static tables to load")
	if not _failures.is_empty():
		_finish()
		return
	_config = repository.get_match_config_by_id(CONFIG_ID)
	var field_definition := repository.get_field_by_id("demo_field")
	_expect(_config != null, "Expected demo match configuration")
	_expect(field_definition != null, "Expected demo field definition")
	if field_definition != null:
		_right_goal_center_m = Vector2(field_definition.length_m * 0.5, 0.0)
	if not _failures.is_empty():
		_finish()
		return
	test_shot_without_possession_is_rejected()
	test_shot_without_goal_configuration_is_rejected()
	test_invalid_goal_registration_is_rejected()
	test_shot_at_goal_center_is_rejected()
	test_zero_power_releases_still_ball()
	test_shot_waits_for_kick_frame_and_rejects_duplicate()
	test_shot_releases_ball_with_event_and_recovery()
	test_shot_power_and_shooting_attribute_change_speed()
	test_shot_apex_height_is_independent_of_shooting_attribute()
	test_shot_power_outside_range_is_clamped()
	test_player_without_shooting_attribute_cannot_shoot()
	test_shot_aims_at_opponent_goal_ignoring_command_direction()
	test_shot_slows_and_stops_as_loose_ball()
	test_same_commands_and_seed_reproduce_ball_motion()
	test_paused_match_rejects_shot_without_advancing()
	_finish()


## Requires ownership before a shot action can start.
func test_shot_without_possession_is_rejected() -> void:
	var simulation := _create_simulation(80, false)
	var events := simulation.advance_fixed_step(FIXED_DELTA, _shot_actions())
	_expect(not _has_event(events, MatchEvent.Type.ACTION_ACCEPTED), "Unowned shot accepted")
	_expect(simulation.create_snapshot().ball.motion_state == BallMatchState.MotionState.LOOSE,
		"Unowned shot changed ball state")


## Rejects a shot when the shooter's team has no opponent goal configured.
func test_shot_without_goal_configuration_is_rejected() -> void:
	var simulation := _create_simulation(80, true, Vector2.ZERO, false, false)
	var events := simulation.advance_fixed_step(FIXED_DELTA, _shot_actions())
	_expect(not _has_event(events, MatchEvent.Type.ACTION_ACCEPTED),
		"Shot without a team goal was accepted")
	var snapshot := simulation.create_snapshot()
	_expect(snapshot.ball.owner_player_id == SHOOTER_ID,
		"Shot without a team goal released the ball")
	_expect(snapshot.get_player(SHOOTER_ID).action_state == PlayerMatchState.ActionState.IDLE,
		"Shot without a team goal changed player action")


## Keeps each team's goal assignment finite, unique, and fixed before kickoff.
func test_invalid_goal_registration_is_rejected() -> void:
	var simulation := MatchSimulation.new(73, _config, null,
		MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN, Callable(), Callable(),
		func() -> int: return ShotAim.Lane.CENTER)
	# Isolate existing contact/shot behavior from the independent F11 accuracy branch.
	simulation._shot_miss_override = 0
	_expect(not simulation.register_team_attacking_goal("", _right_goal_center_m),
		"Empty team ID accepted a goal")
	_expect(not simulation.register_team_attacking_goal("team", Vector2.INF),
		"Non-finite goal center was accepted")
	_expect(simulation.register_team_attacking_goal("team", _right_goal_center_m),
		"Valid opponent goal was rejected")
	_expect(not simulation.register_team_attacking_goal("team", -_right_goal_center_m),
		"Duplicate team goal assignment was accepted")
	_expect(simulation.start_match(), "Expected match start")
	_expect(not simulation.register_team_attacking_goal("another", _right_goal_center_m),
		"Goal changed after kickoff")


## Rejects a zero-length vector when the player stands at the goal center.
func test_shot_at_goal_center_is_rejected() -> void:
	var simulation := _create_simulation(80, true, _right_goal_center_m)
	var events := simulation.advance_fixed_step(FIXED_DELTA, _shot_actions())
	_expect(not _has_event(events, MatchEvent.Type.ACTION_ACCEPTED),
		"Shot from the goal center has no valid direction")
	_expect(simulation.create_snapshot().ball.owner_player_id == SHOOTER_ID,
		"Invalid goal-center shot released the ball")


## Treats minimum power as a valid kick with no ball velocity.
func test_zero_power_releases_still_ball() -> void:
	var simulation := _create_simulation(80)
	simulation.advance_fixed_step(FIXED_DELTA, _shot_actions(0.0))
	var events := simulation.advance_fixed_step(FIXED_DELTA, [])
	var ball := simulation.create_snapshot().ball
	_expect(_has_event(events, MatchEvent.Type.BALL_SHOT), "Zero-power shot event missing")
	_expect(ball.motion_state == BallMatchState.MotionState.LOOSE,
		"Zero-power shot should leave a loose ball")
	_expect(ball.velocity_mps.is_zero_approx(), "Zero-power shot moved the ball")
	_expect(is_zero_approx(ball.height_m), "Zero-power shot rose above the ground")
	_expect(ball.owner_player_id.is_empty(), "Zero-power shot retained possession")
	simulation.advance_fixed_step(FIXED_DELTA, [])
	_expect(simulation.create_snapshot().ball.owner_player_id.is_empty(),
		"Shooter reacquired during recovery")


## Holds possession through windup and admits only one shot.
func test_shot_waits_for_kick_frame_and_rejects_duplicate() -> void:
	var simulation := _create_simulation(80)
	var events := simulation.advance_fixed_step(FIXED_DELTA, _shot_actions())
	_expect(_has_event(events, MatchEvent.Type.ACTION_ACCEPTED), "Shot was rejected")
	_expect(not _has_event(events, MatchEvent.Type.BALL_SHOT), "Shot released early")
	_expect(simulation.create_snapshot().ball.owner_player_id == SHOOTER_ID,
		"Ball left owner before kick frame")
	_expect(simulation.create_snapshot().get_player(SHOOTER_ID).action_state
		== PlayerMatchState.ActionState.SHOOTING, "Player did not enter shooting state")
	events = simulation.advance_fixed_step(0.05, _shot_actions(1.0, Vector2.LEFT))
	_expect(not _has_event(events, MatchEvent.Type.ACTION_ACCEPTED), "Duplicate shot accepted")
	_expect(simulation.create_snapshot().ball.owner_player_id == SHOOTER_ID,
		"Duplicate shot released ball")


## Releases once at the kick frame and keeps the actor in recovery until duration ends.
func test_shot_releases_ball_with_event_and_recovery() -> void:
	var simulation := _create_simulation(80)
	simulation.advance_fixed_step(FIXED_DELTA, _shot_actions())
	var events := simulation.advance_fixed_step(FIXED_DELTA, [])
	var snapshot := simulation.create_snapshot()
	_expect(_has_event(events, MatchEvent.Type.BALL_SHOT), "Missing BALL_SHOT event")
	_expect(snapshot.ball.owner_player_id.is_empty(), "Shot retained owner")
	_expect(snapshot.ball.motion_state == BallMatchState.MotionState.IN_FLIGHT,
		"Shot did not enter independent motion")
	_expect(snapshot.ball.target_player_id.is_empty(), "Shot inherited pass target")
	_expect(snapshot.get_player(SHOOTER_ID).possession_state
		== PlayerMatchState.PossessionState.NO_BALL, "Shooter retained possession")
	_expect(snapshot.ball.position_m.x > 0.55, "Shot did not leave the control point")
	_expect(snapshot.ball.height_m > 0.0, "Shot did not rise after release")
	events = simulation.advance_fixed_step(0.1, _shot_actions())
	_expect(not _has_event(events, MatchEvent.Type.ACTION_ACCEPTED),
		"Shot accepted during recovery")
	simulation.advance_fixed_step(0.15, [])
	_expect(simulation.create_snapshot().get_player(SHOOTER_ID).action_state
		== PlayerMatchState.ActionState.IDLE, "Shot action did not finish")


## Applies command power and the 1–100 shooting attribute monotonically.
func test_shot_power_and_shooting_attribute_change_speed() -> void:
	var weak_speed := _launch_and_get_speed(1, 1.0)
	var strong_speed := _launch_and_get_speed(100, 1.0)
	var soft_speed := _launch_and_get_speed(100, 0.25)
	_expect(weak_speed < strong_speed, "Shooting attribute did not increase speed")
	_expect(soft_speed < strong_speed, "Shot power did not increase speed")
	_expect(is_equal_approx(strong_speed,
		_config.shot_base_speed_mps * _config.shot_max_attribute_multiplier
		- _config.shot_ground_deceleration_mps2 * FIXED_DELTA),
		"Shot speed did not use CSV rules")


## Verifies weak and strong shooters share the configured apex despite different speeds.
func test_shot_apex_height_is_independent_of_shooting_attribute() -> void:
	var weak_peak_height_m := _measure_shot_peak_height(1)
	var strong_peak_height_m := _measure_shot_peak_height(100)
	var soft_peak_height_m := _measure_shot_peak_height(100, 0.5)
	_expect(absf(weak_peak_height_m - _config.shot_apex_height_m) < 0.01,
		"Weak shooter did not reach the configured apex")
	_expect(absf(strong_peak_height_m - _config.shot_apex_height_m) < 0.01,
		"Strong shooter did not reach the configured apex")
	_expect(absf(soft_peak_height_m - _config.shot_apex_height_m) < 0.01,
		"Soft shot did not reach the configured apex")
	_expect(absf(weak_peak_height_m - strong_peak_height_m) < 0.01,
		"Shot apex changed with shooting attribute")


## Clamps intensity to the documented inclusive 0–1 command range.
func test_shot_power_outside_range_is_clamped() -> void:
	_expect(is_equal_approx(_launch_and_get_speed(100, 2.0),
		_launch_and_get_speed(100, 1.0)), "Power above one was not clamped")
	var simulation := _create_simulation(100)
	simulation.advance_fixed_step(FIXED_DELTA, _shot_actions(-1.0))
	simulation.advance_fixed_step(FIXED_DELTA, [])
	_expect(simulation.create_snapshot().ball.velocity_mps.is_zero_approx(),
		"Negative power did not clamp to zero")


## Keeps old test-created players without static attributes unable to shoot.
func test_player_without_shooting_attribute_cannot_shoot() -> void:
	var simulation := _create_simulation(0)
	var events := simulation.advance_fixed_step(FIXED_DELTA, _shot_actions())
	_expect(not _has_event(events, MatchEvent.Type.ACTION_ACCEPTED),
		"Player without shooting attribute accepted a shot")
	_expect(simulation.create_snapshot().ball.owner_player_id == SHOOTER_ID,
		"Rejected shot changed ownership")


## Pins the center lane to isolate goal selection from conflicting direction or facing.
func test_shot_aims_at_opponent_goal_ignoring_command_direction() -> void:
	var right_match := _create_simulation(80)
	right_match.advance_fixed_step(FIXED_DELTA, _shot_actions(1.0, Vector2.LEFT))
	right_match.advance_fixed_step(FIXED_DELTA, [])
	_expect(right_match.create_snapshot().ball.velocity_mps.normalized()
		.is_equal_approx(Vector2.RIGHT), "Right-goal shot followed command direction")
	var left_position_m := Vector2(0.0, 5.0)
	var left_match := _create_simulation(80, true, left_position_m, true)
	left_match.advance_fixed_step(FIXED_DELTA, _shot_actions(1.0, Vector2.RIGHT))
	left_match.advance_fixed_step(FIXED_DELTA, [])
	var left_goal_center_m := Vector2(-_right_goal_center_m.x, 0.0)
	var left_direction := (left_goal_center_m - left_position_m).normalized()
	_expect(left_match.create_snapshot().ball.velocity_mps.normalized()
		.is_equal_approx(left_direction), "Left-goal shot missed the center")
	var high_position_m := Vector2(0.0, -5.0)
	var diagonal_match := _create_simulation(80, true, high_position_m)
	diagonal_match.advance_fixed_step(FIXED_DELTA, _shot_actions(1.0, Vector2.UP))
	diagonal_match.advance_fixed_step(FIXED_DELTA, [])
	var right_direction := (_right_goal_center_m - high_position_m).normalized()
	_expect(diagonal_match.create_snapshot().ball.velocity_mps.normalized()
		.is_equal_approx(right_direction), "Shot ignored the shooter's vertical position")


## Reduces velocity each fixed step and eventually settles with no owner.
func test_shot_slows_and_stops_as_loose_ball() -> void:
	var simulation := _create_simulation(80)
	simulation.advance_fixed_step(FIXED_DELTA, _shot_actions())
	simulation.advance_fixed_step(FIXED_DELTA, [])
	var first_speed := simulation.create_snapshot().ball.velocity_mps.length()
	simulation.advance_fixed_step(FIXED_DELTA, [])
	var second_speed := simulation.create_snapshot().ball.velocity_mps.length()
	_expect(second_speed < first_speed, "Ground shot did not decelerate")
	var landing_x := INF
	for step_index in range(40):
		var current := simulation.create_snapshot().ball
		if current.motion_state == BallMatchState.MotionState.LOOSE:
			break
		if is_inf(landing_x) and is_zero_approx(current.height_m) and current.velocity_mps.x > 0.0:
			landing_x = current.position_m.x
		simulation.advance_fixed_step(FIXED_DELTA, [])
	var ball := simulation.create_snapshot().ball
	_expect(is_finite(landing_x) and ball.position_m.x > landing_x,
		"Shot must travel on the ground after its arc ends")
	_expect(ball.motion_state == BallMatchState.MotionState.LOOSE, "Shot did not stop")
	_expect(ball.velocity_mps.is_zero_approx(), "Stopped shot retained velocity")
	_expect(is_zero_approx(ball.height_m), "Stopped shot remained above ground")
	_expect(ball.owner_player_id.is_empty(), "Stopped shot gained an owner")


## Replays the same fixed-step input against two matches with the same seed.
func test_same_commands_and_seed_reproduce_ball_motion() -> void:
	var first := _create_simulation(65)
	var second := _create_simulation(65)
	var replay_simulations: Array[MatchSimulation] = [first, second]
	for simulation in replay_simulations:
		simulation.advance_fixed_step(FIXED_DELTA, _shot_actions())
		simulation.advance_fixed_step(FIXED_DELTA, [])
		simulation.advance_fixed_step(FIXED_DELTA, [])
	_expect(first.create_snapshot().ball.position_m.is_equal_approx(
		second.create_snapshot().ball.position_m), "Same seed and commands diverged")
	_expect(first.create_snapshot().ball.velocity_mps.is_equal_approx(
		second.create_snapshot().ball.velocity_mps), "Same seed and commands changed velocity")


## Pausing freezes the match clock and all shot initiation.
func test_paused_match_rejects_shot_without_advancing() -> void:
	var simulation := _create_simulation(80)
	_expect(simulation.pause_match(), "Expected pause")
	var before := simulation.create_snapshot()
	var events := simulation.advance_fixed_step(FIXED_DELTA, _shot_actions())
	var after := simulation.create_snapshot()
	_expect(events.is_empty(), "Paused match emitted simulation events")
	_expect(is_equal_approx(before.elapsed_seconds, after.elapsed_seconds),
		"Paused match advanced time")
	_expect(after.ball.owner_player_id == SHOOTER_ID, "Paused shot released ball")


## Creates a player and assigns its team a field-derived opponent goal.
func _create_simulation(
	shooting: int,
	acquire_ball: bool = true,
	player_position_m: Vector2 = Vector2.ZERO,
	attacks_left: bool = false,
	has_goal: bool = true,
) -> MatchSimulation:
	var simulation := MatchSimulation.new(73, _config, null,
		MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN, Callable(), Callable(),
		func() -> int: return ShotAim.Lane.CENTER)
	# Isolate existing contact/shot behavior from the independent F11 accuracy branch.
	simulation._shot_miss_override = 0
	_expect(simulation.register_player(SHOOTER_ID, player_position_m, 5.0, "team", shooting),
		"Expected player registration")
	if has_goal:
		var goal_x := -_right_goal_center_m.x if attacks_left else _right_goal_center_m.x
		_expect(simulation.register_team_attacking_goal("team", Vector2(goal_x, 0.0)),
			"Expected opponent goal registration")
	var ball_offset_m := Vector2(0.5, 0.0) if acquire_ball else Vector2(5.0, 0.0)
	_expect(simulation.register_ball(player_position_m + ball_offset_m),
		"Expected ball registration")
	_expect(simulation.start_match(), "Expected match start")
	if acquire_ball:
		simulation.advance_fixed_step(0.05, [])
	return simulation


## Measures the ball immediately after the configured kick frame.
func _launch_and_get_speed(shooting: int, power: float) -> float:
	var simulation := _create_simulation(shooting)
	simulation.advance_fixed_step(FIXED_DELTA, _shot_actions(power))
	simulation.advance_fixed_step(FIXED_DELTA, [])
	return simulation.create_snapshot().ball.velocity_mps.length()


## Samples the full shot arc through fixed steps and returns its highest ball position.
func _measure_shot_peak_height(shooting: int, power: float = 1.0) -> float:
	var simulation := _create_simulation(shooting)
	simulation.advance_fixed_step(FIXED_DELTA, _shot_actions(power))
	simulation.advance_fixed_step(FIXED_DELTA, [])
	var peak_height_m := simulation.create_snapshot().ball.height_m
	for step_index in range(300):
		if simulation.create_snapshot().ball.motion_state != BallMatchState.MotionState.IN_FLIGHT:
			break
		simulation.advance_fixed_step(0.01, [])
		peak_height_m = maxf(peak_height_m, simulation.create_snapshot().ball.height_m)
	return peak_height_m


## Constructs a typed shot command; its direction is ignored by match rules.
func _shot_actions(power: float = 1.0, direction: Vector2 = Vector2.ZERO) -> Array[MatchAction]:
	return [MatchAction.new(SHOOTER_ID, MatchAction.Type.SHOOT, direction, "", power)]


## Finds one event type in the deterministic step event stream.
func _has_event(events: Array[MatchEvent], event_type: int) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false


## Collects failures and reports the process status once.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Exits with failure only after all independent assertions ran.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
