## Verifies goal, out, event order, and atomic resets in the fixed-step core.
extends SceneTree

const SHOOTER_ID := "shooter"
const TEAM_ID := "team"
const FIXED_DELTA := 0.1

var _field: FieldDefinition
var _config: MatchConfigDefinition
var _failures: PackedStringArray = []


## Loads production definitions and executes the one-ball match scenarios.
func _init() -> void:
	var repository := DataRepository.new()
	_expect(repository.load_all(), "Expected static match and field data")
	if not _failures.is_empty():
		_finish()
		return
	_field = repository.get_field_by_id("demo_field")
	_config = repository.get_match_config_by_id("demo_match")
	test_right_and_left_goals_count_once()
	test_sideline_and_non_goal_baseline_are_out()
	test_dribbled_ball_crosses_boundary_and_resets()
	test_picking_up_ball_at_boundary_waits_to_reset()
	test_receiving_pass_over_end_line_waits_to_reset()
	test_dribble_out_waits_with_idle_player()
	test_vertical_dribble_waits_until_visible_ball_clears_line()
	test_goal_waits_while_shot_ball_keeps_moving()
	test_shot_out_waits_while_ball_keeps_moving()
	test_pause_does_not_consume_settlement_time()
	test_manual_round_reset_cancels_windup_and_keeps_score()
	test_repeated_reset_clears_held_ball_without_changing_spawn()
	test_restart_clears_score_clock_and_old_motion()
	test_reset_during_flight_and_loose_ball_is_stable()
	test_same_commands_produce_same_boundary_result()
	_finish()


## Checks the short displacement from flight contact to the receiver's foot.
func test_receiving_pass_over_end_line_waits_to_reset() -> void:
	for side: float in [-1.0, 1.0]:
		var end_x := side * _field.length_m * 0.5
		var foot_limit := _config.ball_radius_m
		var player_point := Vector2(end_x + side * (foot_limit - 0.25), 5.0)
		var ball_start := player_point - Vector2(side * 1.0, 0.0)
		var simulation := _create_match(Vector2(end_x, 0.0), ball_start, player_point)
		var receiver := simulation._player_runtime_system.get_player(SHOOTER_ID)
		receiver.state._set_facing_direction(Vector2(side, 0.0))
		simulation._ball_runtime_system.state._launch_pass(
			SHOOTER_ID, Vector2(side * 5.0, 0.0), 2.0, 0.0)
		var events := simulation.advance_fixed_step(FIXED_DELTA, [])
		var event := _find_event(events, MatchEvent.Type.BALL_OUT_OF_BOUNDS)
		var expected_side := MatchBoundaryResult.Side.LEFT if side < 0.0 else MatchBoundaryResult.Side.RIGHT
		_expect(event != null and event.side == expected_side,
			"Reception moving the ball beyond either end line must settle as out")
		_expect(simulation.create_snapshot().round_phase == MatchState.RoundPhase.OUT_RESOLVED,
			"End-line reception must wait before reset")


