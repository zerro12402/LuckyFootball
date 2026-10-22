## Records one immutable F04 contact outcome independently of ball motion.
class_name GoalkeeperSaveResult
extends RefCounted

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
		u: float, point: Vector2, height: float) -> void:
	_keeper_id = id
	_shot_sequence = sequence
	_lane = direction
	_did_catch = caught
	_sample = u
	_position_m = point
	_height_m = height
