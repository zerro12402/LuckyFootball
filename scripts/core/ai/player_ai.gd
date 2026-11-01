## Filters and weights read-only proposals before selecting a single category and target.
class_name PlayerAI
extends RefCounted

var random_draws: int:
	get: return _random_draws
var _random_draws: int = 0
var _rng := RandomNumberGenerator.new()
var _sampler: Callable
var _modifier: AIWeightModifier
var selected_target: AITargetOption:
	get: return _selected_target
var _selected_target: AITargetOption
var selected_behavior: int:
	get: return _selected_behavior
var _selected_behavior: int = AIActionCandidate.Behavior.HOLD

## Uses a versioned UTF-8 rolling hash, independent of process hash and contest RNG streams.
func _init(seed_value: int, player_id: String, modifier: AIWeightModifier = null,
		sampler: Callable = Callable()) -> void:
	var mixed := posmod(seed_value, 2147483647)
	for byte in ("lucky_ai_v1:" + player_id).to_utf8_buffer():
		mixed = (mixed * 131 + byte) % 2147483647
	_rng.seed = mixed
	_modifier = modifier if modifier != null else AIWeightModifier.new()
	_sampler = sampler if sampler.is_valid() else _next_sample

## Filters before modifiers and rechecks the selected action, never mutating caller-owned proposals.
func choose(snapshot: MatchStateSnapshot, player_id: String,
		candidates: Array[AIActionCandidate], config: MatchConfigDefinition) -> MatchAction:
	_selected_target = null
	_selected_behavior = AIActionCandidate.Behavior.HOLD
	if not snapshot.can_decide_player_actions:
		return null
	var sorted: Array[AIActionCandidate] = candidates.duplicate()
	sorted.sort_custom(func(a: AIActionCandidate, b: AIActionCandidate) -> bool: return a.behavior < b.behavior)
	var legal: Array[AIActionCandidate] = []
	var category_weights: Array[float] = []
	for candidate in sorted:
		var targets: Array[AITargetOption] = []
		for option in candidate.targets:
			if option.action.player_id == player_id and is_finite(option.weight) and option.weight > 0.0 \
					and ActionEligibility.allows(snapshot, option.action, config):
				targets.append(option)
		targets.sort_custom(_target_before)
		if targets.is_empty():
			continue
		var multiplier := _modifier.multiplier(snapshot, player_id, candidate.behavior)
		var weight := candidate.weight * multiplier
		if not is_finite(multiplier) or multiplier < 0.0 or not is_finite(weight) or weight <= 0.0:
			continue
		legal.append(AIActionCandidate.new(candidate.behavior, weight, targets))
		category_weights.append(weight)
	var index := WeightedActionSelector.choose_index(category_weights, _sampler)
	if index < 0:
		var stop := MatchAction.new(player_id, MatchAction.Type.MOVE)
		return stop if ActionEligibility.allows(snapshot, stop, config) else null
	var options := legal[index].targets
	_selected_behavior = legal[index].behavior
	var target_weights: Array[float] = []
	for option in options:
		target_weights.append(option.weight)
	var target_index := WeightedActionSelector.choose_index(target_weights, _sampler)
	var selected := options[target_index].action
	_selected_target = options[target_index]
	return selected if ActionEligibility.allows(snapshot, selected, config) else null

## Provides a total target order even when candidate generation receives shuffled player arrays.
static func _target_before(a: AITargetOption, b: AITargetOption) -> bool:
	if a.action.target_player_id != b.action.target_player_id:
		return a.action.target_player_id < b.action.target_player_id
	if a.action.direction.x != b.action.direction.x:
		return a.action.direction.x < b.action.direction.x
	return a.action.direction.y < b.action.direction.y

## Maps a seeded 32-bit draw into the half-open interval required by weighted selection.
func _next_sample() -> float:
	_random_draws += 1
	return float(_rng.randi()) / 4294967296.0
