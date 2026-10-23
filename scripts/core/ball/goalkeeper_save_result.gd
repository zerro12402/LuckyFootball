## Records one immutable F04 contact outcome independently of ball motion.
class_name GoalkeeperSaveResult
extends RefCounted

var base_shooting: int:
	get: return _base_shooting
var _base_shooting: int
var goalkeeping: int:
	get: return _goalkeeping
var _goalkeeping: int
var distance_m: float:
	get: return _distance_m
var _distance_m: float
## Actual committed flight, distinct from the reach-independent F04 distance above.
var flight_distance_m: float:
	get: return _flight_distance_m
var _flight_distance_m: float
var knockdown_count: int:
	get: return _knockdown_count
var _knockdown_count: int
var distance_multiplier: float:
	get: return _distance_multiplier
var _distance_multiplier: float
var knockdown_multiplier: float:
	get: return _knockdown_multiplier
var _knockdown_multiplier: float
var effective_shooting: float:
	get: return _effective_shooting
var _effective_shooting: float
var shot_win_probability: float:
	get: return _shot_win_probability
var _shot_win_probability: float
var save_probability: float:
	get: return _save_probability
var _save_probability: float

var keeper_id: String:
	get: return _keeper_id
var shot_sequence: int:
	get: return _shot_sequence
var lane: int:
	get: return _lane
var did_catch: bool:
	get: return _did_catch
var sample: float:
	get: return _sample
var position_m: Vector2:
	get: return _position_m
var height_m: float:
	get: return _height_m
var _keeper_id: String
var _shot_sequence: int
var _lane: int
var _did_catch: bool
var _sample: float
var _position_m: Vector2
var _height_m: float

func _init(id: String, sequence: int, direction: int, caught: bool,
		u: float, point: Vector2, height: float, shooting: int, keeper_skill: int,
		meters: float, flight_meters: float, knocked_down: int, distance_factor: float, knockdown_factor: float,
		effective: float, shot_probability: float, catch_probability: float) -> void:
	_keeper_id = id
	_shot_sequence = sequence
	_lane = direction
	_did_catch = caught
	_sample = u
	_position_m = point
	_height_m = height
	_base_shooting = shooting
	_goalkeeping = keeper_skill
	_distance_m = meters
	_flight_distance_m = flight_meters
	_knockdown_count = knocked_down
	_distance_multiplier = distance_factor
	_knockdown_multiplier = knockdown_factor
	_effective_shooting = effective
	_shot_win_probability = shot_probability
	_save_probability = catch_probability
