extends SceneTree

const FIXED_DELTA := 0.1

var _failures: PackedStringArray = []


func _init() -> void:
	test_new_player_when_created_is_idle_at_initial_position()
	test_idle_player_when_action_starts_enters_windup()
	test_busy_player_when_second_action_starts_rejects_transition()
	test_action_when_phases_advance_only_moves_forward()
	test_action_when_finished_returns_to_idle()
	test_knocked_down_player_when_movement_requested_rejects_transition()
	test_registered_player_when_snapshotted_is_at_field_centre()
	test_running_match_when_advanced_updates_player_state_time()

	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func test_new_player_when_created_is_idle_at_initial_position() -> void:
	var state := PlayerMatchState.new("test_player", Vector2(2.0, -3.0))
	_expect(
		state.movement_state == PlayerMatchState.MovementState.IDLE,
		"Expected initial movement state to be idle",
	)
	_expect(
		state.action_state == PlayerMatchState.ActionState.IDLE,
		"Expected initial action state to be idle",
	)
	_expect(
		state.possession_state == PlayerMatchState.PossessionState.NO_BALL,
		"Expected initial possession state to be no ball",
	)
	_expect(state.position_m == Vector2(2.0, -3.0), "Expected initial position")


func test_idle_player_when_action_starts_enters_windup() -> void:
	var machine := _create_state_machine()
	var did_start := machine.try_start_action(
		PlayerMatchState.ActionState.SHOOTING
	)
	_expect(did_start, "Expected idle player to start shooting")
	_expect(
		machine.state.action_state == PlayerMatchState.ActionState.SHOOTING,
		"Expected shooting action state",
	)
	_expect(
		machine.state.action_phase == PlayerMatchState.ActionPhase.WINDUP,
		"Expected action to begin in windup",
	)


func test_busy_player_when_second_action_starts_rejects_transition() -> void:
	var machine := _create_state_machine()
	machine.try_start_action(PlayerMatchState.ActionState.TACKLING)
	var did_start := machine.try_start_action(
		PlayerMatchState.ActionState.ATTACKING
	)
	_expect(not did_start, "Expected busy player to reject a second action")
	_expect(
		machine.state.action_state == PlayerMatchState.ActionState.TACKLING,
		"Expected original action to remain active",
	)


func test_action_when_phases_advance_only_moves_forward() -> void:
	var machine := _create_state_machine()
	machine.try_start_action(PlayerMatchState.ActionState.ATTACKING)
	_expect(
		machine.set_action_phase(PlayerMatchState.ActionPhase.ACTIVE),
		"Expected windup to advance to active",
	)
	_expect(
		not machine.set_action_phase(PlayerMatchState.ActionPhase.WINDUP),
		"Expected action phase not to move backwards",
	)
	_expect(
		machine.set_action_phase(PlayerMatchState.ActionPhase.RECOVERY),
		"Expected active to advance to recovery",
	)


func test_action_when_finished_returns_to_idle() -> void:
	var machine := _create_state_machine()
	machine.try_start_action(PlayerMatchState.ActionState.DODGING)
	_expect(machine.finish_action(), "Expected active action to finish")
	_expect(
		machine.state.action_state == PlayerMatchState.ActionState.IDLE,
		"Expected finished action to return to idle",
	)
	_expect(
		machine.state.action_phase == PlayerMatchState.ActionPhase.NONE,
		"Expected idle action to have no phase",
	)


func test_knocked_down_player_when_movement_requested_rejects_transition() -> void:
	var machine := _create_state_machine()
	machine.try_start_action(PlayerMatchState.ActionState.KNOCKED_DOWN)
	var did_move := machine.set_movement_state(
		PlayerMatchState.MovementState.MOVING
	)
	_expect(not did_move, "Expected knocked down player not to begin moving")


func test_registered_player_when_snapshotted_is_at_field_centre() -> void:
	var controller := MatchController.new(31)
	_expect(
		controller.register_player("swift_forward", Vector2.ZERO),
		"Expected player registration before match start",
	)
	var snapshot := controller.create_snapshot()
	var player := snapshot.get_player("swift_forward")
	_expect(player != null, "Expected registered player snapshot")
	if player == null:
		return
	_expect(player.position_m == Vector2.ZERO, "Expected player at field centre")
	_expect(
		player.action_state == PlayerMatchState.ActionState.IDLE,
		"Expected registered player to be idle",
	)


func test_running_match_when_advanced_updates_player_state_time() -> void:
	var controller := MatchController.new(32)
	controller.register_player("swift_forward", Vector2.ZERO)
	controller.start_match()
	var no_actions: Array[MatchAction] = []
	controller.advance_simulation(FIXED_DELTA, no_actions)
	var player := controller.create_snapshot().get_player("swift_forward")
	_expect(player != null, "Expected player snapshot after fixed step")
	if player == null:
		return
	_expect(
		is_equal_approx(player.action_state_elapsed_seconds, FIXED_DELTA),
		"Expected player state time to use fixed delta",
	)


func _create_state_machine() -> PlayerStateMachine:
	return PlayerStateMachine.new(
		PlayerMatchState.new("test_player", Vector2.ZERO)
	)


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