## Both physical goals count once and reset after bounded net motion.
func test_right_and_left_goals_count_once() -> void:
	for attacks_left in [false, true]:
		var goal_x := -_field.length_m * 0.5 if attacks_left else _field.length_m * 0.5
		var simulation := _create_match(Vector2(goal_x, 0.0))
		var events := _shoot_until_result(simulation)
		var goal := _find_event(events, MatchEvent.Type.GOAL_SCORED)
		var expected_side := (
			MatchBoundaryResult.Side.LEFT if attacks_left
			else MatchBoundaryResult.Side.RIGHT
		)
		_expect(goal != null and goal.side == expected_side,
			"Expected goal on the attacked physical side")
		_expect(_find_event(events, MatchEvent.Type.RESET_COMPLETED) == null,
			"Goal reset in the same fixed step")
		if goal != null:
			_expect(goal.last_kicker_id == SHOOTER_ID, "Goal lost the latest kicker")
			_expect(goal.goal_count == 1, "Goal event lacked updated count")
		var waiting_snapshot := simulation.create_snapshot()
		_expect(waiting_snapshot.round_phase == MatchState.RoundPhase.POST_GOAL_MOTION,
			"Goal did not enter the settlement phase")
		_expect(waiting_snapshot.left_goal_count == (1 if attacks_left else 0)
			and waiting_snapshot.right_goal_count == (0 if attacks_left else 1),
			"Physical side count was incorrect")
		_expect(absf(waiting_snapshot.ball.position_m.x) > absf(goal_x),
			"Scored ball was reset before its travel finished")
		var reset_events := _advance_until_auto_reset(
			simulation, MatchEvent.ResetReason.GOAL)
		var reset := _find_event(reset_events, MatchEvent.Type.RESET_COMPLETED)
		_expect(reset != null and reset.side == expected_side,
			"Goal was not followed by a delayed goal reset")
		if goal != null and reset != null:
			_expect(reset.simulation_step - goal.simulation_step <= 12,
				"Goal net motion exceeded its configured maximum")
		var snapshot := simulation.create_snapshot()
		_expect(snapshot.round_phase == MatchState.RoundPhase.PLAYING
			and snapshot.ball.position_m == Vector2.ZERO
			and snapshot.ball.motion_state == BallMatchState.MotionState.LOOSE
			and snapshot.ball.velocity_mps.is_zero_approx(),
			"Goal reset did not center and release the ball")
		_expect(snapshot.get_player(SHOOTER_ID).position_m == Vector2.ZERO
			and snapshot.get_player(SHOOTER_ID).action_state
				== PlayerMatchState.ActionState.IDLE,
			"Goal reset did not restore an actionable player")
		var following_events := simulation.advance_fixed_step(FIXED_DELTA, [])
		_expect(_find_event(following_events, MatchEvent.Type.GOAL_SCORED) == null,
			"One shot scored twice")
		_expect(simulation.create_snapshot().ball.owner_player_id == SHOOTER_ID,
			"Player could not reacquire the reset ball next step")


## Non-goal baseline and sideline exits preserve scores through a delayed reset.
func test_sideline_and_non_goal_baseline_are_out() -> void:
	var cases: Array[Vector2] = [
		Vector2(_field.length_m * 0.5, 10.0),
		Vector2(10.0, _field.width_m),
	]
	var sides: Array[int] = [
		MatchBoundaryResult.Side.RIGHT,
		MatchBoundaryResult.Side.BOTTOM,
	]
	for index in range(cases.size()):
		var simulation := _create_match(cases[index])
		var events := _shoot_until_result(simulation)
		var out_event := _find_event(events, MatchEvent.Type.BALL_OUT_OF_BOUNDS)
		_expect(out_event != null and out_event.side == sides[index],
			"Expected the first non-goal boundary")
		_expect(_find_event(events, MatchEvent.Type.GOAL_SCORED) == null,
			"An out-of-bounds shot scored")
		_expect(_find_event(events, MatchEvent.Type.RESET_COMPLETED) == null,
			"Out-of-bounds shot reset immediately")
		_expect(simulation.create_snapshot().round_phase
			== MatchState.RoundPhase.OUT_RESOLVED,
			"Out-of-bounds shot did not enter settlement")
		var reset_events := _advance_until_auto_reset(
			simulation, MatchEvent.ResetReason.OUT)
		var reset := _find_event(reset_events, MatchEvent.Type.RESET_COMPLETED)
		_expect(reset != null and reset.side == sides[index],
			"Out event did not lead to a delayed reset")
		_expect(simulation.create_snapshot().left_goal_count == 0
			and simulation.create_snapshot().right_goal_count == 0,
			"Out-of-bounds shot changed score")
		_expect(simulation.create_snapshot().ball.position_m == Vector2.ZERO,
			"Out-of-bounds reset did not center the ball")


