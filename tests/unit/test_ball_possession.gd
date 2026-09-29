extends SceneTree

const FIXED_DELTA := 0.25
const MOVE_SPEED_MPS := 4.0

var _failures: PackedStringArray = []


func _init() -> void:
	test_free_ball_when_player_is_far_remains_loose()
	test_free_ball_at_possession_boundary_grants_possession()
	test_second_ball_when_registered_is_rejected()
	test_free_ball_when_player_enters_radius_grants_possession()
	test_owned_ball_when_player_moves_follows_control_point()
	test_owned_ball_when_player_moves_up_stays_in_front()
	test_owned_ball_when_player_moves_down_stays_in_front()
	test_owned_ball_when_player_moves_left_stays_in_front()
	test_owned_ball_when_player_turns_stays_in_front()
	test_owned_ball_when_moving_up_after_left_keeps_left_facing()
	test_owned_ball_when_moving_down_after_left_keeps_left_facing()
	test_player_with_ball_when_moving_uses_possession_speed_multiplier()

	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func test_free_ball_at_possession_boundary_grants_possession() -> void:
	var simulation := _create_started_simulation(Vector2(0.75, 0.0))
	simulation.advance_fixed_step(0.1, _no_actions())
	var snapshot := simulation.create_snapshot()
	_expect(snapshot.ball != null, "Expected ball snapshot")
	if snapshot.ball == null:
		return
	_expect(
		snapshot.ball.owner_player_id == "test_player",
		"Expected possession at the inclusive radius boundary",
	)


func test_second_ball_when_registered_is_rejected() -> void:
	var simulation := MatchSimulation.new(56)
	_expect(
		simulation.register_ball(Vector2.ZERO),
		"Expected first ball registration",
	)
	_expect(
		not simulation.register_ball(Vector2.ONE),
		"Expected second ball registration to be rejected",
	)

func test_free_ball_when_player_is_far_remains_loose() -> void:
	var simulation := _create_started_simulation(Vector2(3.0, 0.0))
	simulation.advance_fixed_step(FIXED_DELTA, _no_actions())
	var snapshot := simulation.create_snapshot()
	_expect(snapshot.ball != null, "Expected ball snapshot")
	if snapshot.ball == null:
		return
	_expect(
		snapshot.ball.motion_state == BallMatchState.MotionState.LOOSE,
		"Expected distant ball to remain loose",
	)
	_expect(snapshot.ball.owner_player_id.is_empty(), "Expected no ball owner")


func test_free_ball_when_player_enters_radius_grants_possession() -> void:
	var simulation := _create_started_simulation(Vector2(1.5, 0.0))
	var actions: Array[MatchAction] = [
		MatchAction.new("test_player", MatchAction.Type.MOVE, Vector2.RIGHT),
	]
	var events := simulation.advance_fixed_step(FIXED_DELTA, actions)
	var snapshot := simulation.create_snapshot()
	var player := snapshot.get_player("test_player")
	_expect(snapshot.ball != null, "Expected ball snapshot")
	_expect(player != null, "Expected player snapshot")
	if snapshot.ball == null or player == null:
		return
	_expect(
		snapshot.ball.motion_state == BallMatchState.MotionState.OWNED,
		"Expected ball to become owned",
	)
	_expect(
		snapshot.ball.owner_player_id == "test_player",
		"Expected approaching player to own ball",
	)
	_expect(
		player.possession_state == PlayerMatchState.PossessionState.POSSESSING,
		"Expected player possession state",
	)
	_expect(
		_has_event(events, MatchEvent.Type.BALL_POSSESSION_GAINED),
		"Expected possession event",
	)


func test_owned_ball_when_player_moves_follows_control_point() -> void:
	var simulation := _create_started_simulation(Vector2(0.5, 0.0))
	simulation.advance_fixed_step(0.1, _no_actions())
	var actions: Array[MatchAction] = [
		MatchAction.new("test_player", MatchAction.Type.MOVE, Vector2.RIGHT),
	]
	simulation.advance_fixed_step(FIXED_DELTA, actions)
	var snapshot := simulation.create_snapshot()
	var player := snapshot.get_player("test_player")
	if snapshot.ball == null or player == null:
		_expect(false, "Expected player and ball snapshots")
		return
	_expect(
		snapshot.ball.position_m.is_equal_approx(
			player.position_m + Vector2.RIGHT * 0.55
		),
		"Expected owned ball at the dribble control point",
	)


