## Carries immutable player intent into the fixed-step match simulation.
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
	RESET_ROUND,
	RESTART_TEST,
	JUMP,
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

var power: float:
	get:
		return _power

var _player_id: String
var _action_type: int
var _direction: Vector2
var _target_player_id: String
var _power: float


func _init(
	new_player_id: String,
	new_action_type: int,
	new_direction: Vector2 = Vector2.ZERO,
	new_target_player_id: String = "",
	new_power: float = 1.0,
) -> void:
	_player_id = new_player_id
	_action_type = new_action_type
	_direction = new_direction
	_target_player_id = new_target_player_id
	_power = new_power