## A carried ball crossing either boundary idles before a delayed reset.
func test_dribbled_ball_crosses_boundary_and_resets() -> void:
	var directions: Array[Vector2] = [Vector2.DOWN, Vector2.RIGHT]
	var expected_sides: Array[int] = [
		MatchBoundaryResult.Side.BOTTOM,
		MatchBoundaryResult.Side.RIGHT,
	]
	for index in range(directions.size()):
		var simulation := _create_match(Vector2(_field.length_m * 0.5, 0.0))
		var move := MatchAction.new(SHOOTER_ID, MatchAction.Type.MOVE, directions[index])
		var events: Array[MatchEvent] = []
		for step_index in range(80):
			var actions: Array[MatchAction] = []
			if step_index == 0:
				actions.append(move)
			events = simulation.advance_fixed_step(FIXED_DELTA, actions)
			if _find_event(events, MatchEvent.Type.BALL_OUT_OF_BOUNDS) != null:
				break
		var out_event := _find_event(events, MatchEvent.Type.BALL_OUT_OF_BOUNDS)
		_expect(out_event != null and out_event.side == expected_sides[index],
			"Dribbling across a field line did not emit out")
		_expect(_find_event(events, MatchEvent.Type.GOAL_SCORED) == null,
			"Carrying the ball through a goal opening counted as a shot")
		_expect(_find_event(events, MatchEvent.Type.RESET_COMPLETED) == null,
			"Dribble-out reset immediately")
		var waiting_snapshot := simulation.create_snapshot()
		_expect(waiting_snapshot.left_goal_count == 0
			and waiting_snapshot.right_goal_count == 0,
			"Dribbling out changed the score")
		_expect(waiting_snapshot.get_player(SHOOTER_ID).movement_state
			== PlayerMatchState.MovementState.IDLE,
			"Dribbling out did not idle the player")
		var reset_events := _advance_until_auto_reset(
			simulation, MatchEvent.ResetReason.OUT)
		_expect(_find_event(reset_events, MatchEvent.Type.RESET_COMPLETED) != null,
			"Dribble-out reset never completed")
		var snapshot := simulation.create_snapshot()
		_expect(snapshot.ball.position_m == Vector2.ZERO
			and snapshot.ball.motion_state == BallMatchState.MotionState.LOOSE
			and snapshot.ball.owner_player_id.is_empty(),
			"Dribble-out reset left the ball in possession")
		_expect(snapshot.get_player(SHOOTER_ID).position_m == Vector2.ZERO
			and snapshot.get_player(SHOOTER_ID).movement_input == Vector2.ZERO,
			"Dribble-out reset did not restore the player")


## Picking up a near-line ball enters out settlement before resetting.
func test_picking_up_ball_at_boundary_waits_to_reset() -> void:
	var player_start_m := Vector2(_field.length_m * 0.5 + 0.02, 0.0)
	var ball_start_m := Vector2(_field.length_m * 0.5 - 0.2, 0.0)
	var simulation := MatchSimulation.new(77, _config, _field)
	_expect(simulation.register_player(
		SHOOTER_ID, player_start_m, 5.0, TEAM_ID, 100
	), "Expected near-line player registration")
	_expect(simulation.register_team_attacking_goal(
		TEAM_ID, Vector2(_field.length_m * 0.5, 0.0)
	), "Expected near-line team registration")
	_expect(simulation.register_ball(ball_start_m),
		"Expected near-line ball registration")
	_expect(simulation.start_match(), "Expected running near-line match")
	var events := simulation.advance_fixed_step(FIXED_DELTA, [])
	var out_event := _find_event(events, MatchEvent.Type.BALL_OUT_OF_BOUNDS)
	_expect(out_event != null and out_event.side == MatchBoundaryResult.Side.RIGHT,
		"Acquiring a ball into an out-of-bounds control point was missed")
	_expect(_find_event(events, MatchEvent.Type.GOAL_SCORED) == null,
		"Near-line pickup incorrectly counted as a goal")
	_expect(_find_event(events, MatchEvent.Type.RESET_COMPLETED) == null,
		"Near-line pickup reset without a wait")
	_expect(simulation.create_snapshot().round_phase
		== MatchState.RoundPhase.OUT_RESOLVED,
		"Near-line pickup did not enter out settlement")
	var reset_events := _advance_until_auto_reset(
		simulation, MatchEvent.ResetReason.OUT)
	_expect(_find_event(reset_events, MatchEvent.Type.RESET_COMPLETED) != null,
		"Near-line pickup did not complete its delayed reset")
	_expect(simulation.create_snapshot().ball.motion_state
		== BallMatchState.MotionState.LOOSE,
		"Near-line pickup did not release the ball during reset")


