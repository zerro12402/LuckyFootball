extends SceneTree

const PASSER_ID := "passer"
const RECEIVER_ID := "receiver"
const PASS_SPEED_MPS := 14.0

var _failures: PackedStringArray = []


func _init() -> void:
	test_pass_without_possession_is_rejected()
	test_pass_to_unknown_or_self_is_rejected()
	test_pass_to_opponent_or_distant_teammate_is_rejected()
	test_pass_near_maximum_range_is_accepted()
	test_second_pass_during_windup_is_rejected()
	test_pass_when_queued_waits_for_windup()
	test_pass_after_windup_releases_ball_and_enters_flight()
	test_flying_pass_when_crossing_receiver_transfers_possession()
	test_flying_pass_when_receiver_escapes_becomes_loose()
	test_receiver_when_possessing_can_pass_back()
	test_short_pass_below_loft_threshold_stays_grounded()
	test_long_pass_above_loft_threshold_rises()
	test_long_pass_in_flight_follows_parabolic_height()
	test_long_pass_when_receiver_crosses_high_arc_is_not_caught()
	test_long_pass_when_received_returns_to_ground()
	test_long_pass_when_missed_lands_at_original_target()
	test_long_pass_when_target_moves_beyond_range_lands_at_maximum()

	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func test_pass_without_possession_is_rejected() -> void:
	var simulation := _create_simulation(Vector2(6.0, 0.0), "team_a", false)
	var events := simulation.advance_fixed_step(0.1, _pass_actions())
	_expect(
		not _has_event(events, MatchEvent.Type.ACTION_ACCEPTED),
		"Expected a pass without possession to be rejected",
	)


func test_pass_to_unknown_or_self_is_rejected() -> void:
	var simulation := _create_simulation()
	for target_id in ["missing_player", PASSER_ID]:
		var events := simulation.advance_fixed_step(
			0.1,
			[MatchAction.new(PASSER_ID, MatchAction.Type.PASS, Vector2.ZERO, target_id)],
		)
		_expect(
			not _has_event(events, MatchEvent.Type.ACTION_ACCEPTED),
			"Expected invalid target to be rejected: " + target_id,
		)
	_expect(
		simulation.create_snapshot().ball.owner_player_id == PASSER_ID,
		"Expected rejected passes to preserve ball ownership",
	)


func test_pass_to_opponent_or_distant_teammate_is_rejected() -> void:
	var opponent_match := _create_simulation(Vector2(6.0, 0.0), "team_b")
	var opponent_events := opponent_match.advance_fixed_step(0.1, _pass_actions())
	_expect(
		not _has_event(opponent_events, MatchEvent.Type.ACTION_ACCEPTED),
		"Expected a pass to an opponent to be rejected",
	)
	var distant_match := _create_simulation(Vector2(25.0, 0.0))
	var distant_events := distant_match.advance_fixed_step(0.1, _pass_actions())
	_expect(
		not _has_event(distant_events, MatchEvent.Type.ACTION_ACCEPTED),
		"Expected a pass beyond maximum range to be rejected",
	)


func test_pass_near_maximum_range_is_accepted() -> void:
	var simulation := _create_simulation(Vector2(20.5, 0.0))
	var events := simulation.advance_fixed_step(0.1, _pass_actions())
	_expect(
		_has_event(events, MatchEvent.Type.ACTION_ACCEPTED),
		"Expected a teammate within the maximum range to be a valid target",
	)


func test_second_pass_during_windup_is_rejected() -> void:
	var simulation := _create_simulation()
	simulation.advance_fixed_step(0.05, _pass_actions())
	var events := simulation.advance_fixed_step(0.05, _pass_actions())
	_expect(
		not _has_event(events, MatchEvent.Type.ACTION_ACCEPTED),
		"Expected a second pass during windup to be rejected",
	)
	_expect(
		simulation.create_snapshot().ball.motion_state == BallMatchState.MotionState.OWNED,
		"Expected ball to remain owned until the first pass reaches its kick frame",
	)

