## Copies ball motion and its explicit hand/foot attachment for read-only presentation.
class_name BallStateSnapshot
extends RefCounted

var shot_distance_m: float:
	get: return _shot_distance_m
var shot_knockdown_count: int:
	get: return _shot_knockdown_count
var _shot_distance_m: float
var _shot_knockdown_count: int
var flight_kind: int:
	get: return _flight_kind
var shot_aim: ShotAim:
	get: return _shot_aim
var _flight_kind: int
var _shot_aim: ShotAim

var control_attachment: int:
	get: return _control_attachment
var _control_attachment: int
var flight_apex_height_m: float:
	get: return _flight_apex_height_m
var flight_start_height_m: float:
	get: return _flight_start_height_m
var flight_distance_m: float:
	get: return _flight_distance_m
var flight_range_m: float:
	get: return _flight_range_m
var _flight_apex_height_m: float
var _flight_start_height_m: float
var _flight_distance_m: float
var _flight_range_m: float
var last_kicker_id: String:
	get: return _last_kicker_id
var flight_sequence: int:
	get: return _flight_sequence
var defensive_touched: bool:
	get: return _defensive_touched
var _last_kicker_id: String
var _flight_sequence: int
var _defensive_touched: bool

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


## Copies state and cumulative measurements so later motion or ownership cleanup cannot rewrite a frame.
func _init(ball_state: BallMatchState, aim: ShotAim = null, distance_m: float = 0.0,
		knockdowns: int = 0, kicker_id: String = "", sequence: int = 0,
		was_defensively_touched: bool = false) -> void:
	assert(ball_state != null, "Ball snapshot requires ball state")
	_shot_distance_m = distance_m
	_last_kicker_id = kicker_id
	_flight_sequence = sequence
	_defensive_touched = was_defensively_touched
	_flight_apex_height_m = ball_state.flight_apex_height_m
	_flight_start_height_m = ball_state.flight_start_height_m
	_flight_distance_m = ball_state.flight_distance_m
	_flight_range_m = ball_state.flight_range_m
	_shot_knockdown_count = knockdowns
	_flight_kind = ball_state.flight_kind
	_shot_aim = aim
	_control_attachment = ball_state.control_attachment
	_position_m = ball_state.position_m
	_height_m = ball_state.height_m
	_motion_state = ball_state.motion_state
	_owner_player_id = ball_state.owner_player_id
	_target_player_id = ball_state.target_player_id
	_velocity_mps = ball_state.velocity_mps
