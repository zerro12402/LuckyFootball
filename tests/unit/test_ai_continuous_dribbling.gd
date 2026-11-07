## Regresses continuous carrier decisions and moving jumps while preserving deliberate pass/shot stops.
extends SceneTree
const Fixture = preload("res://tests/support/ai_fixture.gd")
var _failures: PackedStringArray = []

## Verifies candidate policy for every outfield role and actual jump motion through the simulation.
func _init() -> void:
	_test_carrier_candidates()
	_test_forward_clear_dribble()
	_test_moving_jump()
	for failure in _failures:
		printerr(failure)
	print("AI continuous dribbling: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

## A legal carrier always has progression choices, while keepers and off-ball actors retain their distinct waiting duties.
func _test_carrier_candidates() -> void:
	var f := Fixture.new()
	var builder := RoleCandidateBuilder.new(f.tuning, f.rules, f.formal.field)
	var carrier := f.player("swift_forward", Vector2(-8, 0))
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	var ball := BallMatchState.new(carrier.state.position_m)
	ball._set_owner(carrier.player_id)
	var snapshot := f.snapshot([carrier], ball)
	for role in ["forward", "mid", "back"]:
		var candidates := builder.build(snapshot, carrier.player_id, role, Vector2(-10, 0),
			Vector2(25, 0), carrier.player_id, false)
		var advance := false
		for candidate in candidates:
			_check(candidate.behavior != AIActionCandidate.Behavior.HOLD,
				role + " carrier cannot randomly idle mid-attack")
			advance = advance or candidate.behavior == AIActionCandidate.Behavior.ADVANCE
		_check(advance, role + " carrier retains legal advance")
	var keeper := f.player("steady_keeper", Vector2(-24.2, 0), "home", true)
	keeper.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	ball._set_owner(keeper.player_id)
	snapshot = f.snapshot([keeper], ball)
	var keeper_hold := false
	for candidate in builder.build(snapshot, keeper.player_id, "keeper", keeper.state.position_m, Vector2(25, 0), "", false):
		keeper_hold = keeper_hold or candidate.behavior == AIActionCandidate.Behavior.HOLD
	_check(keeper_hold, "keeper still waits to distribute from a stationary position")

## Uses the carrier's actual local space, including the exact radius, independently of pressure.
func _test_forward_clear_dribble() -> void:
	var f := Fixture.new()
	var builder := RoleCandidateBuilder.new(f.tuning, f.rules, f.formal.field)
	var carrier := f.player("carrier", Vector2(15, 0))
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	var ball := BallMatchState.new(carrier.state.position_m)
	ball._set_owner(carrier.player_id)
	var teammate := f.player("mate", Vector2(16, 0))
	var opponent := f.player("opponent", Vector2(15, 2), "away")
	for distance: float in [2.0, 2.01]:
		opponent.state._set_position(carrier.state.position_m + Vector2(0, distance))
		var snapshot := f.snapshot([carrier, teammate, opponent], ball)
		for role: String in ["forward", "mid", "back"]:
			var expected := f.tuning.weight(role, AIActionCandidate.Behavior.ADVANCE) * 0.5
			if distance > 2.0 and role == "forward":
				expected *= 1.5
			var choices := builder.build(snapshot, carrier.player_id, role, Vector2.ZERO,
				Vector2(25, 0), "", true)
			for candidate in choices:
				if candidate.behavior == AIActionCandidate.Behavior.ADVANCE:
					_check(is_equal_approx(candidate.weight, expected),
						"Only a forward with no opponent within two metres gets the dribble bonus")


## A jump preserves real dribbling input, while directed high-pass reception and kicking still explicitly stop stale movement.
func _test_moving_jump() -> void:
	var f := Fixture.new()
	var simulation := f.formal.create(3.0)
	var carrier := simulation._player_runtime_system.get_player("swift_forward")
	carrier.state_machine.reset_to_spawn(Vector2(-8, 0))
	simulation._ball_runtime_system.reset_ball(Vector2(-7.45, 0))
	var contact := BallContactCandidate.new()
	contact.player_id = carrier.player_id
	simulation._ball_runtime_system.acquire_contact_ball(contact, simulation._player_runtime_system)
	carrier.state_machine.set_movement_input(Vector2.RIGHT)
	simulation.start_match()
	var source := f.source()
	var player := simulation.create_snapshot().get_player(carrier.player_id)
	var commands := source._emit_action(MatchAction.new(carrier.player_id, MatchAction.Type.JUMP), player)
	var before := player.position_m
	simulation.advance_fixed_step(0.05, commands)
	var after := simulation.create_snapshot().get_player(carrier.player_id)
	_check(after.position_m.x > before.x and after.movement_input == Vector2.RIGHT
		and after.jump_phase != PlayerMatchState.JumpPhase.NONE,
		"carrying jump starts and advances without clearing dribble input")
	for kind in [MatchAction.Type.PASS, MatchAction.Type.SHOOT]:
		commands = source._emit_action(MatchAction.new(carrier.player_id, kind), after)
		_check(commands[0].direction == Vector2.ZERO, "passing and shooting retain deliberate movement stop")
	var receiver := f.player("formal_player_02", Vector2(14, 0))
	receiver.state_machine.set_movement_input(Vector2.LEFT)
	var ball := BallMatchState.new(Vector2.ZERO)
	ball._launch_pass(receiver.player_id, Vector2.RIGHT * 14, 14, 1.8)
	player = f.snapshot([receiver], ball).get_player(receiver.player_id)
	commands = source._emit_action(MatchAction.new(receiver.player_id, MatchAction.Type.JUMP), player)
	_check(commands[0].direction == Vector2.ZERO, "unowned high-pass jump still stops at its receiving point")

## Records each independent failed contract once.
func _check(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
