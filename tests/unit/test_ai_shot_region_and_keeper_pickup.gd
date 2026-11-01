## Regresses rear-half shooting, automatic aerial shots and bounded keeper collection without rendering.
extends SceneTree
const Fixture = preload("res://tests/support/ai_fixture.gd")
var _failures: PackedStringArray = []

## Verifies opportunities, mirrored penalty boundaries, live plan invalidation and real keeper possession.
func _init() -> void:
	_test_shot_regions()
	_test_keeper_boundaries()
	_test_keeper_collection()
	for failure in _failures:
		printerr(failure)
	print("AI shot region and keeper pickup: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

## Rear-half jumping cannot bypass the same region restriction applied to ordinary shot candidates.
func _test_shot_regions() -> void:
	var f := Fixture.new()
	var builder := RoleCandidateBuilder.new(f.tuning, f.rules, f.formal.field)
	for direction in [-1.0, 1.0]:
		var goal := Vector2(25.0 * direction, 0)
		var player := f.player("carrier", Vector2(-10.0 * direction, 0))
		player.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
		var ball := BallMatchState.new(player.state.position_m)
		ball._set_owner(player.player_id)
		var snapshot := f.snapshot([player], ball)
		var candidates := builder.build(snapshot, player.player_id, "forward", Vector2.ZERO, goal, "", false)
		_check(not _contains_shot(candidates), "rear-half ground shot excluded for either direction")
		_check(ActionEligibility.allows(snapshot, MatchAction.new("carrier", MatchAction.Type.SHOOT), f.rules),
			"AI tuning does not restrict manual simulation shot commands")
		player.state_machine.try_start_jump(f.rules)
		player.advance(0.15)
		snapshot = f.snapshot([player], ball)
		_check(builder.aerial_action(snapshot, snapshot.get_player("carrier"), goal) == null,
			"airborne possession cannot bypass rear-half restriction")
		player.state_machine.reset_to_spawn(Vector2(5.0 * direction, 0))
		player.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
		_check(builder.can_attempt_shot(f.snapshot([player], ball).get_player("carrier"), goal),
			"20m front-half boundary remains a valid random shooting opportunity")
		player.state._set_position(Vector2(4.99 * direction, 0))
		_check(not builder.can_attempt_shot(f.snapshot([player], ball).get_player("carrier"), goal),
			"distance just beyond configured maximum excluded")
	# An involuntary carrier flip has no AI-owned aerial finishing plan.
	var simulation := f.formal.create(3.0)
	var carrier := simulation._player_runtime_system.get_player("swift_forward")
	carrier.state_machine.reset_to_spawn(Vector2(10, 0))
	simulation._ball_runtime_system.state._set_owner(carrier.player_id)
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	carrier.state_machine.try_start_jump(f.rules)
	carrier.advance(0.15)
	simulation.start_match()
	var snapshot := simulation.create_snapshot()
	_check(f.source()._precision_action(snapshot, snapshot.get_player(carrier.player_id)) == null,
		"unplanned carrier flip is not an unconditional precision shot")

## Collection uses field-defined penalty geometry and the existing ordinary control limits.
func _test_keeper_boundaries() -> void:
	var f := Fixture.new()
	var builder := RoleCandidateBuilder.new(f.tuning, f.rules, f.formal.field)
	for direction in [-1.0, 1.0]:
		var goal := Vector2(25.0 * direction, 0)
		var keeper := f.player("keeper", Vector2(-24.2 * direction, 0), "home", true)
		var ball := BallMatchState.new(Vector2(-20.0 * direction, 3))
		_check(builder.keeper_pickup_target(f.snapshot([keeper], ball), f.snapshot([keeper], ball).get_player("keeper"), goal).is_finite(),
			"uncontrolled ball inside own penalty area is collectible")
		for outside in [Vector2(-16.9 * direction, 0), Vector2(-20.0 * direction, 8.01),
				Vector2(20.0 * direction, 0), Vector2(-25.01 * direction, 0)]:
			ball._set_position(outside)
			var snapshot := f.snapshot([keeper], ball)
			_check(not builder.keeper_pickup_target(snapshot, snapshot.get_player("keeper"), goal).is_finite(),
				"outside own penalty area is not collectible")
		ball._launch_shot(Vector2(-20.0 * direction, 0), Vector2(-8.0 * direction, 0), 10, 0.3)
		var snapshot := f.snapshot([keeper], ball)
		_check(not builder.keeper_pickup_target(snapshot, snapshot.get_player("keeper"), goal).is_finite(),
			"active shot cannot be collected instead of F04 save")
		ball._release(Vector2(-20.0 * direction, 0))
		ball._set_owner("other")
		snapshot = f.snapshot([keeper], ball)
		_check(not builder.keeper_pickup_target(snapshot, snapshot.get_player("keeper"), goal).is_finite(),
			"keeper does not chase a controlled ball")
		ball._release(Vector2(-20.0 * direction, 0))
		ball._launch_pass("keeper", Vector2(-50.0 * direction, 0), 10, 1.8)
		snapshot = f.snapshot([keeper], ball)
		_check(not builder.keeper_pickup_target(snapshot, snapshot.get_player("keeper"), goal).is_finite(),
			"uncontrollable high-speed pass is not a pickup opportunity")
		ball._advance_flight(ball.position_m, 5.0)
		snapshot = f.snapshot([keeper], ball)
		_check(not builder.keeper_pickup_target(snapshot, snapshot.get_player("keeper"), goal).is_finite(),
			"high airborne pass is not a ground collection")

## An old chase is cancelled immediately, and a new legal approach awards possession through normal rules.
func _test_keeper_collection() -> void:
	var f := Fixture.new()
	var simulation := f.formal.create(6.0)
	for runtime in simulation._player_runtime_system.get_players():
		runtime.state_machine.reset_to_spawn(Vector2(-10, 12))
	var keeper := simulation._player_runtime_system.get_player("formal_player_09")
	keeper.state_machine.reset_to_spawn(Vector2(24.2, 0))
	var ball := simulation._ball_runtime_system
	ball.reset_ball(Vector2(20, 0))
	var source := f.source()
	var loop := GameLoop.new(simulation, 1.0 / 60.0, 0.25, 8, null, [], [source])
	simulation.start_match()
	loop.advance_frame(1.0 / 60.0, [])
	_check(keeper.state.movement_input.x < 0.0, "keeper approaches legal ball instead of staying on goal line")
	# Change only the scenario's observed ball position; the next source step must invalidate immediately.
	ball.state._set_position(Vector2(16, 0))
	loop.advance_frame(1.0 / 60.0, [])
	_check(keeper.state.movement_input.x >= 0.0, "leaving penalty area cancels old chase before heartbeat")
	ball.state._set_position(Vector2(20, 0))
	var gained := false
	for step in range(120):
		var frame := loop.advance_frame(1.0 / 60.0, [])
		if frame.snapshot.ball.owner_player_id == keeper.player_id:
			gained = true
			break
	_check(gained, "keeper actually gains ball through existing pickup rules")
	loop.advance_frame(1.0 / 60.0, [])
	_check(keeper.state.movement_input == Vector2.ZERO, "keeper stops moving after acquiring possession")

## Tests the behavior set rather than random samples.
func _contains_shot(candidates: Array[AIActionCandidate]) -> bool:
	for candidate in candidates:
		for option in candidate.targets:
			if option.action.action_type == MatchAction.Type.SHOOT:
				return true
	return false

## Preserves all independent failure diagnostics for one process exit.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
