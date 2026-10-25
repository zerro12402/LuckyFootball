## Tests candidate legality, neutral modifiers, target-count independence and explicit random boundaries.
extends SceneTree
const Fixture = preload("res://tests/support/ai_fixture.gd")
var _failures: PackedStringArray = []
var _samples: int = 0

class ZeroModifier extends AIWeightModifier:
	func multiplier(_snapshot: MatchStateSnapshot, _id: String, _kind: int) -> float:
		return 0.0

class HugeModifier extends AIWeightModifier:
	func multiplier(_snapshot: MatchStateSnapshot, _id: String, _kind: int) -> float:
		return 1000000.0

## Exercises business boundaries using real runtime state copied to immutable observations.
func _init() -> void:
	var fixture := Fixture.new()
	var carrier := fixture.player("carrier")
	var teammate := fixture.player("mate", Vector2(5, 0))
	var enemy := fixture.player("enemy", Vector2(1, 0), "away")
	var ball := BallMatchState.new(Vector2.ZERO)
	ball._set_owner("carrier")
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	var snapshot := fixture.snapshot([carrier, teammate, enemy], ball)
	var shoot := MatchAction.new("carrier", MatchAction.Type.SHOOT)
	var pass_mate := MatchAction.new("carrier", MatchAction.Type.PASS, Vector2.ZERO, "mate")
	var pass_enemy := MatchAction.new("carrier", MatchAction.Type.PASS, Vector2.ZERO, "enemy")
	_check(ActionEligibility.allows(snapshot, shoot, fixture.rules), "owned shooting allowed")
	_check(not ActionEligibility.allows(snapshot, pass_enemy, fixture.rules), "opponent cannot be pass target")
	_check(not ActionEligibility.allows(snapshot, MatchAction.new("mate", MatchAction.Type.SHOOT), fixture.rules), "unowned shot rejected")
	var choices: Array[AIActionCandidate] = [
		AIActionCandidate.new(AIActionCandidate.Behavior.PASS, 1.0, [AITargetOption.new(pass_mate)]),
		AIActionCandidate.new(AIActionCandidate.Behavior.SHOOT, 1.0, [AITargetOption.new(shoot)])]
	var brain := PlayerAI.new(42, "carrier", null, _half)
	_check(brain._rng.seed == 63160759, "versioned UTF-8 AI seed derivation has a fixed golden vector")
	var selected := brain.choose(snapshot, "carrier", choices, fixture.rules)
	_check(selected.action_type == MatchAction.Type.SHOOT and _samples == 1, "half-open category boundary uses one sample; single target none")
	var more_targets: Array[AITargetOption] = [AITargetOption.new(pass_mate), AITargetOption.new(pass_mate), AITargetOption.new(pass_mate)]
	choices[0] = AIActionCandidate.new(AIActionCandidate.Behavior.PASS, 1.0, more_targets)
	selected = brain.choose(snapshot, "carrier", choices, fixture.rules)
	_check(selected.action_type == MatchAction.Type.SHOOT, "extra targets do not multiply pass category weight")
	var zero := PlayerAI.new(42, "carrier", ZeroModifier.new(), _half)
	var before := _samples
	selected = zero.choose(snapshot, "carrier", choices, fixture.rules)
	_check(selected.action_type == MatchAction.Type.MOVE and selected.direction == Vector2.ZERO and before == _samples, "zero modifier falls back legally without sampling")
	var illegal: Array[AIActionCandidate] = [AIActionCandidate.new(AIActionCandidate.Behavior.PASS, 1.0, [AITargetOption.new(pass_enemy)])]
	selected = PlayerAI.new(1, "carrier", HugeModifier.new()).choose(snapshot, "carrier", illegal, fixture.rules)
	_check(selected.action_type == MatchAction.Type.MOVE, "huge modifier cannot resurrect illegal targets")
	var neutral_a := PlayerAI.new(42, "carrier")
	var neutral_b := PlayerAI.new(42, "carrier", AIWeightModifier.new())
	for index in range(20):
		_check(neutral_a.choose(snapshot, "carrier", choices, fixture.rules).action_type == neutral_b.choose(snapshot, "carrier", choices, fixture.rules).action_type, "neutral weights preserve seeded choices")
	var copies := snapshot.players
	copies.clear()
	var targets := choices[0].targets
	targets.clear()
	_check(snapshot.players.size() == 3 and choices[0].targets.size() == 3 and carrier.state.position_m == Vector2.ZERO, "candidate and snapshot arrays are detached")
	enemy.state_machine.try_start_tackle(fixture.rules)
	enemy.advance(fixture.rules.tackle_action_duration_seconds + 0.001)
	var cooled := fixture.snapshot([carrier, teammate, enemy], ball)
	_check(cooled.get_player("enemy").tackle_cooldown_seconds > 0.0, "cooldown copied from live runtime")
	_check(not ActionEligibility.allows(cooled, MatchAction.new("enemy", MatchAction.Type.TACKLE, Vector2.LEFT, "carrier"), fixture.rules), "cooldown filters repeated tackles")
	var saved_cooldown := cooled.get_player("enemy").tackle_cooldown_seconds
	enemy.advance(10.0)
	_check(cooled.get_player("enemy").tackle_cooldown_seconds == saved_cooldown, "old snapshot cooldown cannot change with runtime")
	carrier.state_machine.start_knockdown(fixture.rules)
	var down := fixture.snapshot([carrier, teammate, enemy], ball)
	_check(brain.choose(down, "carrier", choices, fixture.rules) == null, "downed player has no illegal fallback")
	var samples: Array[float] = [0.0, 0.0]
	_check(WeightedActionSelector.choose_index(samples, _half) == -1, "all-zero selection absent")
	samples = [0.0, 3.0]
	before = _samples
	_check(WeightedActionSelector.choose_index(samples, _half) == 1 and before == _samples, "one positive weight needs no random sample")
	var states := [PlayerMatchState.ActionState.STAGGERED, PlayerMatchState.ActionState.GETTING_UP, PlayerMatchState.ActionState.LANDING]
	for state in states:
		carrier.state._set_action_state(state, PlayerMatchState.ActionPhase.ACTIVE)
		_check(not ActionEligibility.allows(fixture.snapshot([carrier], ball), shoot, fixture.rules), "locks reject shots")
	_finish()

## Counts explicit test draws, making accidental consumption visible.
func _half() -> float:
	_samples += 1
	return 0.5

## Records independent failures before returning one useful process status.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

## Exits without initializing a renderer or gameplay scene.
func _finish() -> void:
	for failure in _failures:
		printerr(failure)
	print("AI contracts: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)