## Carried-ball out locks movement for two simulated seconds before resetting.
func test_dribble_out_waits_with_idle_player() -> void:
	var simulation := _create_match(Vector2(_field.length_m * 0.5, 0.0))
	var move := MatchAction.new(SHOOTER_ID, MatchAction.Type.MOVE, Vector2.DOWN)
	var result_events: Array[MatchEvent] = []
	for step_index in range(80):
		var actions: Array[MatchAction] = []
		if step_index == 0:
			actions.append(move)
		result_events = simulation.advance_fixed_step(FIXED_DELTA, actions)
		if _find_event(result_events, MatchEvent.Type.BALL_OUT_OF_BOUNDS) != null:
			break
	_expect(_find_event(result_events, MatchEvent.Type.BALL_OUT_OF_BOUNDS) != null,
		"Expected carried-ball out before waiting")
	_expect(_find_event(result_events, MatchEvent.Type.RESET_COMPLETED) == null,
		"Carried-ball out reset without waiting")
	var waiting_snapshot := simulation.create_snapshot()
	var crossing_position_m := waiting_snapshot.get_player(SHOOTER_ID).position_m
	_expect(waiting_snapshot.round_phase == MatchState.RoundPhase.OUT_RESOLVED,
		"Carried-ball out did not enter a resolved round phase")
	_expect(waiting_snapshot.get_player(SHOOTER_ID).movement_state
		== PlayerMatchState.MovementState.IDLE
		and waiting_snapshot.get_player(SHOOTER_ID).movement_input == Vector2.ZERO,
		"Carried-ball out did not put the player in idle")
	for step_index in range(19):
		var ignored_action := MatchAction.new(
			SHOOTER_ID, MatchAction.Type.MOVE, Vector2.UP)
		var events := simulation.advance_fixed_step(FIXED_DELTA, [ignored_action])
		_expect(_find_event(events, MatchEvent.Type.ACTION_ACCEPTED) == null,
			"Settlement accepted player movement")
		_expect(_find_event(events, MatchEvent.Type.RESET_COMPLETED) == null,
			"Carried-ball out reset before two seconds")
		_expect(simulation.create_snapshot().get_player(SHOOTER_ID).position_m
			== crossing_position_m, "Idle player moved during settlement")
	var reset_events := simulation.advance_fixed_step(FIXED_DELTA, [])
	_expect(_find_event(reset_events, MatchEvent.Type.RESET_COMPLETED) != null,
		"Carried-ball out did not reset at two seconds")
	_expect(simulation.create_snapshot().get_player(SHOOTER_ID).position_m == Vector2.ZERO,
		"Delayed reset did not restore the player")



