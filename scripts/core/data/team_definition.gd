## Readonly CSV definition used to validate and assemble formal rosters.
class_name TeamDefinition
extends RefCounted

var team_id: String:
	get: return _team_id
var _team_id: String
var display_name: String:
	get: return _display_name
var _display_name: String
var default_formation: String:
	get: return _default_formation
var _default_formation: String
var attacking_direction: int:
	get: return _attacking_direction
var _attacking_direction: int

func _init(new_team_id: String, new_display_name: String, new_default_formation: String, new_attacking_direction: int) -> void:
	_team_id = new_team_id
	_display_name = new_display_name
	_default_formation = new_default_formation
	_attacking_direction = new_attacking_direction
