## Readonly CSV definition used to validate and assemble formal rosters.
class_name FormationPositionDefinition
extends RefCounted

var formation_id: String:
	get: return _formation_id
var _formation_id: String
var position_id: String:
	get: return _position_id
var _position_id: String
var position_m: Vector2:
	get: return _position_m
var _position_m: Vector2

func _init(new_formation_id: String, new_position_id: String, new_position_m: Vector2) -> void:
	_formation_id = new_formation_id
	_position_id = new_position_id
	_position_m = new_position_m
