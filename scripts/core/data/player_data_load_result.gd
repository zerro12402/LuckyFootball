class_name PlayerDataLoadResult
extends RefCounted

var is_success: bool:
	get:
		return _errors.is_empty()

var players: Array[PlayerDefinition]:
	get:
		return _players.duplicate()

var errors: PackedStringArray:
	get:
		return _errors.duplicate()

var _players: Array[PlayerDefinition] = []
var _errors: PackedStringArray = []


func _replace_players(new_players: Array[PlayerDefinition]) -> void:
	_players = new_players.duplicate()


func _add_error(message: String) -> void:
	_errors.append(message)
