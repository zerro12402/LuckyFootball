class_name FieldDataLoadResult
extends RefCounted

var is_success: bool:
	get:
		return _errors.is_empty()

var fields: Array[FieldDefinition]:
	get:
		return _fields.duplicate()

var errors: PackedStringArray:
	get:
		return _errors.duplicate()

var _fields: Array[FieldDefinition] = []
var _errors: PackedStringArray = []


func _replace_fields(new_fields: Array[FieldDefinition]) -> void:
	_fields = new_fields.duplicate()


func _add_error(message: String) -> void:
	_errors.append(message)
