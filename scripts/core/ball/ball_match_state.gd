## Holds the ball's ownership and one active pass or shot trajectory.
class_name BallMatchState
extends RefCounted


enum MotionState {
	LOOSE,
	OWNED,
	IN_FLIGHT,
}

enum FlightKind {
	NONE,
	PASS,
	SHOT,
}

var position_m: Vector2:
	get:
		return _position_m

var motion_state: int:
	get:
		return _motion_state

var flight_kind: int:
	get:
		return _flight_kind

var owner_player_id: String:
	get:
		return _owner_player_id

var target_player_id: String:
	get:
		return _target_player_id

var velocity_mps: Vector2:
	get:
		return _velocity_mps

var flight_distance_m: float:
	get:
		return _flight_distance_m

var flight_range_m: float:
	get:
		return _flight_range_m

var height_m: float:
	get:
		return _height_m

var _position_m: Vector2
var _motion_state: int = MotionState.LOOSE
var _flight_kind: int = FlightKind.NONE
var _owner_player_id: String = ""
var _target_player_id: String = ""
var _velocity_mps: Vector2 = Vector2.ZERO
var _flight_distance_m: float = 0.0
var _flight_range_m: float = 0.0
var _flight_apex_height_m: float = 0.0
var _flight_start_height_m: float = 0.0
var _height_m: float = 0.0


func _init(initial_position_m: Vector2) -> void:
	_position_m = initial_position_m


func _set_position(new_position_m: Vector2) -> void:
	_position_m = new_position_m


## Atomically assigns ownership and clears any previous trajectory.
func _set_owner(player_id: String) -> void:
	assert(not player_id.is_empty(), "Ball owner ID cannot be empty")
	_owner_player_id = player_id
	_motion_state = MotionState.OWNED
	_clear_flight()


## Keeps the one owned ball at its carrier's simulated height.
func _set_control_height(new_height_m: float) -> void:
	assert(_motion_state == MotionState.OWNED)
	assert(new_height_m >= 0.0 and is_finite(new_height_m))
	_height_m = new_height_m


## Releases a pass with its fixed target and possible parabolic height.
func _launch_pass(
	target_id: String,
	pass_velocity_mps: Vector2,
	flight_range_m: float,
	apex_height_m: float,
) -> void:
	assert(not target_id.is_empty(), "A pass requires a target player")
	assert(not pass_velocity_mps.is_zero_approx(), "A pass requires velocity")
	assert(flight_range_m > 0.0, "A pass requires positive flight range")
	assert(apex_height_m >= 0.0, "Pass apex height cannot be negative")
	_owner_player_id = ""
	_target_player_id = target_id
	_velocity_mps = pass_velocity_mps
	_flight_distance_m = 0.0
	_flight_range_m = flight_range_m
	_flight_apex_height_m = apex_height_m
	_flight_start_height_m = 0.0
	_height_m = 0.0
	_flight_kind = FlightKind.PASS
	_motion_state = MotionState.IN_FLIGHT


## Starts a shot at the owned ball's current height with an additional flight arc.
func _launch_shot(
	release_position_m: Vector2,
	shot_velocity_mps: Vector2,
	flight_range_m: float,
	apex_height_m: float,
	start_height_m: float = 0.0,
) -> void:
	assert(shot_velocity_mps.is_finite() and not shot_velocity_mps.is_zero_approx())
	assert(flight_range_m > 0.0, "A shot requires positive flight range")
	assert(apex_height_m > 0.0, "Shot apex height must be positive")
	assert(start_height_m >= 0.0 and is_finite(start_height_m))
	_position_m = release_position_m
	_owner_player_id = ""
	_target_player_id = ""
	_velocity_mps = shot_velocity_mps
	_flight_distance_m = 0.0
	_flight_range_m = flight_range_m
	_flight_apex_height_m = apex_height_m
	_flight_start_height_m = start_height_m
	_height_m = start_height_m
	_flight_kind = FlightKind.SHOT
	_motion_state = MotionState.IN_FLIGHT


## Advances a pass while keeping its parabolic height synchronized with distance.
func _advance_flight(new_position_m: Vector2, traveled_distance_m: float) -> void:
	assert(_motion_state == MotionState.IN_FLIGHT, "Ball must be in flight")
	assert(_flight_kind == FlightKind.PASS, "Pass distance requires a pass trajectory")
	_position_m = new_position_m
	_flight_distance_m += traveled_distance_m
	_height_m = calculate_height_at_distance(_flight_distance_m)


## Advances shot position, speed, and height from the same traveled distance.
func _advance_shot(
	new_position_m: Vector2,
	new_velocity_mps: Vector2,
	traveled_distance_m: float,
) -> void:
	assert(_motion_state == MotionState.IN_FLIGHT and _flight_kind == FlightKind.SHOT)
	assert(traveled_distance_m >= 0.0, "Shot travel cannot be negative")
	_position_m = new_position_m
	_velocity_mps = new_velocity_mps
	_flight_distance_m += traveled_distance_m
	_height_m = calculate_height_at_distance(_flight_distance_m)


## Combines the release height with a reproducible pass or shot parabola.
func calculate_height_at_distance(distance_m: float) -> float:
	if _flight_apex_height_m <= 0.0:
		return 0.0
	var progress := clampf(distance_m / _flight_range_m, 0.0, 1.0)
	return (
		_flight_start_height_m * (1.0 - progress)
		+ 4.0 * _flight_apex_height_m * progress * (1.0 - progress)
	)


## Keeps a scored ball visually in flight while its net response uses ground-plane velocity.
func _set_post_goal_motion(new_position_m: Vector2, new_velocity_mps: Vector2) -> void:
	_position_m = new_position_m
	_velocity_mps = new_velocity_mps
	_owner_player_id = ""
	_target_player_id = ""
	_flight_kind = FlightKind.SHOT
	_motion_state = MotionState.IN_FLIGHT
	_flight_distance_m = 0.0
	_flight_range_m = 0.0
	_flight_apex_height_m = 0.0
	_flight_start_height_m = 0.0
	_height_m = 0.0


## Leaves the ball free and motionless after a trajectory ends.
func _release(new_position_m: Vector2) -> void:
	_position_m = new_position_m
	_owner_player_id = ""
	_motion_state = MotionState.LOOSE
	_clear_flight()


## Removes pass and shot metadata whenever the ball changes ownership or stops.
func _clear_flight() -> void:
	_flight_kind = FlightKind.NONE
	_target_player_id = ""
	_velocity_mps = Vector2.ZERO
	_flight_distance_m = 0.0
	_flight_range_m = 0.0
	_flight_apex_height_m = 0.0
	_flight_start_height_m = 0.0
	_height_m = 0.0