func test_pass_when_queued_waits_for_windup() -> void:
	var simulation := _create_simulation()
	var events := simulation.advance_fixed_step(0.1, _pass_actions())
	var snapshot := simulation.create_snapshot()
	var passer := snapshot.get_player(PASSER_ID)
	_expect(_has_event(events, MatchEvent.Type.ACTION_ACCEPTED), "Expected valid pass")
	_expect(
		not _has_event(events, MatchEvent.Type.BALL_PASSED),
		"Expected ball release to wait for the kick frame",
	)
	_expect(
		snapshot.ball.motion_state == BallMatchState.MotionState.OWNED,
		"Expected ball to remain owned during pass windup",
	)
	_expect(
		passer.action_state == PlayerMatchState.ActionState.PASSING,
		"Expected passer to play the passing action",
	)


func test_pass_after_windup_releases_ball_and_enters_flight() -> void:
	var simulation := _create_simulation()
	simulation.advance_fixed_step(0.1, _pass_actions())
	var events := simulation.advance_fixed_step(0.1, _no_actions())
	var snapshot := simulation.create_snapshot()
	var passer := snapshot.get_player(PASSER_ID)
	_expect(_has_event(events, MatchEvent.Type.BALL_PASSED), "Expected pass event")
	_expect(
		snapshot.ball.motion_state == BallMatchState.MotionState.IN_FLIGHT,
		"Expected ball to fly independently after the kick",
	)
	_expect(snapshot.ball.owner_player_id.is_empty(), "Expected owner to be released")
	_expect(snapshot.ball.target_player_id == RECEIVER_ID, "Expected pass target ID")
	_expect(
		is_equal_approx(snapshot.ball.velocity_mps.length(), PASS_SPEED_MPS),
		"Expected configured pass speed",
	)
	_expect(
		passer.possession_state == PlayerMatchState.PossessionState.NO_BALL,
		"Expected passer to lose possession",
	)


func test_flying_pass_when_crossing_receiver_transfers_possession() -> void:
	var simulation := _create_simulation()
	_start_flight(simulation)
	var events := simulation.advance_fixed_step(0.4, _no_actions())
	var snapshot := simulation.create_snapshot()
	var passer := snapshot.get_player(PASSER_ID)
	var receiver := snapshot.get_player(RECEIVER_ID)
	_expect(
		snapshot.ball.motion_state == BallMatchState.MotionState.OWNED,
		"Expected a pass crossing the receiver to be caught",
	)
	_expect(
		snapshot.ball.owner_player_id == RECEIVER_ID,
		"Expected receiver to own the ball",
	)
	_expect(
		receiver.possession_state == PlayerMatchState.PossessionState.POSSESSING,
		"Expected receiver possession state",
	)
	_expect(
		_has_event(events, MatchEvent.Type.BALL_PASS_RECEIVED),
		"Expected pass received event",
	)
	_expect(
		passer.action_state == PlayerMatchState.ActionState.IDLE,
		"Expected pass animation to finish after recovery",
	)


func test_flying_pass_when_receiver_escapes_becomes_loose() -> void:
	var simulation := _create_simulation(Vector2(6.0, 0.0), "team_a", true, 10.0)
	_start_flight(simulation)
	var move_actions: Array[MatchAction] = [
		MatchAction.new(RECEIVER_ID, MatchAction.Type.MOVE, Vector2.UP),
	]
	simulation.advance_fixed_step(0.5, move_actions)
	simulation.advance_fixed_step(0.5, _no_actions())
	var events := simulation.advance_fixed_step(0.5, _no_actions())
	var snapshot := simulation.create_snapshot()
	_expect(
		snapshot.ball.motion_state == BallMatchState.MotionState.LOOSE,
		"Expected missed pass to become a loose ball",
	)
	_expect(snapshot.ball.owner_player_id.is_empty(), "Expected missed ball without owner")
	_expect(
		_has_event(events, MatchEvent.Type.BALL_PASS_MISSED),
		"Expected pass missed event",
	)


