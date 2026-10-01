class_name BallStateSnapshot
extends RefCounted

var position_m: Vector2:
	get:
		return _position_m

var height_m: float:
	get:
		return _height_m

var motion_state: int:
	get:
		return _motion_state

var owner_player_id: String:
	get:
		return _owner_player_id

var target_player_id: String:
	get:
		return _target_player_id

var velocity_mps: Vector2:
	get:
		return _velocity_mps

var _position_m: Vector2
var _height_m: float
var _motion_state: int
var _owner_player_id: String
var _target_player_id: String
var _velocity_mps: Vector2


func _init(ball_state: BallMatchState) -> void:
	assert(ball_state != null, "Ball snapshot requires ball state")
	_position_m = ball_state.position_m
	_height_m = ball_state.height_m
	_motion_state = ball_state.motion_state
	_owner_player_id = ball_state.owner_player_id
	_target_player_id = ball_state.target_player_id
	_velocity_mps = ball_state.velocity_mps
