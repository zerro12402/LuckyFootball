## Returns either a complete set of typed match configurations or CSV errors.
class_name MatchConfigDataLoadResult
extends RefCounted

var is_success: bool:
	get:
		return _errors.is_empty()

var configs: Array[MatchConfigDefinition]:
	get:
		return _configs.duplicate()

var errors: PackedStringArray:
	get:
		return _errors.duplicate()

var _configs: Array[MatchConfigDefinition] = []
var _errors: PackedStringArray = []


## Publishes parsed definitions only after the entire CSV has passed validation.
func _replace_configs(new_configs: Array[MatchConfigDefinition]) -> void:
	_configs = new_configs.duplicate()


## Accumulates row diagnostics without exposing mutable error storage.
func _add_error(message: String) -> void:
	_errors.append(message)