## Vertical dribbling waits for the visible ball to clear either sideline.
func test_vertical_dribble_waits_until_visible_ball_clears_line() -> void:
	var start_y_values: Array[float] = [-14.7, 14.7]
	var directions: Array[Vector2] = [Vector2.UP, Vector2.DOWN]
	var expected_sides: Array[int] = [
		MatchBoundaryResult.Side.TOP,
		MatchBoundaryResult.Side.BOTTOM,
	]
	for index in range(start_y_values.size()):
		var player_start_m := Vector2(0.0, start_y_values[index])
		var ball_start_m := player_start_m + Vector2(0.55, 0.0)
		var simulation := _create_match(
			Vector2(_field.length_m * 0.5, 0.0),
			ball_start_m,
			player_start_m,
		)
		_expect(simulation.create_snapshot().ball.owner_player_id == SHOOTER_ID,
			"Expected possession before approaching the sideline")
		var move := MatchAction.new(SHOOTER_ID, MatchAction.Type.MOVE, directions[index])
		var before_clearance := simulation.advance_fixed_step(FIXED_DELTA, [move])
		_expect(_find_event(before_clearance, MatchEvent.Type.BALL_OUT_OF_BOUNDS)
			== null, "Vertical dribble settled while the ball still overlapped the line")
		_expect(simulation.create_snapshot().get_player(SHOOTER_ID).movement_state
			== PlayerMatchState.MovementState.MOVING,
			"Player was idled before the ball cleared the line")
		var after_clearance := simulation.advance_fixed_step(FIXED_DELTA, [])
		var out_event := _find_event(
			after_clearance, MatchEvent.Type.BALL_OUT_OF_BOUNDS)
		_expect(out_event != null and out_event.side == expected_sides[index],
			"Vertical dribble did not settle after the visible ball cleared the line")


## A scored shot contacts the back net before its bounded reset.
func test_goal_waits_while_shot_ball_keeps_moving() -> void:
	var simulation := _create_match(Vector2(_field.length_m * 0.5, 0.0))
	var result_events := _shoot_until_result(simulation)
	_expect(_find_event(result_events, MatchEvent.Type.GOAL_SCORED) != null,
		"Expected a goal before net motion")
	var all_events: Array[MatchEvent] = result_events.duplicate()
	var reset: MatchEvent
	for step_index in range(20):
		var events := simulation.advance_fixed_step(FIXED_DELTA, [
			MatchAction.new(SHOOTER_ID, MatchAction.Type.SHOOT),
		])
		_expect(_find_event(events, MatchEvent.Type.ACTION_ACCEPTED) == null,
			"Shot command was accepted during goal net motion")
		_expect(_find_event(events, MatchEvent.Type.GOAL_SCORED) == null,
			"Goal was counted again during net motion")
		all_events.append_array(events)
		reset = _find_event(events, MatchEvent.Type.RESET_COMPLETED)
		if reset != null:
			break
	var contact := _find_event(all_events, MatchEvent.Type.GOAL_NET_CONTACT)
	_expect(contact != null and contact.net_surface == GoalNetContact.Surface.BACK,
		"Scored ball did not contact the back net")
	if contact != null:
		_expect(absf(contact.contact_position_m.x
			- (_field.length_m * 0.5 + _field.goal_depth_m)) < 0.001,
			"Back-net contact used the wrong plane")
		_expect(contact.velocity_after_mps.x < 0.0
			and contact.velocity_after_mps.length() < contact.velocity_before_mps.length(),
			"Back net did not slow and reverse the ball")
	_expect(reset != null and reset.reason == MatchEvent.ResetReason.GOAL,
		"Goal net motion did not end in a goal reset")
	_expect(_event_index(all_events, MatchEvent.Type.GOAL_SCORED)
		< _event_index(all_events, MatchEvent.Type.GOAL_NET_CONTACT)
		and _event_index(all_events, MatchEvent.Type.GOAL_NET_CONTACT)
		< _event_index(all_events, MatchEvent.Type.RESET_COMPLETED),
		"Goal, net, and reset events were out of order")


## A shot that misses the goal also keeps moving until its delayed reset.
func test_shot_out_waits_while_ball_keeps_moving() -> void:
	var target_m := Vector2(_field.length_m * 0.5, 10.0)
	var simulation := _create_match(target_m)
	var result_events := _shoot_until_result(simulation)
	_expect(_find_event(result_events, MatchEvent.Type.BALL_OUT_OF_BOUNDS) != null,
		"Expected a shot to miss the goal")
	_expect(_find_event(result_events, MatchEvent.Type.RESET_COMPLETED) == null,
		"Missed shot reset immediately")
	var previous_position_m := simulation.create_snapshot().ball.position_m
	for step_index in range(19):
		var events := simulation.advance_fixed_step(FIXED_DELTA, [])
		_expect(_find_event(events, MatchEvent.Type.RESET_COMPLETED) == null,
			"Missed shot reset before two seconds")
		var current_position_m := simulation.create_snapshot().ball.position_m
		_expect(current_position_m.distance_to(target_m)
			> previous_position_m.distance_to(target_m),
			"Out-of-bounds shot stopped before its two-second window")
		previous_position_m = current_position_m
	var reset_events := simulation.advance_fixed_step(FIXED_DELTA, [])
	_expect(_find_event(reset_events, MatchEvent.Type.RESET_COMPLETED) != null,
		"Out-of-bounds shot did not reset at two seconds")


