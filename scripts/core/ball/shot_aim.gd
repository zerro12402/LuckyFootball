## Locks the planar goal target chosen once at legal shot release.
class_name ShotAim
extends RefCounted

enum Lane { UPPER, CENTER, LOWER }

var lane: int:
	get: return _lane
var point_m: Vector2:
	get: return _point_m
var is_miss: bool:
	get: return _is_miss
var shooting: int:
	get: return _shooting
var miss_probability: float:
	get: return _miss_probability
var miss_sample: float:
	get: return _miss_sample
var post_side: int:
	get: return _post_side
var miss_margin_m: float:
	get: return _miss_margin_m
var _is_miss: bool
var _shooting: int
var _miss_probability: float
var _miss_sample: float
var _post_side: int
var _miss_margin_m: float
var _lane: int
var _point_m: Vector2

func _init(new_lane: int, target: Vector2, missed: bool = false, base_shooting: int = 0,
		probability: float = 0.0, sample: float = -1.0, side: int = 0, margin: float = 0.0) -> void:
	_lane = new_lane
	_point_m = target
	_is_miss = missed
	_shooting = base_shooting
	_miss_probability = probability
	_miss_sample = sample
	_post_side = side
	_miss_margin_m = margin
