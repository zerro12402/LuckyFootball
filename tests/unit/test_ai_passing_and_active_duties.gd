## Regresses directional passing and live defensive/support duties using read-only snapshots.
extends SceneTree
const Fixture = preload("res://tests/support/ai_fixture.gd")
var _failures: PackedStringArray = []

class SupportPreference extends AIWeightModifier:
	## Makes one support plan deterministic without altering rules or the other actors' behavior.
	func multiplier(_snapshot: MatchStateSnapshot, id: String, behavior: int) -> float:
		if id == "formal_player_02":
			return 1.0 if behavior == AIActionCandidate.Behavior.SUPPORT else 0.0
		return 1.0

class PressPreference extends AIWeightModifier:
	## Isolates movement from randomly chosen tackle or attack animations.
	func multiplier(_snapshot: MatchStateSnapshot, id: String, behavior: int) -> float:
		if id == "formal_player_04":
			return 1.0 if behavior == AIActionCandidate.Behavior.PRESS else 0.0
		return 1.0


## Tests intent weighting, persistent moving targets and immediate handoffs before ordinary heartbeat expiry.
func _init() -> void:
	_test_directional_passes()
	_test_pressing_and_handoff()
	_test_press_stops_without_jitter()
	_test_press_tracks_a_moving_carrier_continuously()
	_test_retreat_on_keeper_possession()
	_test_live_support()
	_test_actual_player_movement()
	for failure in _failures:
		printerr(failure)
	print("AI passing and active duties: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

## Holds the goal-side position through small reversals and follows a substantial displacement.
func _test_press_stops_without_jitter() -> void:
	var f := Fixture.new()
	var carrier := f.player("swift_forward", Vector2.ZERO)
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	var defender := f.player("formal_player_04", Vector2(f.rules.tackle_start_range_m * 0.5, 0), "away")
	var ball := BallMatchState.new(Vector2.ZERO)
	ball._set_owner(carrier.player_id)
	var source := MatchPlayerAISource.new(f.formal.teams, f.formal.field, f.rules, f.tuning, PressPreference.new())
	var step := 0
	for offset: float in [0.0, 0.35, -0.35, 0.35]:
		carrier.state._set_position(Vector2(offset, 0))
		var actions := source.propose_actions(f.snapshot([carrier, defender], ball, "", 1, false, step))
		_check(source._plans[defender.player_id].behavior == AIActionCandidate.Behavior.PRESS
			and _movement(actions, defender.player_id).is_zero_approx(),
			"A stopped defender ignores small reversals of the goal-side press target")
		step += 1
	carrier.state._set_position(Vector2(0.65, 0))
	var actions := source.propose_actions(f.snapshot([carrier, defender], ball, "", 1, false, step))
	_check(_movement(actions, defender.player_id).x > 0.0, "A stopped defender resumes pressing once the target moves away")


## Checks the actual movement state across fixed steps with a slower, steadily dribbling carrier.
func _test_press_tracks_a_moving_carrier_continuously() -> void:
	var f := Fixture.new()
	var carrier := f.player("swift_forward", Vector2.ZERO)
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	carrier.state_machine.set_movement_input(Vector2.LEFT * 0.3)
	var defender := f.player("formal_player_04", Vector2(f.rules.tackle_start_range_m * 0.5 + 0.35, 0), "away")
	defender.state_machine.set_movement_input(Vector2.LEFT)
	var ball := BallMatchState.new(Vector2.ZERO)
	ball._set_owner(carrier.player_id)
	var source := MatchPlayerAISource.new(f.formal.teams, f.formal.field, f.rules, f.tuning, PressPreference.new())
	var fixed_step := 1.0 / 60.0
	for step in range(90):
		var snapshot := f.snapshot([carrier, defender], ball, "", 1, false, step)
		var actions := source.propose_actions(snapshot)
		defender.state_machine.set_movement_input(_movement(actions, defender.player_id))
		_check(defender.state.movement_state == PlayerMatchState.MovementState.MOVING,
			"An already moving defender keeps running while pacing a slower dribbler")
		defender.advance(fixed_step)
		carrier.advance(fixed_step)

	var builder := RoleCandidateBuilder.new(f.tuning, f.rules, f.formal.field)
	var snapshot := f.snapshot([carrier, defender], ball)
	var cover := builder.build(snapshot, defender.player_id, "back", Vector2(16, 0),
		Vector2(-25, 0), "another_defender", false)
	for candidate in cover:
		_check(candidate.behavior != AIActionCandidate.Behavior.HOLD,
			"A covering defender cannot randomly idle while the opponent controls the ball")


## The former presser must drop back on the same frame that the opposing keeper gains control.
func _test_retreat_on_keeper_possession() -> void:
	var f := Fixture.new()
	var carrier := f.player("swift_forward", Vector2(-24, 0))
	var keeper := f.player("steady_keeper", Vector2(-24, 0), "home", true)
	var defender := f.player("formal_player_04", Vector2(-22, 0), "away")
	var players: Array[PlayerRuntime] = [carrier, keeper, defender]
	var ball := BallMatchState.new(carrier.state.position_m)
	ball._set_owner(carrier.player_id)
	var source := f.source(true)
	source.propose_actions(f.snapshot(players, ball))
	_check(source._plans[defender.player_id].behavior == AIActionCandidate.Behavior.PRESS,
		"An ordinary opposing carrier draws the primary defender")
	ball._set_owner(keeper.player_id)
	var snapshot := f.snapshot(players, ball, "", 1, false, 1)
	var actions := source.propose_actions(snapshot)
	_check(TeamTacticalContext.phase_for(snapshot, "home") == TeamTacticalContext.Phase.ATTACK
		and TeamTacticalContext.phase_for(snapshot, "away") == TeamTacticalContext.Phase.DEFEND,
		"Keeper control puts the keeper's team on attack and its opponent on defense")
	_check(source._plans[defender.player_id].behavior == AIActionCandidate.Behavior.RETURN
		and _movement(actions, defender.player_id).x > 0.0,
		"The former presser returns to its defensive region before the next heartbeat")
	ball._set_owner(carrier.player_id)
	source.propose_actions(f.snapshot(players, ball, "", 1, false, 2))
	_check(source._plans[defender.player_id].behavior == AIActionCandidate.Behavior.PRESS,
		"Ordinary pressing resumes when a field player takes possession")


## Forward/backward uses team attack direction, including mirrored sides and a backward-only escape.
func _test_directional_passes() -> void:
	var f := Fixture.new()
	var builder := RoleCandidateBuilder.new(f.tuning, f.rules, f.formal.field)
	for side in [-1.0, 1.0]:
		var carrier := f.player("carrier")
		carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
		carrier.state._set_facing_direction(Vector2(-side, 0))
		var forward := f.player("forward", Vector2(side * 8, 0))
		var lateral := f.player("lateral", Vector2(0, 5))
		var backward := f.player("backward", Vector2(-side * 8, 0))
		var ball := BallMatchState.new(Vector2.ZERO)
		ball._set_owner("carrier")
		var snapshot := f.snapshot([carrier, forward, lateral, backward], ball)
		var pass_candidate := _find_pass(builder.build(snapshot, "carrier", "mid",
			Vector2.ZERO, Vector2(side * 25, 0), "", false))
		_check(pass_candidate != null and pass_candidate.targets.size() == 3, "all legal directions remain possible")
		_check(_target_weight(pass_candidate, "forward") == 4.0 and _target_weight(pass_candidate, "lateral") == 1.0
			and _target_weight(pass_candidate, "backward") == 0.1, "forward > lateral > backward independent of sprite facing")
		var brain := PlayerAI.new(42, "carrier", null, func() -> float: return 0.5)
		var action := brain.choose(snapshot, "carrier", [pass_candidate], f.rules)
		_check(action.target_player_id == "forward", "fixed weighted sample favors the forward teammate")
		snapshot = f.snapshot([carrier, backward], ball)
		var back_only := _find_pass(builder.build(snapshot, "carrier", "mid",
			Vector2.ZERO, Vector2(side * 25, 0), "", false))
		_check(back_only.weight > 0 and back_only.weight < pass_candidate.weight, "backward-only options reduce pass frequency without removing escape")
		_check(brain.choose(snapshot, "carrier", [back_only], f.rules).target_player_id == "backward",
			"legal fallback pass remains available when no forward teammate exists")

## The designated defender cannot choose a stationary role, follows a turning carrier, and hands off when downed.
func _test_pressing_and_handoff() -> void:
	var f := Fixture.new()
	var carrier := f.player("swift_forward")
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	var first := f.player("formal_player_04", Vector2(10, 0), "away")
	var second := f.player("formal_player_05", Vector2(14, 0), "away")
	var ball := BallMatchState.new(Vector2.ZERO)
	ball._set_owner(carrier.player_id)
	var source := f.source()
	var snapshot := f.snapshot([carrier, first, second], ball)
	var initial := source.propose_actions(snapshot)
	_check(_movement(initial, first.player_id).x < 0, "an assigned defender actually closes down the carrier")
	var original_plan: PlayerAIPlan = source._plans[first.player_id]
	_check(original_plan.behavior == AIActionCandidate.Behavior.PRESS, "primary defender cannot randomly hold or return")
	var draws := source.get_random_draws(first.player_id)
	carrier.state._set_position(Vector2(0, 5))
	snapshot = f.snapshot([carrier, first, second], ball, "", 1, false, 1)
	var turning := source.propose_actions(snapshot)
	_check(_movement(turning, first.player_id).y > 0.0, "turning carrier updates pursuit target before heartbeat")
	_check(source._plans[first.player_id] == original_plan and source.get_random_draws(first.player_id) == draws,
		"following the live target preserves the plan and random stream")
	first.state_machine.start_knockdown(f.rules)
	snapshot = f.snapshot([carrier, first, second], ball, "", 1, false, 2)
	var handed_off := source.propose_actions(snapshot)
	_check(_movement(handed_off, second.player_id).x < 0 and source._plans[second.player_id].behavior == AIActionCandidate.Behavior.PRESS,
		"downed pursuer hands over immediately instead of leaving everyone stationary")
	var previous_start: float = source._plans[second.player_id].started_at
	carrier.state._set_position(Vector2(12.5, 0))
	snapshot = f.snapshot([carrier, first, second], ball, "", 1, false, 3)
	source.propose_actions(snapshot)
	_check(source._plans[second.player_id].started_at > previous_start,
		"new legal contest window triggers an immediate review")
	var coordinator := TeamRoleCoordinator.new()
	second.state_machine.try_start_jump(f.rules, true)
	snapshot = f.snapshot([first, second], ball)
	_check(coordinator.select_primary(snapshot, "away", Vector2.ZERO, f.tuning).is_empty(),
		"downed and airborne actors cannot reserve the active ground-defense duty")

## Support targets follow an advancing teammate without waiting for random reselection; receivers keep their lane.
func _test_live_support() -> void:
	var f := Fixture.new()
	var carrier := f.player("swift_forward")
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	var teammate := f.player("formal_player_02", Vector2(-8, -6))
	var ball := BallMatchState.new(Vector2.ZERO)
	ball._set_owner(carrier.player_id)
	var source := MatchPlayerAISource.new(f.formal.teams, f.formal.field, f.rules, f.tuning, SupportPreference.new())
	var snapshot := f.snapshot([carrier, teammate], ball)
	var initial := source.propose_actions(snapshot)
	_check(not _movement(initial, teammate.player_id).is_zero_approx(), "teammate moves into a support lane")
	var plan: PlayerAIPlan = source._plans[teammate.player_id]
	var destination := plan.target_m
	var draws := source.get_random_draws(teammate.player_id)
	carrier.state._set_position(Vector2(5, 2))
	snapshot = f.snapshot([carrier, teammate], ball, "", 1, false, 1)
	source.propose_actions(snapshot)
	_check(source._plans[teammate.player_id] == plan and plan.target_m.x > destination.x and plan.target_m.y > destination.y,
		"support lane advances with the carrier before heartbeat expiry")
	_check(source.get_random_draws(teammate.player_id) == draws, "support tracking consumes no extra random draws")
	var builder := RoleCandidateBuilder.new(f.tuning, f.rules, f.formal.field)
	ball._launch_pass(teammate.player_id, Vector2.LEFT * 14, 12, 1.8)
	snapshot = f.snapshot([carrier, teammate], ball, carrier.player_id)
	_check(builder.movement_target(snapshot, snapshot.get_player(teammate.player_id),
		AIActionCandidate.Behavior.SUPPORT, "mid", Vector2(-7, -6), Vector2(25, 0)) == teammate.state.position_m,
		"selected pass receiver keeps the receiving lane")

## Advances the actual simulation after setup so valid intent must produce visible-world position changes.
func _test_actual_player_movement() -> void:
	var f := Fixture.new()
	var simulation := f.formal.create(5.0)
	for runtime in simulation._player_runtime_system.get_players():
		runtime.state_machine.reset_to_spawn(Vector2(-18, -12) if runtime.team_id == "home" else Vector2(18, 12))
	var carrier := simulation._player_runtime_system.get_player("swift_forward")
	var defender := simulation._player_runtime_system.get_player("formal_player_04")
	var supporter := simulation._player_runtime_system.get_player("formal_player_02")
	carrier.state_machine.reset_to_spawn(Vector2.ZERO)
	defender.state_machine.reset_to_spawn(Vector2(5, 0))
	supporter.state_machine.reset_to_spawn(Vector2(-5, -5))
	simulation._ball_runtime_system.reset_ball(Vector2(0.55, 0))
	var defender_start := defender.state.position_m
	var supporter_start := supporter.state.position_m
	var defender_travel := 0.0
	var supporter_travel := 0.0
	var loop := GameLoop.new(simulation, 1.0 / 60.0, 0.25, 8, null, [], [f.source()])
	simulation.start_match()
	for step in range(180):
		loop.advance_frame(1.0 / 60.0, [])
		defender_travel = maxf(defender_travel, defender.state.position_m.distance_to(defender_start))
		supporter_travel = maxf(supporter_travel, supporter.state.position_m.distance_to(supporter_start))
	_check(defender_travel > 0.5, "opponent actually moves in the simulated match")
	_check(supporter_travel > 0.5, "teammate actually moves in the simulated match")

## Locates the one pass category without multiplying it by target count.
func _find_pass(candidates: Array[AIActionCandidate]) -> AIActionCandidate:
	for candidate in candidates:
		if candidate.behavior == AIActionCandidate.Behavior.PASS:
			return candidate
	return null

## Reads immutable target weights for exact boundary tests.
func _target_weight(candidate: AIActionCandidate, id: String) -> float:
	for option in candidate.targets:
		if option.action.target_player_id == id:
			return option.weight
	return -1.0

## Extracts a public move intent; tests never inspect rendered pixels.
func _movement(actions: Array[MatchAction], id: String) -> Vector2:
	for action in actions:
		if action.player_id == id and action.action_type == MatchAction.Type.MOVE:
			return action.direction
	return Vector2.ZERO

## Accumulates independent regression failures.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
