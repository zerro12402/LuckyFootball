## Checks shared ball acquisition eligibility, speed boundaries, and the tackle exception.
extends SceneTree

const PASSER_ID := "passer"
const RECEIVER_ID := "receiver"
const CONTROL_LIMIT_MPS := 15.0

var _failures: PackedStringArray = []
var _config: MatchConfigDefinition


## Runs independent possession cases against the same validated match preset.
func _init() -> void:
	var load_result := MatchConfigDataRepository.new().load_from_csv(
		"res://resources/data/match_configs.csv"
	)
	if not load_result.is_success or load_result.configs.is_empty():
		push_error("Ball control tests require a valid match configuration")
		quit(1)
		return
	_config = load_result.configs[0]
	test_active_player_can_pick_up_loose_ball()
	test_busy_player_cannot_pick_up_loose_ball()
	test_busy_target_cannot_be_selected_for_pass()
	test_target_becoming_busy_cannot_receive_pass()
	test_pass_at_control_speed_limit_can_be_received()
	test_pass_above_control_speed_limit_remains_in_flight()
	test_active_tackler_can_receive_ball_as_explicit_exception()
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


## Allows an idle action state to gain a nearby free ball.
func test_active_player_can_pick_up_loose_ball() -> void:
	var players := _create_players()
	var ball := _create_ball(CONTROL_LIMIT_MPS)
	ball.advance(0.1, players)
	_expect(ball.state.owner_player_id == PASSER_ID, "Active player did not pick up free ball")


## Prevents passing, tackling, and getting up from acquiring an ordinary free ball.
func test_busy_player_cannot_pick_up_loose_ball() -> void:
	for action_state in [
		PlayerMatchState.ActionState.PASSING,
		PlayerMatchState.ActionState.TACKLING,
		PlayerMatchState.ActionState.GETTING_UP,
	]:
		var players := _create_players()
		var player := players.get_player(PASSER_ID)
		_expect(player.state_machine.try_start_action(action_state), "Could not set busy state")
		var ball := _create_ball(CONTROL_LIMIT_MPS)
		ball.advance(0.1, players)
		_expect(ball.state.owner_player_id.is_empty(), "Busy player picked up free ball")


## Applies the same available-state rule when the pass command is accepted.
func test_busy_target_cannot_be_selected_for_pass() -> void:
	for action_state in [
		PlayerMatchState.ActionState.PASSING,
		PlayerMatchState.ActionState.TACKLING,
		PlayerMatchState.ActionState.GETTING_UP,
	]:
		var players := _create_players()
		var ball := _create_ball(CONTROL_LIMIT_MPS)
		ball.acquire_loose_ball(players)
		var receiver := players.get_player(RECEIVER_ID)
		_expect(receiver.state_machine.try_start_action(action_state), "Could not set target state")
		_expect(
			not ball.try_start_pass(players.get_player(PASSER_ID), receiver),
			"Busy target accepted a pass command",
		)
		_expect(ball.state.owner_player_id == PASSER_ID, "Rejected pass changed ownership")


## Rechecks eligibility at ball contact after a valid target changes state in flight.
func test_target_becoming_busy_cannot_receive_pass() -> void:
	for action_state in [
		PlayerMatchState.ActionState.PASSING,
		PlayerMatchState.ActionState.TACKLING,
		PlayerMatchState.ActionState.GETTING_UP,
	]:
		var players := _create_players()
		var ball := _start_pass(players, CONTROL_LIMIT_MPS)
		var receiver := players.get_player(RECEIVER_ID)
		_expect(receiver.state_machine.try_start_action(action_state), "Could not change target")
		ball.advance(0.2, players)
		_expect(ball.state.owner_player_id.is_empty(), "Busy target caught an in-flight pass")
		_expect(
			ball.state.motion_state == BallMatchState.MotionState.IN_FLIGHT,
			"Uncaught pass stopped before its planned range",
		)


## Treats a pass exactly at the configured speed as controllable.
func test_pass_at_control_speed_limit_can_be_received() -> void:
	var players := _create_players()
	var ball := _start_pass(players, CONTROL_LIMIT_MPS)
	ball.advance(0.2, players)
	_expect(ball.state.owner_player_id == RECEIVER_ID, "Boundary-speed pass was not caught")


## Keeps a faster directed pass in flight even when it crosses the target's feet.
func test_pass_above_control_speed_limit_remains_in_flight() -> void:
	var players := _create_players()
	var ball := _start_pass(players, CONTROL_LIMIT_MPS + 1.0)
	ball.advance(0.2, players)
	_expect(ball.state.owner_player_id.is_empty(), "Fast pass was caught above speed limit")
	_expect(
		ball.state.motion_state == BallMatchState.MotionState.IN_FLIGHT,
		"Fast pass did not remain in flight",
	)


## Lets a legal active tackle transfer ownership without ordinary pickup eligibility.
func test_active_tackler_can_receive_ball_as_explicit_exception() -> void:
	var players := _create_players()
	var ball := _create_ball(CONTROL_LIMIT_MPS)
	ball.acquire_loose_ball(players)
	var tackler := players.get_player(RECEIVER_ID)
	_expect(
		tackler.state_machine.try_start_action(PlayerMatchState.ActionState.TACKLING),
		"Could not start tackle",
	)
	_expect(
		not ball.transfer_tackled_ball(players.get_player(PASSER_ID), tackler),
		"Tackle transferred the ball during windup",
	)
	_expect(
		tackler.state_machine.set_action_phase(PlayerMatchState.ActionPhase.ACTIVE),
		"Could not enter tackle contact phase",
	)
	_expect(
		ball.transfer_tackled_ball(players.get_player(PASSER_ID), tackler),
		"Active tackle did not transfer ball",
	)
	_expect(ball.state.owner_player_id == RECEIVER_ID, "Tackler did not own transferred ball")


## Registers one carrier and one teammate with deterministic spacing.
func _create_players() -> PlayerRuntimeSystem:
	var players := PlayerRuntimeSystem.new()
	_expect(players.register_player(PASSER_ID, Vector2.ZERO), "Could not register passer")
	_expect(players.register_player(RECEIVER_ID, Vector2(6.0, 0.0)), "Could not register receiver")
	return players


## Keeps test ball rules identical to the production CSV except for pass speed.
func _create_ball(pass_speed_mps: float) -> BallRuntimeSystem:
	var ball := BallRuntimeSystem.new(0.75, 0.55, pass_speed_mps)
	ball.configure_match_rules(_config)
	_expect(ball.register_ball(Vector2(0.5, 0.0)), "Could not register ball")
	return ball


## Starts a directed pass and advances through its kick frame.
func _start_pass(players: PlayerRuntimeSystem, speed_mps: float) -> BallRuntimeSystem:
	var ball := _create_ball(speed_mps)
	ball.acquire_loose_ball(players)
	_expect(
		ball.try_start_pass(players.get_player(PASSER_ID), players.get_player(RECEIVER_ID)),
		"Could not start a valid pass",
	)
	ball.advance(0.2, players)
	return ball


## Collects all independent failures before returning the test process status.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
