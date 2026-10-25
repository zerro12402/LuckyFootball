## Immutable validated numeric AI tuning; match rules remain authoritative for actual actions.
class_name AIBehaviorConfig
extends RefCounted

var _numbers: Dictionary[String, float]
func _init(numbers: Dictionary[String, float]) -> void:
	_numbers = numbers.duplicate()

func number(key: String) -> float:
	assert(_numbers.has(key), "Unknown AI parameter: " + key)
	return _numbers[key]

## Maps a finite behavior enum to one stable parameter key.
func weight(role: String, behavior: int) -> float:
	var names: Array[String] = ["hold", "advance", "pass", "shoot", "jump", "support",
		"press", "tackle", "attack", "chase", "return", "save"]
	return number(role + "_" + names[behavior])
