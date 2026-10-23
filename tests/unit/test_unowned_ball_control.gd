## Verifies unowned moving balls use shared control rules and preserve unique ownership.
extends SceneTree

var _config: MatchConfigDefinition
var _failures: PackedStringArray = []

## Reproduces the returning shot and independent pass, clearance and eligibility cases.
func _init() -> void:
	_config = MatchConfigDataRepository.new().load_from_csv(
		"res://resources/data/match_configs.csv").configs[0]
	_test_shooter_receives_rebound()
	_test_non_target_receives_pass()
	_test_clearance_can_be_controlled()
	_test_stopped_shot_is_available_in_same_step()
	_test_speed_and_height_limits()
	_test_locked_players_cannot_control_flights()
	_test_release_protection_is_local_and_expires()
	_test_first_contact_and_stable_ties()
	_test_moving_receiver_crosses_ball_path()
	_test_boundary_precedes_control()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: unowned ball control")
	quit(0 if _failures.is_empty() else 1)

## Uses a real shot and equal-strength impact without manually returning the ball.
func _test_shooter_receives_rebound() -> void:
	var simulation := MatchSimulation.new(1, _config, null,
		MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN, Callable(), Callable(),
		func() -> int: return ShotAim.Lane.CENTER)
	# This fixture isolates returning-shot control from F11 accuracy.
	simulation._shot_miss_override = 0
	simulation.register_player("shooter", Vector2.ZERO, 5.0, "blue", 80)
	simulation.register_player("defender", Vector2(4.0, 0.0), 5.0, "red", 1, 80)
	simulation.register_team_attacking_goal("blue", Vector2(25.0, 0.0))
	simulation.register_ball(Vector2(0.55, 0.0))
	simulation.start_match()
	simulation.advance_fixed_step(0.01, [])
	simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT)])
	var saw_rebound := false
	var regained := false
	for step in range(180):
		var events := simulation.advance_fixed_step(0.01, [])
		for event in events:
			if event.event_type == MatchEvent.Type.BALL_REBOUNDED:
				saw_rebound = true
		var snapshot := simulation.create_snapshot()
		if saw_rebound and snapshot.ball.owner_player_id == "shooter":
			regained = true
			_check(snapshot.get_player("shooter").possession_state
				== PlayerMatchState.PossessionState.POSSESSING, "Player and ball must agree")
			_check(simulation._ball_runtime_system.shot_source == null,
				"Control must clear the old shot source")
			break
	_check(saw_rebound, "Equal-strength shot must actually rebound")
	_check(regained, "Shooter must control the returning rebound before it rolls past")

## A destination ID expresses intent rather than exclusive ownership of a pass.
func _test_non_target_receives_pass() -> void:
	var players := PlayerRuntimeSystem.new()
	players.register_player("interceptor", Vector2(2.0, 0.0), 5.0, "red")
	players.register_player("target", Vector2(6.0, 0.0), 5.0, "blue")
	var ball := BallRuntimeSystem.new()
	ball.configure_match_rules(_config)
	ball.register_ball(Vector2.ZERO)
	ball.state._launch_pass("target", Vector2(14.0, 0.0), 10.0, 0.0)
	var result := ball.advance(0.3, players)
	_check(ball.state.owner_player_id == "interceptor", "Eligible non-target must receive pass")
	_check(result.new_owner_player_id == "interceptor", "Control result must identify real owner")
	_check(players.get_player("target").state.possession_state
		== PlayerMatchState.PossessionState.NO_BALL, "Intended target must not gain phantom control")

## A low clearance remains available while crossing an eligible player's control range.
func _test_clearance_can_be_controlled() -> void:
	var players := PlayerRuntimeSystem.new()
	players.register_player("receiver", Vector2(2.0, 0.0))
	var ball := BallRuntimeSystem.new()
	ball.configure_match_rules(_config)
	ball.register_ball(Vector2.ZERO)
	ball.state._launch_clearance(Vector2.ZERO, Vector2(10.0, 0.0), 10.0, 0.01, 0.0)
	ball.advance(0.4, players)
	_check(ball.state.owner_player_id == "receiver", "Low moving clearance must be controllable")