func test_player_with_ball_when_moving_uses_possession_speed_multiplier() -> void:
	var simulation := _create_started_simulation(Vector2(0.5, 0.0))
	simulation.advance_fixed_step(0.1, _no_actions())
	var actions: Array[MatchAction] = [
		MatchAction.new("test_player", MatchAction.Type.MOVE, Vector2.RIGHT),
	]
	simulation.advance_fixed_step(1.0, actions)
	var player := simulation.create_snapshot().get_player("test_player")
	_expect(player != null, "Expected player snapshot")
	if player == null:
		return
	_expect(
		player.position_m.is_equal_approx(Vector2(3.6, 0.0)),
		"Expected possession movement speed to be reduced to 90 percent",
	)


func _create_started_simulation(ball_position_m: Vector2) -> MatchSimulation:
	var simulation := MatchSimulation.new(55)
	_expect(
		simulation.register_player(
			"test_player",
			Vector2.ZERO,
			MOVE_SPEED_MPS,
		),
		"Expected player registration",
	)
	_expect(simulation.register_ball(ball_position_m), "Expected ball registration")
	_expect(simulation.start_match(), "Expected match to start")
	return simulation


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

func test_owned_ball_when_player_moves_up_stays_in_front() -> void:
	_expect_owned_ball_in_direction(Vector2.UP)


func test_owned_ball_when_player_moves_down_stays_in_front() -> void:
	_expect_owned_ball_in_direction(Vector2.DOWN)


func _expect_owned_ball_in_direction(direction: Vector2) -> void:
	var simulation := _create_started_simulation(Vector2(0.5, 0.0))
	simulation.advance_fixed_step(0.1, _no_actions())
	var actions: Array[MatchAction] = [
		MatchAction.new("test_player", MatchAction.Type.MOVE, direction),
	]
	simulation.advance_fixed_step(FIXED_DELTA, actions)
	var snapshot := simulation.create_snapshot()
	var player := snapshot.get_player("test_player")
	if snapshot.ball == null or player == null:
		_expect(false, "Expected player and ball snapshots")
		return
	var expected_facing := Vector2.LEFT if direction.x < 0.0 else Vector2.RIGHT
	_expect(
		snapshot.ball.position_m.is_equal_approx(
			player.position_m + expected_facing * 0.55
		),
		"Expected owned ball to remain in front of the moving player",
	)


func test_owned_ball_when_player_moves_left_stays_in_front() -> void:
	_expect_owned_ball_in_direction(Vector2.LEFT)


func test_owned_ball_when_player_turns_stays_in_front() -> void:
	var simulation := _create_started_simulation(Vector2(0.5, 0.0))
	simulation.advance_fixed_step(0.1, _no_actions())
	var right_actions: Array[MatchAction] = [
		MatchAction.new("test_player", MatchAction.Type.MOVE, Vector2.RIGHT),
	]
	simulation.advance_fixed_step(FIXED_DELTA, right_actions)
	var up_actions: Array[MatchAction] = [
		MatchAction.new("test_player", MatchAction.Type.MOVE, Vector2.UP),
	]
	simulation.advance_fixed_step(FIXED_DELTA, up_actions)
	var snapshot := simulation.create_snapshot()
	var player := snapshot.get_player("test_player")
	if snapshot.ball == null or player == null:
		_expect(false, "Expected player and ball snapshots after turning")
		return
	_expect(
		snapshot.ball.position_m.is_equal_approx(
			player.position_m + Vector2.RIGHT * 0.55
		),
		"Expected ball 0.55 m ahead after changing direction",
	)

func test_owned_ball_when_moving_up_after_left_keeps_left_facing() -> void:
	_expect_left_facing_ball_after_vertical_movement(Vector2.UP)


func test_owned_ball_when_moving_down_after_left_keeps_left_facing() -> void:
	_expect_left_facing_ball_after_vertical_movement(Vector2.DOWN)


func _expect_left_facing_ball_after_vertical_movement(direction: Vector2) -> void:
	var simulation := _create_started_simulation(Vector2(0.5, 0.0))
	simulation.advance_fixed_step(0.1, _no_actions())
	var left_actions: Array[MatchAction] = [
		MatchAction.new("test_player", MatchAction.Type.MOVE, Vector2.LEFT),
	]
	simulation.advance_fixed_step(FIXED_DELTA, left_actions)
	var vertical_actions: Array[MatchAction] = [
		MatchAction.new("test_player", MatchAction.Type.MOVE, direction),
	]
	simulation.advance_fixed_step(FIXED_DELTA, vertical_actions)
	var snapshot := simulation.create_snapshot()
	var player := snapshot.get_player("test_player")
	if snapshot.ball == null or player == null:
		_expect(false, "Expected player and ball snapshots after moving vertically")
		return
	_expect(
		player.facing_direction == Vector2.LEFT,
		"Expected vertical movement to preserve left-facing sprite direction",
	)
	_expect(
		snapshot.ball.position_m.is_equal_approx(
			player.position_m + Vector2.LEFT * 0.55
		),
		"Expected ball 0.55 m left while moving vertically and facing left",
	)
