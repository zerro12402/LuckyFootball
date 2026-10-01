class_name MatchAction
extends RefCounted

enum Type {
	NONE,
	MOVE,
	PASS,
	SHOOT,
	TACKLE,
	ATTACK,
	DODGE,
}

var player_id: String:
	get:
		return _player_id

var action_type: int:
	get:
		return _action_type

var direction: Vector2:
	get:
		return _direction

var target_player_id: String:
	get:
		return _target_player_id

var _player_id: String
var _action_type: int
var _direction: Vector2
var _target_player_id: String


func _init(
	new_player_id: String,
	new_action_type: int,
	new_direction: Vector2 = Vector2.ZERO,
	new_target_player_id: String = "",
) -> void:
	_player_id = new_player_id
	_action_type = new_action_type
	_direction = new_direction
	_target_player_id = new_target_player_id
