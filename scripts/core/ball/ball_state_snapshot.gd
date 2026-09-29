class_name BallStateSnapshot
extends RefCounted

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
var _motion_state: int
var _owner_player_id: String


func _init(ball_state: BallMatchState) -> void:
	assert(ball_state != null, "Ball snapshot requires ball state")
	_position_m = ball_state.position_m
	_motion_state = ball_state.motion_state
	_owner_player_id = ball_state.owner_player_id