## Pausing the match freezes the settlement timer and out-of-play trajectory.
func test_pause_does_not_consume_settlement_time() -> void:
	var simulation := _create_match(Vector2(_field.length_m * 0.5, 0.0))
	_shoot_until_result(simulation)
	var paused_position_m := simulation.create_snapshot().ball.position_m
	var paused_step := simulation.create_snapshot().simulation_step
	_expect(simulation.pause_match(), "Expected active settlement to pause")
	for step_index in range(30):
		var events := simulation.advance_fixed_step(FIXED_DELTA, [])
		_expect(events.is_empty(), "Paused settlement emitted a simulation event")
	_expect(simulation.create_snapshot().simulation_step == paused_step
		and simulation.create_snapshot().ball.position_m == paused_position_m,
		"Paused settlement advanced its timer or trajectory")
	_expect(simulation.resume_match(), "Expected paused settlement to resume")
	var reset_events := _advance_until_auto_reset(
		simulation, MatchEvent.ResetReason.GOAL)
	_expect(_find_event(reset_events, MatchEvent.Type.RESET_COMPLETED) != null,
		"Resumed settlement did not finish after two active seconds")


## A manual reset interrupts settlement and preserves an earlier goal.
func test_manual_round_reset_cancels_windup_and_keeps_score() -> void:
	var simulation := _create_match(Vector2(_field.length_m * 0.5, 0.0))
	_shoot_until_result(simulation)
	var shooting := MatchAction.new(SHOOTER_ID, MatchAction.Type.SHOOT)
	var ignored_events := simulation.advance_fixed_step(FIXED_DELTA, [shooting])
	_expect(_find_event(ignored_events, MatchEvent.Type.ACTION_ACCEPTED) == null,
		"Shot command was accepted during settlement")
	var reset := MatchAction.new("", MatchAction.Type.RESET_ROUND)
	var events := simulation.advance_fixed_step(FIXED_DELTA, [shooting, reset])
	_expect(_find_event(events, MatchEvent.Type.BALL_SHOT) == null,
		"Kick escaped a same-step reset")
	_expect(_find_event(events, MatchEvent.Type.RESET_COMPLETED).reason
		== MatchEvent.ResetReason.MANUAL_ROUND, "Manual reset reason was lost")
	var snapshot := simulation.create_snapshot()
	_expect(snapshot.right_goal_count == 1, "Round reset erased the score")
	_expect(snapshot.round_phase == MatchState.RoundPhase.PLAYING,
		"Manual reset left the match in settlement")
	_expect(snapshot.ball.position_m == Vector2(0.5, 0.0)
		and snapshot.ball.velocity_mps.is_zero_approx(),
		"Round reset did not restore the registered test ball position")
	_expect(snapshot.get_player(SHOOTER_ID).action_state
		== PlayerMatchState.ActionState.IDLE,
		"Round reset kept the shooting windup")
	events = simulation.advance_fixed_step(FIXED_DELTA, [])
	_expect(_find_event(events, MatchEvent.Type.BALL_SHOT) == null,
		"Old kick fired after reset")


