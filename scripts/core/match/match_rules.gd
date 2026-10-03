## Resolves the first complete-ball boundary crossing from a meter-space motion segment.
class_name MatchRules
extends RefCounted

const LINE_EPSILON_M := 0.00001
const TIME_EPSILON := 0.00000001
const EDGE_ORDER: Array[int] = [
	MatchBoundaryResult.Side.TOP,
	MatchBoundaryResult.Side.BOTTOM,
	MatchBoundaryResult.Side.LEFT,
	MatchBoundaryResult.Side.RIGHT,
]

var _half_length_m: float
var _half_width_m: float
var _half_goal_width_m: float
var _ball_radius_m: float


## Keeps every boundary dimension in the validated field and ball configuration.
func _init(field: FieldDefinition, ball_radius_m: float) -> void:
	assert(field != null, "Boundary rules require a field")
	assert(ball_radius_m > 0.0, "Ball radius must be positive")
	assert(ball_radius_m < field.goal_width_m * 0.5, "Ball must fit through the goal")
	_half_length_m = field.length_m * 0.5
	_half_width_m = field.width_m * 0.5
	_half_goal_width_m = field.goal_width_m * 0.5
	_ball_radius_m = ball_radius_m


## Chooses the first whole-ball crossing, scoring only for released balls when allowed.
func resolve_ball_boundary(
	previous_position_m: Vector2,
	next_position_m: Vector2,
	allow_goal: bool = true,
) -> MatchBoundaryResult:
	if not previous_position_m.is_finite() or not next_position_m.is_finite():
		return null
	var best_side := MatchBoundaryResult.Side.NONE
	var best_fraction := INF
	var is_corner := false
	for side in EDGE_ORDER:
		var fraction := _get_full_crossing_fraction(
			side, previous_position_m, next_position_m
		)
		if fraction == INF:
			continue
		if fraction < best_fraction - TIME_EPSILON:
			best_fraction = fraction
			best_side = side
			is_corner = false
		elif absf(fraction - best_fraction) <= TIME_EPSILON:
			is_corner = true
	if best_side == MatchBoundaryResult.Side.NONE:
		return null
	var crossing_position_m := previous_position_m.lerp(next_position_m, best_fraction)
	if best_side == MatchBoundaryResult.Side.LEFT or best_side == MatchBoundaryResult.Side.RIGHT:
		var goal_line_x := -_half_length_m
		if best_side == MatchBoundaryResult.Side.RIGHT:
			goal_line_x = _half_length_m
		var goal_line_fraction := (
			(goal_line_x - previous_position_m.x)
			/ (next_position_m.x - previous_position_m.x)
		)
		var crossing_y := lerpf(
			previous_position_m.y, next_position_m.y, goal_line_fraction
		)
		crossing_position_m = Vector2(goal_line_x, crossing_y)
		if allow_goal and not is_corner and absf(crossing_y) + _ball_radius_m < (
			_half_goal_width_m - LINE_EPSILON_M
		):
			return MatchBoundaryResult.new(
				MatchBoundaryResult.Outcome.GOAL,
				best_side,
				crossing_position_m,
			)
	return MatchBoundaryResult.new(
		MatchBoundaryResult.Outcome.OUT,
		best_side,
		crossing_position_m,
		is_corner,
	)


## Finds when the entire ball first clears one line, with a fixed tolerance.
func _get_full_crossing_fraction(
	side: int,
	previous_position_m: Vector2,
	next_position_m: Vector2,
) -> float:
	var previous_axis := 0.0
	var next_axis := 0.0
	var outer_boundary := 0.0
	if side == MatchBoundaryResult.Side.TOP:
		previous_axis = -previous_position_m.y
		next_axis = -next_position_m.y
		outer_boundary = _half_width_m + _ball_radius_m
	elif side == MatchBoundaryResult.Side.BOTTOM:
		previous_axis = previous_position_m.y
		next_axis = next_position_m.y
		outer_boundary = _half_width_m + _ball_radius_m
	elif side == MatchBoundaryResult.Side.LEFT:
		previous_axis = -previous_position_m.x
		next_axis = -next_position_m.x
		outer_boundary = _half_length_m + _ball_radius_m
	else:
		previous_axis = previous_position_m.x
		next_axis = next_position_m.x
		outer_boundary = _half_length_m + _ball_radius_m
	if (
		previous_axis > outer_boundary + LINE_EPSILON_M
		or next_axis <= outer_boundary + LINE_EPSILON_M
	):
		return INF
	var traveled_axis := next_axis - previous_axis
	if traveled_axis <= 0.0:
		return INF
	return clampf((outer_boundary - previous_axis) / traveled_axis, 0.0, 1.0)
