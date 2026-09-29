extends SceneTree

const FIXED_DELTA := 0.25
const MOVE_SPEED_MPS := 4.0

var _failures: PackedStringArray = []


func _init() -> void:
	test_move_command_when_advanced_changes_position_at_fixed_speed()
	test_move_command_when_no_new_command_continues_moving()
	test_stop_command_when_advanced_keeps_position_and_enters_idle()
	test_diagonal_input_when_advanced_is_limited_to_full_speed()
	test_unknown_player_when_move_requested_rejects_action()

	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func test_move_command_when_advanced_changes_position_at_fixed_speed() -> void:
	var simulation := _create_started_simulation()
	var move_action := MatchAction.new(
		"test_player",
		MatchAction.Type.MOVE,
		Vector2.RIGHT,
	)
	var actions: Array[MatchAction] = [move_action]
	var events := simulation.advance_fixed_step(FIXED_DELTA, actions)
	var player := simulation.create_snapshot().get_player("test_player")
	_expect(player != null, "Expected player snapshot")
	if player == null:
		return
	_expect(player.position_m == Vector2(1.0, 0.0), "Expected fixed-step movement")
	_expect(
		player.movement_state == PlayerMatchState.MovementState.MOVING,
		"Expected player to enter moving state",
	)
	_expect(
		_has_event(events, MatchEvent.Type.ACTION_ACCEPTED),
		"Expected valid move action to be accepted",
	)


func test_move_command_when_no_new_command_continues_moving() -> void:
	var simulation := _create_started_simulation()
	var move_actions: Array[MatchAction] = [
		MatchAction.new("test_player", MatchAction.Type.MOVE, Vector2.RIGHT),
	]
	simulation.advance_fixed_step(FIXED_DELTA, move_actions)
	var no_actions: Array[MatchAction] = []
	simulation.advance_fixed_step(FIXED_DELTA, no_actions)
	var player := simulation.create_snapshot().get_player("test_player")
	_expect(player != null, "Expected player snapshot")
	if player == null:
		return
	_expect(player.position_m == Vector2(2.0, 0.0), "Expected movement to persist")


func test_stop_command_when_advanced_keeps_position_and_enters_idle() -> void:
	var simulation := _create_started_simulation()
	var move_actions: Array[MatchAction] = [
		MatchAction.new("test_player", MatchAction.Type.MOVE, Vector2.RIGHT),
	]
	simulation.advance_fixed_step(FIXED_DELTA, move_actions)
	var stop_actions: Array[MatchAction] = [
		MatchAction.new("test_player", MatchAction.Type.MOVE, Vector2.ZERO),
	]
	simulation.advance_fixed_step(FIXED_DELTA, stop_actions)
	var player := simulation.create_snapshot().get_player("test_player")
	_expect(player != null, "Expected player snapshot")
	if player == null:
		return
	_expect(player.position_m == Vector2(1.0, 0.0), "Expected stopped position")
	_expect(
		player.movement_state == PlayerMatchState.MovementState.IDLE,
		"Expected stop command to enter idle state",
	)


func test_diagonal_input_when_advanced_is_limited_to_full_speed() -> void:
	var simulation := _create_started_simulation()
	var diagonal_actions: Array[MatchAction] = [
		MatchAction.new("test_player", MatchAction.Type.MOVE, Vector2.ONE),
	]
	simulation.advance_fixed_step(FIXED_DELTA, diagonal_actions)
	var player := simulation.create_snapshot().get_player("test_player")
	_expect(player != null, "Expected player snapshot")
	if player == null:
		return
	_expect(
		is_equal_approx(player.position_m.length(), MOVE_SPEED_MPS * FIXED_DELTA),
		"Expected diagonal movement not to exceed full speed",
	)


func test_unknown_player_when_move_requested_rejects_action() -> void:
	var simulation := _create_started_simulation()
	var actions: Array[MatchAction] = [
		MatchAction.new("missing_player", MatchAction.Type.MOVE, Vector2.RIGHT),
	]
	var events := simulation.advance_fixed_step(FIXED_DELTA, actions)
	_expect(
		not _has_event(events, MatchEvent.Type.ACTION_ACCEPTED),
		"Expected unknown player action to be rejected",
	)


func _create_started_simulation() -> MatchSimulation:
	var simulation := MatchSimulation.new(44)
	_expect(
		simulation.register_player(
			"test_player",
			Vector2.ZERO,
			MOVE_SPEED_MPS,
		),
		"Expected player registration",
	)
	_expect(simulation.start_match(), "Expected match to start")
	return simulation


func _has_event(events: Array[MatchEvent], event_type: int) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