## Repeating a reset from possession yields the same actionable spawn state.
func test_repeated_reset_clears_held_ball_without_changing_spawn() -> void:
	var simulation := _create_match(Vector2(_field.length_m * 0.5, 0.0))
	_expect(simulation.create_snapshot().ball.owner_player_id == SHOOTER_ID,
		"Expected possession before manual reset")
	var reset_action := MatchAction.new("", MatchAction.Type.RESET_ROUND)
	simulation.advance_fixed_step(FIXED_DELTA, [reset_action])
	var first := simulation.create_snapshot()
	simulation.advance_fixed_step(FIXED_DELTA, [reset_action])
	var second := simulation.create_snapshot()
	_expect(first.ball.position_m == second.ball.position_m
		and first.ball.motion_state == second.ball.motion_state
		and first.ball.owner_player_id == second.ball.owner_player_id,
		"Repeated reset changed the free-ball initial state")
	_expect(second.get_player(SHOOTER_ID).movement_input == Vector2.ZERO
		and second.get_player(SHOOTER_ID).possession_state
			== PlayerMatchState.PossessionState.NO_BALL
		and second.get_player(SHOOTER_ID).action_state
			== PlayerMatchState.ActionState.IDLE,
		"Repeated reset left a player action or possession behind")


## Restart restores the original test state and erases cumulative goal counts.
func test_restart_clears_score_clock_and_old_motion() -> void:
	var simulation := _create_match(Vector2(_field.length_m * 0.5, 0.0))
	_shoot_until_result(simulation)
	var restart := MatchAction.new("", MatchAction.Type.RESTART_TEST)
	var events := simulation.advance_fixed_step(FIXED_DELTA, [restart])
	var snapshot := simulation.create_snapshot()
	_expect(_find_event(events, MatchEvent.Type.RESET_COMPLETED).reason
		== MatchEvent.ResetReason.RESTART_TEST, "Restart reason was lost")
	_expect(snapshot.left_goal_count == 0 and snapshot.right_goal_count == 0,
		"Restart kept the old score")
	_expect(snapshot.simulation_step == 0 and is_zero_approx(snapshot.elapsed_seconds),
		"Restart kept the old clock")
	_expect(snapshot.ball.position_m == Vector2(0.5, 0.0)
		and snapshot.ball.owner_player_id.is_empty(),
		"Restart did not restore the original free ball")
	for past_event in simulation.get_event_history():
		_expect(past_event.event_type != MatchEvent.Type.GOAL_SCORED,
			"Restart kept the previous test's goal record")


## Reset from active flight or a still-loose initial ball leaves no trajectory.
func test_reset_during_flight_and_loose_ball_is_stable() -> void:
	var simulation := _create_match(Vector2(_field.length_m * 0.5, 0.0))
	simulation.advance_fixed_step(FIXED_DELTA, [
		MatchAction.new(SHOOTER_ID, MatchAction.Type.SHOOT)])
	simulation.advance_fixed_step(FIXED_DELTA, [])
	_expect(simulation.create_snapshot().ball.motion_state
		== BallMatchState.MotionState.IN_FLIGHT, "Expected flight before reset")
	simulation.advance_fixed_step(FIXED_DELTA, [
		MatchAction.new("", MatchAction.Type.RESET_ROUND)])
	var position_after_reset := simulation.create_snapshot().ball.position_m
	_expect(position_after_reset == Vector2(0.5, 0.0),
		"Flight reset did not restore test position")
	var following_events := simulation.advance_fixed_step(FIXED_DELTA, [])
	_expect(_find_event(following_events, MatchEvent.Type.BALL_SHOT) == null
		and simulation.create_snapshot().ball.velocity_mps.is_zero_approx(),
		"Old flight continued after reset")
	var loose := _create_match(Vector2(25.0, 0.0), Vector2(3.0, 0.0))
	loose.advance_fixed_step(FIXED_DELTA, [
		MatchAction.new("", MatchAction.Type.RESET_ROUND)])
	_expect(loose.create_snapshot().ball.position_m == Vector2(3.0, 0.0)
		and loose.create_snapshot().ball.motion_state == BallMatchState.MotionState.LOOSE,
		"Loose-ball reset changed the registered initial state")


