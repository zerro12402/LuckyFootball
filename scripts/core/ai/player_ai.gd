## Filters and weights read-only proposals before selecting a single category and target.
class_name PlayerAI
extends RefCounted

var random_draws: int:
	get: return _random_draws
var _random_draws: int = 0
var strategy_error: String = ""
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
		candidates: Array[AIActionCandidate], config: MatchConfigDefinition,
		strategy: PlayerAIDecisionStrategy = null, goal: Vector2 = Vector2.ZERO,
		pressured: bool = false) -> MatchAction:
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
	strategy_error = ""
	if strategy != null and not legal.is_empty():
		var direct := _apply_strategy(strategy, snapshot, player_id, goal, pressured, legal, category_weights)
		if direct != null:
			return direct
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

## Validates the entire response before consuming any random draw or changing lottery weights.
func _apply_strategy(strategy: PlayerAIDecisionStrategy, snapshot: MatchStateSnapshot,
		player_id: String, goal: Vector2, pressured: bool, legal: Array[AIActionCandidate],
		weights: Array[float]) -> MatchAction:
	var view := ScriptedAIContract.make_view(snapshot, player_id, goal, pressured, legal)
	var public_choices: Dictionary = view["candidates"]
	var result := strategy.decide(view.duplicate(true))
	if result.is_empty():
		return null
	if result.has("error"):
		strategy_error = str(result["error"])
	elif result.size() == 2 and result.get("behavior") is String and result.get("target") is String:
		var choice := ScriptedAIContract.select(legal, public_choices, result["behavior"], result["target"])
		if choice != null:
			_selected_behavior = ScriptedAIContract.BEHAVIORS[result["behavior"]]
			_selected_target = choice
			return choice.action
		strategy_error = "当前行为或目标不可用"
	elif result.size() == 1 and result.get("weights") is Dictionary:
		strategy_error = _apply_strategy_weights(result["weights"], public_choices, legal, weights)
	else:
		strategy_error = "无效的策略返回值"
	return null


## Keeps category weights atomic and rejects alias conflicts and empty lotteries.
func _apply_strategy_weights(multipliers: Dictionary, public_choices: Dictionary,
		legal: Array[AIActionCandidate], weights: Array[float]) -> String:
	var revised := weights.duplicate()
	var modified := {}
	for id in multipliers:
		var multiplier: Variant = multipliers[id]
		if not public_choices.has(id) or not (multiplier is int or multiplier is float) \
				or not is_finite(float(multiplier)) or float(multiplier) < 0.0:
			return "当前行为不可用或倍率无效：%s" % id
		var behavior: int = ScriptedAIContract.BEHAVIORS[id]
		if modified.has(behavior):
			return "同一行为不能重复加权"
		modified[behavior] = true
		for index in range(legal.size()):
			if legal[index].behavior == behavior:
				revised[index] *= float(multiplier)
				break
	var total := 0.0
	for weight in revised:
		total += weight
	if not is_finite(total) or total <= 0.0:
		return "调整后的权重总和无效"
	weights.assign(revised)
	return ""


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
