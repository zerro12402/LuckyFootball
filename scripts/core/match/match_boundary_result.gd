## Describes one fully crossed field boundary before match state is changed.
class_name MatchBoundaryResult
extends RefCounted

enum Outcome {
	GOAL,
	OUT,
}

enum Side {
	NONE,
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
}

var outcome: int:
	get:
		return _outcome

var side: int:
	get:
		return _side

var ball_position_m: Vector2:
	get:
		return _ball_position_m

var is_corner: bool:
	get:
		return _is_corner

var crossing_fraction: float:
	get: return _crossing_fraction

var _crossing_fraction: float

var _outcome: int
var _side: int
var _ball_position_m: Vector2
var _is_corner: bool


func _init(
	new_outcome: int,
	new_side: int,
	new_ball_position_m: Vector2,
	new_is_corner: bool = false,
	new_crossing_fraction: float = 0.0,
) -> void:
	_outcome = new_outcome
	_side = new_side
	_ball_position_m = new_ball_position_m
	_is_corner = new_is_corner
	_crossing_fraction = new_crossing_fraction