## Identical seeded matches produce the same result step, side, and counts.
func test_same_commands_produce_same_boundary_result() -> void:
	var first := _create_match(Vector2(_field.length_m * 0.5, 0.0))
	var second := _create_match(Vector2(_field.length_m * 0.5, 0.0))
	var first_events := _shoot_until_result(first)
	var second_events := _shoot_until_result(second)
	var first_goal := _find_event(first_events, MatchEvent.Type.GOAL_SCORED)
	var second_goal := _find_event(second_events, MatchEvent.Type.GOAL_SCORED)
	_expect(first_goal != null and second_goal != null
		and first_goal.simulation_step == second_goal.simulation_step
		and first_goal.side == second_goal.side
		and first_goal.ball_position_m.is_equal_approx(second_goal.ball_position_m),
		"Same seed and commands produced different goal events")
	_expect(first.create_snapshot().right_goal_count
		== second.create_snapshot().right_goal_count,
		"Same replay produced different score")


## Registers one controllable shooter and a configurable test trajectory target.
func _create_match(
	goal_center_m: Vector2,
	initial_ball_position_m: Vector2 = Vector2(0.5, 0.0),
	player_initial_position_m: Vector2 = Vector2.ZERO,
) -> MatchSimulation:
	var simulation := MatchSimulation.new(77, _config, _field)
	_expect(simulation.register_player(
		SHOOTER_ID, player_initial_position_m, 5.0, TEAM_ID, 100
	),
		"Expected shooter registration")
	_expect(simulation.register_team_attacking_goal(TEAM_ID, goal_center_m),
		"Expected trajectory target registration")
	_expect(simulation.register_ball(initial_ball_position_m),
		"Expected ball registration")
	_expect(simulation.start_match(), "Expected running test match")
	if initial_ball_position_m.distance_to(player_initial_position_m) < 0.75:
		simulation.advance_fixed_step(0.05, [])
	return simulation


## Launches one shot and returns the first settled boundary step's event stream.
func _shoot_until_result(simulation: MatchSimulation) -> Array[MatchEvent]:
	simulation.advance_fixed_step(FIXED_DELTA, [
		MatchAction.new(SHOOTER_ID, MatchAction.Type.SHOOT)])
	for step_index in range(50):
		var events := simulation.advance_fixed_step(FIXED_DELTA, [])
		if _find_event(events, MatchEvent.Type.GOAL_SCORED) != null:
			return events
		if _find_event(events, MatchEvent.Type.BALL_OUT_OF_BOUNDS) != null:
			return events
	_expect(false, "Shot did not reach a boundary")
	var empty_events: Array[MatchEvent] = []
	return empty_events


## Waits for the configured goal limit or the existing two-second out window.
func _advance_until_auto_reset(
	simulation: MatchSimulation,
	expected_reason: int,
) -> Array[MatchEvent]:
	for step_index in range(20):
		var events := simulation.advance_fixed_step(FIXED_DELTA, [])
		_expect(_find_event(events, MatchEvent.Type.GOAL_SCORED) == null
			and _find_event(events, MatchEvent.Type.BALL_OUT_OF_BOUNDS) == null,
			"Boundary result repeated during settlement")
		if _find_event(events, MatchEvent.Type.RESET_COMPLETED) != null:
			_expect(_find_event(events, MatchEvent.Type.RESET_COMPLETED).reason
				== expected_reason, "Automatic reset used the wrong reason")
			return events
	_expect(false, "Automatic reset did not occur by two simulated seconds")
	var empty_events: Array[MatchEvent] = []
	return empty_events


## Finds a type in the ordered events from one fixed simulation step.
func _find_event(events: Array[MatchEvent], event_type: int) -> MatchEvent:
	for event in events:
		if event.event_type == event_type:
			return event
	return null


## Returns the earliest matching index for event-order assertions.
func _event_index(events: Array[MatchEvent], event_type: int) -> int:
	for index in range(events.size()):
		if events[index].event_type == event_type:
			return index
	return 9999


## Stores failures without interrupting independent scenarios.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Exits after reporting all failed fixed-step invariants.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
