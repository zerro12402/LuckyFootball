## Locks the planar goal target chosen once at legal shot release.
class_name ShotAim
extends RefCounted

enum Lane { UPPER, CENTER, LOWER }

var lane: int:
	get: return _lane
var point_m: Vector2:
	get: return _point_m
var _lane: int
var _point_m: Vector2

func _init(new_lane: int, target: Vector2) -> void:
	_lane = new_lane
	_point_m = target