## A shot finishing its trajectory does not need an extra step before ordinary pickup.
func _test_stopped_shot_is_available_in_same_step() -> void:
	var simulation := MatchSimulation.new(1, _config)
	simulation.register_player("receiver", Vector2.ZERO)
	simulation.register_ball(Vector2(0.4, 0.0))
	simulation.start_match()
	simulation._ball_runtime_system.state._launch_shot(
		Vector2(0.4, 0.0), Vector2(0.6, 0.0), 0.004583333, 0.01)
	simulation.advance_fixed_step(0.05, [])
	_check(simulation.create_snapshot().ball.owner_player_id == "receiver",
		"Shot stopping in control range must be acquired in the same step")

## Keeps inclusive ball-speed and physical-height limits consistent across flight kinds.
func _test_speed_and_height_limits() -> void:
	for kind in [BallMatchState.FlightKind.PASS, BallMatchState.FlightKind.SHOT,
		BallMatchState.FlightKind.CLEARANCE]:
		for speed in [15.0, 100.0]:
			var players := PlayerRuntimeSystem.new()
			players.register_player("receiver", Vector2.ZERO)
			var ball := _flight(kind, speed, 0.01)
			ball.advance(0.3, players)
			_check((ball.state.owner_player_id == "receiver") == (speed == 15.0),
				"All flight kinds must apply the shared control speed threshold")
		var high_players := PlayerRuntimeSystem.new()
		high_players.register_player("receiver", Vector2.ZERO)
		var high_ball := _flight(kind, 14.0, 3.0)
		high_ball.advance(0.3, high_players)
		_check(high_ball.state.owner_player_id.is_empty(), "High ball must pass above ground control")

## Every action lock rejects ordinary reception, including moving rebounds and clearances.
func _test_locked_players_cannot_control_flights() -> void:
	for action in PlayerMatchState.ActionState.values():
		if action == PlayerMatchState.ActionState.IDLE:
			continue
		for kind in [BallMatchState.FlightKind.PASS, BallMatchState.FlightKind.SHOT,
			BallMatchState.FlightKind.CLEARANCE]:
			var players := PlayerRuntimeSystem.new()
			players.register_player("receiver", Vector2.ZERO)
			players.get_player("receiver").state._set_action_state(
				action, PlayerMatchState.ActionPhase.ACTIVE)
			var ball := _flight(kind, 14.0, 0.01)
			ball.advance(0.3, players)
			_check(ball.state.owner_player_id.is_empty(), "Action lock must reject moving-ball control")

## The last releaser waits, while other players may receive the same ball immediately.
func _test_release_protection_is_local_and_expires() -> void:
	var players := PlayerRuntimeSystem.new()
	players.register_player("receiver", Vector2.ZERO)
	var ball := _flight(BallMatchState.FlightKind.SHOT, 1.0, 0.01)
	ball.state._launch_shot(Vector2(-0.5, 0.0), Vector2(1.0, 0.0), 10.0, 0.01)
	ball._protect_releaser("receiver")
	ball.advance(0.01, players)
	_check(ball.state.owner_player_id.is_empty(), "Releaser must not control during protection")
	# A pass stays moving long enough to test the exact expiry independently of shot deceleration.
	ball.state._launch_pass("receiver", Vector2(1.0, 0.0), 10.0, 0.0)
	ball.advance(0.14, players)
	_check(ball.state.owner_player_id == "receiver", "Control must become available at protection expiry")
	ball = _flight(BallMatchState.FlightKind.PASS, 1.0, 0.01)
	ball.state._release(Vector2(-0.5, 0.0))
	ball.state._launch_pass("receiver", Vector2(1.0, 0.0), 10.0, 0.0)
	ball._protect_releaser("other")
	# Restore the player's ordinary eligibility after the earlier reception.
	players.get_player("receiver").state_machine.set_possession_state(
		PlayerMatchState.PossessionState.NO_BALL)
	ball.advance(0.01, players)
	_check(ball.state.owner_player_id == "receiver", "Another releaser's protection must not block control")

