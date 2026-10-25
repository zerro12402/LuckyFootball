## Selects a category then a target with explicit samples, stable order and legal zero-weight fallback.
class_name WeightedActionSelector
extends RefCounted

## Returns -1 without sampling for all-zero weights, and uses no sample for one positive option.
static func choose_index(weights: Array[float], sampler: Callable) -> int:
	var total := 0.0
	var positive := 0
	var single := -1
	for index in range(weights.size()):
		var weight := weights[index]
		if is_finite(weight) and weight > 0.0:
			total += weight
			positive += 1
			single = index
	if positive == 0:
		return -1
	if positive == 1:
		return single
	if not is_finite(total):
		return -1
	var sample := float(sampler.call())
	assert(is_finite(sample) and sample >= 0.0 and sample < 1.0)
	var remaining := sample * total
	for index in range(weights.size()):
		var weight := weights[index]
		if not is_finite(weight) or weight <= 0.0:
			continue
		if remaining < weight:
			return index
		remaining -= weight
	return single
