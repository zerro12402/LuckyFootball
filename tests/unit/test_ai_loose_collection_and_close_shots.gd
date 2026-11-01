## Regresses live loose-ball collection near all lines and the reduced AI shooting envelope without rendering.
extends SceneTree
const Fixture = preload("res://tests/support/ai_fixture.gd")
var _failures: PackedStringArray = []

## Exercises real pickup, held-plan tracking and both-direction ground/air shooting eligibility.
func _init() -> void:
	_test_live_chase()
	_test_boundary_pickups()
	_test_shooting_range()
	for failure in _failures:
		printerr(failure)
	print("AI loose collection and close shots: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

## Holding a chase updates its destination without new dice, and arrival tolerance cannot stop short of a moving ball.
func _test_live_chase() -> void:
	var f := Fixture.new()
	var player := f.player("swift_forward", Vector2(1, 0))
	var ball := BallMatchState.new(Vector2.ZERO)
	var source := f.source(true)
	var snapshot := f.snapshot([player], ball)
	var initial := source.propose_actions(snapshot)
	_check(_direction(initial, player.player_id).x < 0, "primary approaches unowned ball")
	var plan: PlayerAIPlan = source._plans[player.player_id]
	var draws := source.get_random_draws(player.player_id)
	ball._set_position(Vector2(0.8, 0))
	snapshot = f.snapshot([player], ball, "", 1, false, 1)
	var actions := source.propose_actions(snapshot)
	_check(_direction(actions, player.player_id).x < 0, "collector keeps approaching inside ordinary arrival tolerance")
	_check(source._plans[player.player_id] == plan and plan.target_m == ball.position_m,
		"same chase plan tracks current ball position")
	ball._set_position(Vector2(1.2, 0))
	actions = source.propose_actions(f.snapshot([player], ball, "", 1, false, 2))
	_check(_direction(actions, player.player_id).x > 0 and source.get_random_draws(player.player_id) == draws,
		"live chase reverses immediately without random reselection")
	var builder := RoleCandidateBuilder.new(f.tuning, f.rules, f.formal.field)
	ball._set_position(Vector2(0, 14.8))
	snapshot = f.snapshot([player], ball)
	var candidates := builder.build(snapshot, player.player_id, "forward", Vector2(-2, -11),
		Vector2(25, 0), player.player_id, false)
	var chase := Vector2.INF
	for candidate in candidates:
		_check(candidate.behavior != AIActionCandidate.Behavior.HOLD, "primary collector has no ordinary idle candidate")
		if candidate.behavior == AIActionCandidate.Behavior.CHASE:
			chase = candidate.targets[0].destination_m
	_check(chase == ball.position_m, "chase destination bypasses one-metre field margin")
	var ordinary := builder.movement_target(snapshot, snapshot.get_player(player.player_id),
		AIActionCandidate.Behavior.SUPPORT, "forward", Vector2(25, 15), Vector2(25, 0))
	_check(ordinary.x <= 24 and ordinary.y <= 14, "ordinary positioning still respects field margins")

## Only scenario setup writes state; acquisition itself must occur through the production source and simulation.
func _test_boundary_pickups() -> void:
	var f := Fixture.new()
	for point in [Vector2(0, 14.8), Vector2(0, -14.8), Vector2(24.8, 0),
			Vector2(-24.8, 0), Vector2(24.8, 14.8), Vector2(25.3, 0)]:
		var simulation := f.formal.create(4.0)
		for player in simulation._player_runtime_system.get_players():
			player.state_machine.reset_to_spawn(Vector2(-20, 0))
		var collector := simulation._player_runtime_system.get_player("swift_forward")
		collector.state_machine.reset_to_spawn(point - point.normalized() * 2.0)
		simulation._ball_runtime_system.reset_ball(point)
		var source := f.source(true)
		var loop := GameLoop.new(simulation, 1.0 / 60.0, 0.25, 8, null, [], [source])
		simulation.start_match()
		var acquired := false
		for step in range(90):
			var frame := loop.advance_frame(1.0 / 60.0, [])
			if frame.snapshot.ball.owner_player_id == collector.player_id:
				acquired = true
				break
		_check(acquired, "ordinary pickup succeeds near line at " + str(point))

## A twelve-metre threshold applies to both teams and the automatic airborne finishing route.
func _test_shooting_range() -> void:
	var f := Fixture.new()
	_check(f.tuning.number("shot_max_distance_m") == 12.0, "default maximum shooting distance is twelve metres")
	var builder := RoleCandidateBuilder.new(f.tuning, f.rules, f.formal.field)
	for side in [-1.0, 1.0]:
		var goal := Vector2(side * 25, 0)
		var carrier := f.player("carrier", Vector2(side * 10, 0))
		carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
		var ball := BallMatchState.new(carrier.state.position_m)
		ball._set_owner(carrier.player_id)
		var snapshot := f.snapshot([carrier], ball)
		var choices := builder.build(snapshot, carrier.player_id, "forward", Vector2.ZERO, goal, "", false)
		for candidate in choices:
			for option in candidate.targets:
				_check(option.action.action_type != MatchAction.Type.SHOOT, "fifteen-metre ground shot excluded")
		carrier.state_machine.try_start_jump(f.rules)
		carrier.advance(0.15)
		snapshot = f.snapshot([carrier], ball)
		_check(builder.aerial_action(snapshot, snapshot.get_player(carrier.player_id), goal) == null,
			"fifteen-metre airborne shot excluded")
		carrier.state._set_position(Vector2(side * 13, 0))
		snapshot = f.snapshot([carrier], ball)
		_check(builder.can_attempt_shot(snapshot.get_player(carrier.player_id), goal)
			and builder.aerial_action(snapshot, snapshot.get_player(carrier.player_id), goal) != null,
			"twelve-metre airborne finish remains available")

## Extracts only the controlled player's movement from a detached proposal list.
func _direction(actions: Array[MatchAction], player_id: String) -> Vector2:
	for action in actions:
		if action.player_id == player_id and action.action_type == MatchAction.Type.MOVE:
			return action.direction
	return Vector2.ZERO

## Aggregates independent regressions into the process exit code.
func _check(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