## Earliest physical contact wins; only simultaneous candidates fall back to stable IDs.
func _test_first_contact_and_stable_ties() -> void:
	for tied in [false, true]:
		var players := PlayerRuntimeSystem.new()
		players.register_player("z_first", Vector2.ZERO)
		players.register_player("a_other", Vector2.ZERO if tied else Vector2(1.0, 0.0))
		var ball := _flight(BallMatchState.FlightKind.CLEARANCE, 14.0, 0.01)
		ball.advance(0.4, players)
		_check(ball.state.owner_player_id == ("a_other" if tied else "z_first"),
			"Control winner must depend on time before stable ID")
		var owner_count := 0
		for player in players.get_players():
			if player.state.possession_state == PlayerMatchState.PossessionState.POSSESSING:
				owner_count += 1
		_check(owner_count == 1, "Simultaneous contact must never duplicate possession")

## A receiver crossing the ball between two distant endpoints must not be missed.
func _test_moving_receiver_crosses_ball_path() -> void:
	var simulation := MatchSimulation.new(1, _config)
	simulation.register_player("receiver", Vector2(2.0, -1.0), 5.0)
	simulation.register_ball(Vector2.ZERO)
	simulation.start_match()
	simulation._ball_runtime_system.state._launch_pass("absent", Vector2(14.0, 0.0), 10.0, 0.0)
	simulation.advance_fixed_step(0.4, [MatchAction.new("receiver", MatchAction.Type.MOVE, Vector2.DOWN)])
	_check(simulation.create_snapshot().ball.owner_player_id == "receiver",
		"Moving receiver must use its swept path, rather than only its final position")

## Settled goals and exits cannot be cancelled by a receiver beyond the boundary.
func _test_boundary_precedes_control() -> void:
	var field := FieldDataRepository.new().load_from_csv("res://resources/data/fields.csv").fields[0]
	var half := field.length_m * 0.5
	for kind in [BallMatchState.FlightKind.SHOT, BallMatchState.FlightKind.PASS]:
		var simulation := MatchSimulation.new(1, _config, field)
		simulation.register_player("receiver", Vector2(half + 2.0, 0.0))
		simulation.register_ball(Vector2(half - 1.0, 0.0))
		simulation.start_match()
		var ball := simulation._ball_runtime_system.state
		if kind == BallMatchState.FlightKind.SHOT:
			ball._launch_shot(ball.position_m, Vector2(14.0, 0.0), 10.0, 0.01)
		else:
			ball._launch_pass("receiver", Vector2(14.0, 0.0), 10.0, 0.0)
		simulation.advance_fixed_step(0.3, [])
		_check(simulation.create_snapshot().ball.owner_player_id.is_empty(),
			"Whole-ball crossing before reception must prevent control")
		simulation.advance_fixed_step(0.1, [])
		_check(simulation.create_snapshot().ball.owner_player_id.is_empty(),
			"Settlement must disable further ball acquisition")

## Creates the same unowned path with only its flight kind, speed and arc varying.
func _flight(kind: int, speed: float, apex: float) -> BallRuntimeSystem:
	var ball := BallRuntimeSystem.new()
	ball.configure_match_rules(_config)
	ball.register_ball(Vector2(-2.0, 0.0))
	if kind == BallMatchState.FlightKind.SHOT:
		ball.state._launch_shot(ball.state.position_m, Vector2(speed, 0.0), 10.0, apex)
	elif kind == BallMatchState.FlightKind.CLEARANCE:
		ball.state._launch_clearance(ball.state.position_m, Vector2(speed, 0.0), 10.0, apex, 0.0)
	else:
		ball.state._launch_pass("receiver", Vector2(speed, 0.0), 10.0, apex)
	return ball

## Collects failures so each independent ownership case is still checked.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