func test_receiver_when_possessing_can_pass_back() -> void:
	var simulation := _create_simulation()
	_start_flight(simulation)
	simulation.advance_fixed_step(0.4, _no_actions())
	var actions: Array[MatchAction] = [
		MatchAction.new(
			RECEIVER_ID,
			MatchAction.Type.PASS,
			Vector2.ZERO,
			PASSER_ID,
		),
	]
	var events := simulation.advance_fixed_step(0.1, actions)
	_expect(
		_has_event(events, MatchEvent.Type.ACTION_ACCEPTED),
		"Expected receiver to be able to pass back",
	)


func test_short_pass_below_loft_threshold_stays_grounded() -> void:
	var simulation := _create_simulation(Vector2(6.5, 0.0))
	_start_flight(simulation)
	var ball := simulation.create_snapshot().ball
	_expect(ball.motion_state == BallMatchState.MotionState.IN_FLIGHT, "Expected short flight")
	_expect(is_zero_approx(ball.height_m), "Expected short pass to stay on the ground")


func test_long_pass_above_loft_threshold_rises() -> void:
	var simulation := _create_simulation(Vector2(6.6, 0.0))
	_start_flight(simulation)
	var ball := simulation.create_snapshot().ball
	_expect(ball.motion_state == BallMatchState.MotionState.IN_FLIGHT, "Expected long flight")
	_expect(ball.height_m > 0.0, "Expected long pass to rise above the ground")


func test_long_pass_in_flight_follows_parabolic_height() -> void:
	var simulation := _create_simulation(Vector2(10.55, 0.0))
	_start_flight(simulation)
	var rising_height_m := simulation.create_snapshot().ball.height_m
	simulation.advance_fixed_step(0.25, _no_actions())
	var apex_height_m := simulation.create_snapshot().ball.height_m
	simulation.advance_fixed_step(0.15, _no_actions())
	var falling_height_m := simulation.create_snapshot().ball.height_m
	_expect(
		rising_height_m > 0.0 and rising_height_m < apex_height_m,
		"Expected ball to rise toward the middle of the pass",
	)
	_expect(
		absf(apex_height_m - BallRuntimeSystem.DEFAULT_LOFTED_PASS_APEX_HEIGHT_M) < 0.05,
		"Expected configured parabolic apex near the flight midpoint",
	)
	_expect(
		falling_height_m > 0.0 and falling_height_m < apex_height_m,
		"Expected ball to descend after the flight midpoint",
	)


func test_long_pass_when_receiver_crosses_high_arc_is_not_caught() -> void:
	var simulation := _create_simulation(Vector2(10.55, 0.0), "team_a", true, 10.0)
	_start_flight(simulation)
	var move_actions: Array[MatchAction] = [
		MatchAction.new(RECEIVER_ID, MatchAction.Type.MOVE, Vector2.LEFT),
	]
	var events := simulation.advance_fixed_step(0.4, move_actions)
	var ball := simulation.create_snapshot().ball
	_expect(ball.motion_state == BallMatchState.MotionState.IN_FLIGHT, "Expected ball in air")
	_expect(ball.height_m > BallRuntimeSystem.MAX_RECEIVE_HEIGHT_M, "Expected high ball")
	_expect(
		not _has_event(events, MatchEvent.Type.BALL_PASS_RECEIVED),
		"Expected receiver beneath high ball not to catch it",
	)

func test_long_pass_when_received_returns_to_ground() -> void:
	var simulation := _create_simulation(Vector2(10.55, 0.0))
	_start_flight(simulation)
	var events := simulation.advance_fixed_step(0.7, _no_actions())
	var ball := simulation.create_snapshot().ball
	_expect(ball.motion_state == BallMatchState.MotionState.OWNED, "Expected long pass received")
	_expect(ball.owner_player_id == RECEIVER_ID, "Expected intended receiver to own ball")
	_expect(is_zero_approx(ball.height_m), "Expected received ball at ground height")
	_expect(_has_event(events, MatchEvent.Type.BALL_PASS_RECEIVED), "Expected receive event")


