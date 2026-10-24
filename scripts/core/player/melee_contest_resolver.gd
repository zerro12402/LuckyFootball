## Resolves F05 then F06 from base attributes; geometry and commits belong to MatchSimulation.
class_name MeleeContestResolver
extends RefCounted

## Applies the independent attack advantage only to near-body dodge probability.
static func dodge_probability(strength: int, technique: int, config: MatchConfigDefinition) -> float:
	assert(strength >= 1 and strength <= 100 and technique >= 1 and technique <= 100)
	var difference := float(technique - strength) - config.melee_dodge_attack_advantage
	return clampf(1.0 / (1.0 + exp(-difference / config.melee_dodge_probability_scale)),
		config.melee_dodge_probability_min, config.melee_dodge_probability_max)

## Samples F05 once; F06 samples only a hit with a nonzero gap below its guaranteed-win threshold.
static func resolve(sequence: int, attacker_id: String, target_id: String,
		attack: int, defense: int, technique: int, point: Vector2, direction: Vector2,
		config: MatchConfigDefinition, dodge_sampler: Callable, strength_sampler: Callable,
		forced_outcome: int = -1) -> MeleeContestResult:
	assert(defense >= 1 and defense <= 100 and direction.is_normalized())
	var chance := dodge_probability(attack, technique, config)
	var gap := absi(attack - defense)
	var stronger := attacker_id if attack > defense else (target_id if defense > attack else "")
	var win := minf(float(gap) / config.melee_strength_auto_win_gap, 1.0)
	var dodge_sample := -1.0
	var strength_sample := -1.0
	var has_sample := false
	var outcome := MeleeContestResult.Outcome.DODGED
	var reason := MeleeContestResult.StrengthReason.DODGED
	if forced_outcome >= 0:
		assert(forced_outcome <= MeleeContestResult.Outcome.DRAW)
		outcome = forced_outcome
		reason = MeleeContestResult.StrengthReason.OVERRIDE
	else:
		dodge_sample = _draw(dodge_sampler)
		if dodge_sample >= chance:
			outcome = MeleeContestResult.Outcome.DRAW
			if gap == 0:
				reason = MeleeContestResult.StrengthReason.EQUAL_STRENGTH
			elif gap >= config.melee_strength_auto_win_gap:
				reason = MeleeContestResult.StrengthReason.GUARANTEED_WIN
			else:
				reason = MeleeContestResult.StrengthReason.SAMPLED
				has_sample = true
				strength_sample = _draw(strength_sampler)
			if gap > 0 and (not has_sample or strength_sample < win):
				outcome = MeleeContestResult.Outcome.ATTACKER_WIN if attack > defense else MeleeContestResult.Outcome.TARGET_WIN
	return MeleeContestResult.new(sequence, attacker_id, target_id, attack, defense, technique,
		point, direction, chance, dodge_sample, outcome, gap, config.melee_strength_auto_win_gap, stronger, win,
		has_sample, strength_sample, reason, forced_outcome >= 0)

## Rejects malformed injected samples rather than silently changing the configured probabilities.
static func _draw(sampler: Callable) -> float:
	assert(sampler.is_valid())
	var sample := float(sampler.call())
	assert(is_finite(sample) and sample >= 0.0 and sample < 1.0)
	return sample
