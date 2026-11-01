## Verifies football, tactical, airborne and goalkeeper decisions from explicit observable snapshots.
extends SceneTree
const Fixture = preload("res://tests/support/ai_fixture.gd")
var _failures: PackedStringArray = []

## Covers core behavior windows without starting an animated gameplay scene.
func _init() -> void:
	var f := Fixture.new()
	var builder := RoleCandidateBuilder.new(f.tuning, f.rules, f.formal.field)
	var carrier := f.player("carrier", Vector2(10, 0))
	var mate := f.player("mate", Vector2(0, 5))
	var opponent := f.player("opponent", Vector2(11, 0), "away")
	var keeper := f.player("keeper", Vector2(24.2, 0), "away", true)
	var ball := BallMatchState.new(carrier.state.position_m)
	ball._set_owner("carrier")
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	var snapshot := f.snapshot([carrier, mate, opponent, keeper], ball)
	var goal := Vector2(25, 0)
	var candidates := builder.build(snapshot, "carrier", "forward", Vector2(-1, 0), goal, "carrier", false)
	_check(_has_legal(candidates, MatchAction.Type.PASS, snapshot, f.rules), "carrier has legal teammate pass")
	_check(_has_legal(candidates, MatchAction.Type.SHOOT, snapshot, f.rules), "carrier has legal shot")
	_check(_has_legal(candidates, MatchAction.Type.JUMP, snapshot, f.rules), "carrier has legal carrying jump")
	var tired := builder.build(snapshot, "carrier", "forward", Vector2(-1, 0), goal, "carrier", false, 0.0)
	_check(_weight(tired, AIActionCandidate.Behavior.ADVANCE) < _weight(candidates, AIActionCandidate.Behavior.ADVANCE), "optional low stamina reduces high-intensity preference")
	var unavailable := builder.build(snapshot, "carrier", "forward", Vector2(-1, 0), goal, "carrier", false, -1.0)
	_check(_weight(unavailable, AIActionCandidate.Behavior.ADVANCE) == _weight(candidates, AIActionCandidate.Behavior.ADVANCE), "unavailable stamina remains explicitly neutral")
	carrier.state_machine.try_start_jump(f.rules)
	carrier.advance(0.15)
	snapshot = f.snapshot([carrier, mate, opponent, keeper], ball)
	_check(ActionEligibility.allows(snapshot, builder.aerial_action(snapshot, snapshot.get_player("carrier")), f.rules), "airborne carrier can shoot")
	carrier.state_machine.reset_to_spawn(Vector2(10, 0))
	ball._set_position(Vector2(5, 0))
	ball._launch_pass("mate", Vector2.LEFT * 14, 10, 1.8)
	ball._advance_flight(Vector2(3, 0), 2)
	snapshot = f.snapshot([carrier, mate, opponent, keeper], ball, "carrier")
	_check(TeamTacticalContext.phase_for(snapshot, "home") == TeamTacticalContext.Phase.ATTACK, "untouched pass retains attacking tactics")
	snapshot = f.snapshot([carrier, mate, opponent, keeper], ball, "carrier", 1, true)
	_check(TeamTacticalContext.phase_for(snapshot, "home") == TeamTacticalContext.Phase.LOOSE, "real defensive contact produces loose tactics")
	_check(builder.save_candidate(snapshot, snapshot.get_player("keeper"), Vector2(-25, 0)) == null, "high pass cannot trigger active save")
	var coordinator := TeamRoleCoordinator.new()
	var primary := coordinator.select_primary(snapshot, "away", ball.position_m, f.tuning)
	_check(primary == "opponent", "keeper excluded from primary pursuer")
	ball._set_owner("carrier")
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	snapshot = f.snapshot([carrier, mate, opponent, keeper], ball)
	candidates = builder.build(snapshot, "opponent", "back", Vector2(15, 0), -goal, "opponent", false)
	_check(_has_legal(candidates, MatchAction.Type.TACKLE, snapshot, f.rules), "near carrier produces tackle")
	_check(_has_legal(candidates, MatchAction.Type.ATTACK, snapshot, f.rules), "near carrier produces melee")
	_check(_weight(candidates, AIActionCandidate.Behavior.RETURN) == 0.0
		and _weight(candidates, AIActionCandidate.Behavior.HOLD) == 0.0,
		"designated defender must pursue or challenge instead of returning or holding")
	for lane in [-1, 0, 1]:
		ball._launch_shot(Vector2(16, lane), Vector2(20, 0), 20, 0.65)
		snapshot = f.snapshot([carrier, mate, opponent, keeper], ball, "carrier", lane + 2, true)
		var save := builder.save_candidate(snapshot, snapshot.get_player("keeper"), -goal)
		_check(save != null and _has_legal([save], MatchAction.Type.SAVE, snapshot, f.rules), "shot lane produces legal save even in loose tactics")
	keeper.state_machine.start_knockdown(f.rules)
	_check(not ActionEligibility.allows(f.snapshot([keeper], ball), MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2.LEFT), f.rules), "downed keeper cannot save")
	# A long pass is approaching its selected stationary receiver, before ordinary ground pickup.
	var receiver := f.player("receiver", Vector2(12, 0))
	ball._set_position(Vector2.ZERO)
	ball._launch_pass("receiver", Vector2(14, 0), 12, 1.8)
	ball._advance_flight(Vector2(8.5, 0), 8.5)
	snapshot = f.snapshot([receiver], ball, "carrier")
	var jump := builder.aerial_action(snapshot, snapshot.get_player("receiver"))
	_check(jump != null and jump.action_type == MatchAction.Type.JUMP, "directed high pass triggers pre-contact jump")
	ball._set_position(Vector2.ZERO)
	ball._launch_pass("receiver", Vector2(14, 0), 12, 1.8)
	snapshot = f.snapshot([receiver], ball, "carrier")
	_check(builder.aerial_action(snapshot, snapshot.get_player("receiver")) == null, "distant high pass does not jump too early")
	for failure in _failures:
		printerr(failure)
	print("AI behaviors: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

## Checks legal output, not merely the presence of an unfiltered category.
func _has_legal(candidates: Array[AIActionCandidate], kind: int, snapshot: MatchStateSnapshot,
		rules: MatchConfigDefinition) -> bool:
	for candidate in candidates:
		for target in candidate.targets:
			if target.action.action_type == kind and ActionEligibility.allows(snapshot, target.action, rules):
				return true
	return false

## Looks up a category's pre-selection weight for deterministic monotonic assertions.
func _weight(candidates: Array[AIActionCandidate], kind: int) -> float:
	for candidate in candidates:
		if candidate.behavior == kind:
			return candidate.weight
	return 0.0

## Accumulates scenario failures without hiding later independent checks.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
