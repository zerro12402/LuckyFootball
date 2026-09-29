class_name BallMatchState
extends RefCounted

enum MotionState {
	LOOSE,
	OWNED,
	IN_FLIGHT,
}

var position_m: Vector2:
	get:
		return _position_m

var motion_state: int:
	get:
		return _motion_state

var owner_player_id: String:
	get:
		return _owner_player_id

var _position_m: Vector2
var _motion_state: int = MotionState.LOOSE
var _owner_player_id: String = ""


func _init(initial_position_m: Vector2) -> void:
	_position_m = initial_position_m


func _set_position(new_position_m: Vector2) -> void:
	_position_m = new_position_m


func _set_owner(player_id: String) -> void:
	assert(not player_id.is_empty(), "Ball owner ID cannot be empty")
	_owner_player_id = player_id
	_motion_state = MotionState.OWNED


func _release(new_position_m: Vector2) -> void:
	_position_m = new_position_m
	_owner_player_id = ""
	_motion_state = MotionState.LOOSE
