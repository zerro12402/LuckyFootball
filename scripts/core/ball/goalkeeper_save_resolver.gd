## Resolves the temporary F04 probability only after simulation validates physical contact.
class_name GoalkeeperSaveResolver
extends RefCounted

## Draws exactly once; invalid opportunities must be filtered before calling this function.
static func resolve(keeper_id: String, source: BallShotSource, lane: int,
		point: Vector2, height: float, probability: float, sampler: Callable) -> GoalkeeperSaveResult:
	assert(source != null and sampler.is_valid())
	var sample := float(sampler.call())
	assert(is_finite(sample) and sample >= 0.0 and sample < 1.0)
	return GoalkeeperSaveResult.new(keeper_id, source.sequence, lane,
		sample < probability, sample, point, height)
