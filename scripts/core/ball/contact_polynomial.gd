## Isolates polynomial roots to detect swept contacts without frame-size sampling gaps.
class_name ContactPolynomial
extends RefCounted

const EPSILON := 0.00000001

## Evaluates ascending-order coefficients using Horner's rule.
static func evaluate(coefficients: Array[float], time: float) -> float:
	var value := 0.0
	for index in range(coefficients.size() - 1, -1, -1):
		value = value * time + coefficients[index]
	return value

## Multiplies two short polynomials used by planar distance and flight height.
static func multiply(left: Array[float], right: Array[float]) -> Array[float]:
	var product: Array[float] = []
	product.resize(left.size() + right.size() - 1)
	product.fill(0.0)
	for i in range(left.size()):
		for j in range(right.size()):
			product[i + j] += left[i] * right[j]
	return product

## Partitions at derivative roots, then bisects each monotonic interval, including tangencies.
static func roots(coefficients: Array[float], start: float, end: float) -> Array[float]:
	var values: Array[float] = coefficients.duplicate()
	while values.size() > 1 and absf(values.back()) < EPSILON:
		values.pop_back()
	var result: Array[float] = []
	if values.size() <= 1:
		return result
	if values.size() == 2:
		var root := -values[0] / values[1]
		if root >= start - EPSILON and root <= end + EPSILON:
			result.append(clampf(root, start, end))
		return result
	var derivative: Array[float] = []
	for index in range(1, values.size()):
		derivative.append(values[index] * index)
	var checkpoints: Array[float] = [start]
	checkpoints.append_array(roots(derivative, start, end))
	checkpoints.append(end)
	for point in checkpoints:
		if absf(evaluate(values, point)) < EPSILON:
			result.append(point)
	for index in range(checkpoints.size() - 1):
		var low := checkpoints[index]
		var high := checkpoints[index + 1]
		var low_value := evaluate(values, low)
		if low_value * evaluate(values, high) >= 0.0:
			continue
		for iteration in range(50):
			var middle := (low + high) * 0.5
			if low_value * evaluate(values, middle) <= 0.0:
				high = middle
			else:
				low = middle
				low_value = evaluate(values, low)
		result.append((low + high) * 0.5)
	result.sort()
	return result
