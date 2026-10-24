## Readonly CSV definition used to validate and assemble formal rosters.
class_name TeamPlayerDefinition
extends RefCounted

var team_id: String:
	get: return _team_id
var _team_id: String
var player_id: String:
	get: return _player_id
var _player_id: String
var slot: int:
	get: return _slot
var _slot: int
var default_position: String:
	get: return _default_position
var _default_position: String

func _init(new_team_id: String, new_player_id: String, new_slot: int, new_default_position: String) -> void:
	_team_id = new_team_id
	_player_id = new_player_id
	_slot = new_slot
	_default_position = new_default_position