func test_long_pass_when_missed_lands_at_original_target() -> void:
	var simulation := _create_simulation(Vector2(10.55, 0.0), "team_a", true, 10.0)
	_start_flight(simulation)
	var move_actions: Array[MatchAction] = [
		MatchAction.new(RECEIVER_ID, MatchAction.Type.MOVE, Vector2.UP),
	]
	simulation.advance_fixed_step(0.4, move_actions)
	var events := simulation.advance_fixed_step(0.4, _no_actions())
	var ball := simulation.create_snapshot().ball
	_expect(ball.motion_state == BallMatchState.MotionState.LOOSE, "Expected missed pass to land")
	_expect(ball.position_m.distance_to(Vector2(10.55, 0.0)) < 0.01, "Expected target landing")
	_expect(is_zero_approx(ball.height_m), "Expected landed ball at ground height")
	_expect(_has_event(events, MatchEvent.Type.BALL_PASS_MISSED), "Expected missed pass event")


func test_long_pass_when_target_moves_beyond_range_lands_at_maximum() -> void:
	var simulation := _create_simulation(Vector2(20.5, 0.0), "team_a", true, 10.0)
	var actions: Array[MatchAction] = [
		MatchAction.new(PASSER_ID, MatchAction.Type.PASS, Vector2.ZERO, RECEIVER_ID),
		MatchAction.new(RECEIVER_ID, MatchAction.Type.MOVE, Vector2.RIGHT),
	]
	simulation.advance_fixed_step(0.1, actions)
	simulation.advance_fixed_step(0.1, _no_actions())
	var events := simulation.advance_fixed_step(2.0, _no_actions())
	var ball := simulation.create_snapshot().ball
	_expect(ball.motion_state == BallMatchState.MotionState.LOOSE, "Expected maximum-range landing")
	_expect(
		ball.position_m.distance_to(Vector2(20.55, 0.0)) < 0.01,
		"Expected long pass to stop at maximum range",
	)
	_expect(is_zero_approx(ball.height_m), "Expected maximum-range landing at ground height")
	_expect(_has_event(events, MatchEvent.Type.BALL_PASS_MISSED), "Expected miss event")

func _create_simulation(
	receiver_position_m: Vector2 = Vector2(6.0, 0.0),
	receiver_team_id: String = "team_a",
	acquire_ball: bool = true,
	receiver_speed_mps: float = 5.0,
) -> MatchSimulation:
	var simulation := MatchSimulation.new(73)
	_expect(
		simulation.register_player(PASSER_ID, Vector2.ZERO, 5.0, "team_a"),
		"Expected passer registration",
	)
	_expect(
		simulation.register_player(
			RECEIVER_ID,
			receiver_position_m,
			receiver_speed_mps,
			receiver_team_id,
		),
		"Expected receiver registration",
	)
	_expect(simulation.register_ball(Vector2(0.5, 0.0)), "Expected ball registration")
	_expect(simulation.start_match(), "Expected match start")
	if acquire_ball:
		simulation.advance_fixed_step(0.1, _no_actions())
	return simulation


func _start_flight(simulation: MatchSimulation) -> void:
	simulation.advance_fixed_step(0.1, _pass_actions())
	simulation.advance_fixed_step(0.1, _no_actions())


func _pass_actions() -> Array[MatchAction]:
	return [
		MatchAction.new(
			PASSER_ID,
			MatchAction.Type.PASS,
			Vector2.ZERO,
			RECEIVER_ID,
		),
	]


func _no_actions() -> Array[MatchAction]:
	return []


func _has_event(events: Array[MatchEvent], event_type: int) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
