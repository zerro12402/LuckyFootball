## Resolves F02 from explicit attributes and one injected sample; geometry belongs to simulation.
class_name TackleContestResolver
extends RefCounted

## Computes a monotonic S-shaped probability while retaining configured underdog chances.
static func probability(tackling: int, technique: int, config: MatchConfigDefinition) -> float:
	assert(tackling >= 1 and tackling <= 100 and technique >= 1 and technique <= 100)
	assert(config != null)
	return clampf(1.0 / (1.0 + exp(-float(tackling - technique) / config.tackle_probability_scale)),
		config.tackle_probability_min, config.tackle_probability_max)

## Draws only after the caller has confirmed a legal active contact; equality with P fails.
static func resolve(tackling: int, technique: int, config: MatchConfigDefinition,
		sampler: Callable) -> TackleContestResult:
	var chance := probability(tackling, technique, config)
	assert(sampler.is_valid())
	var sample := float(sampler.call())
	assert(is_finite(sample) and sample >= 0.0 and sample < 1.0)
	return TackleContestResult.new(tackling, technique, chance, sample)
