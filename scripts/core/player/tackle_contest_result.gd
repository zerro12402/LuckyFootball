## Captures the immutable F02 inputs, probability, one random sample and outcome.
class_name TackleContestResult
extends RefCounted

var tackling: int:
	get: return _tackling
var technique: int:
	get: return _technique
var probability: float:
	get: return _probability
var sample: float:
	get: return _sample
var succeeded: bool:
	get: return _sample < _probability

var _tackling: int
var _technique: int
var _probability: float
var _sample: float

func _init(tackling_value: int, technique_value: int, success_probability: float, random_sample: float) -> void:
	_tackling = tackling_value
	_technique = technique_value
	_probability = success_probability
	_sample = random_sample
