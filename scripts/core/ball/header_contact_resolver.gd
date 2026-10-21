## Sweeps high pass and player paths to find legal contacts in stable time order.
class_name HeaderContactResolver
extends RefCounted

const EPSILON := 0.000001


## Finds first contact for each player without using low-pass possession rules.
static func find_candidates(
	ball: BallMatchState,
	ball_end_position_m: Vector2,
	players: Array[HeaderPlayerTrajectory],
	contact_radius_m: float,
	min_contact_height_m: float,
	reach_height_m: float,
) -> Array[HeaderContactCandidate]:
	var candidates: Array[HeaderContactCandidate] = []
	if ball == null or ball.motion_state != BallMatchState.MotionState.IN_FLIGHT:
		return candidates
	if ball.flight_kind != BallMatchState.FlightKind.PASS or ball.flight_range_m <= 0.0:
		return candidates
	assert(contact_radius_m > 0.0 and min_contact_height_m > 0.2)
	assert(reach_height_m > min_contact_height_m)
	var ball_start := ball.position_m
	var ball_delta := ball_end_position_m - ball_start
	for player in players:
		if not player.is_eligible:
			continue
		var fraction := _find_first_contact_fraction(
			ball, ball_delta, player, contact_radius_m,
			min_contact_height_m, reach_height_m,
		)
		if fraction < 0.0:
			continue
		var distance_m := ball.flight_distance_m + ball_delta.length() * fraction
		candidates.append(HeaderContactCandidate.new(
			player.player_id, player.team_id, fraction,
			ball_start + ball_delta * fraction,
			ball.calculate_height_at_distance(distance_m),
			player.strength, player.technique,
		))
	candidates.sort_custom(_comes_before)
	return candidates


## Intersects relative planar motion, then clips the interval by both height rules.
static func _find_first_contact_fraction(
	ball: BallMatchState,
	ball_delta: Vector2,
	player: HeaderPlayerTrajectory,
	radius_m: float,
	min_height_m: float,
	reach_height_m: float,
) -> float:
	var relative_start := ball.position_m - player.start_position_m
	var relative_delta := ball_delta - (
		player.end_position_m - player.start_position_m
	)
	var planar_interval := _get_planar_interval(relative_start, relative_delta, radius_m)
	if planar_interval.x < 0.0:
		return -1.0
	var entry := planar_interval.x
	var exit_fraction := planar_interval.y
	var p0 := ball.flight_distance_m / ball.flight_range_m
	var dp := ball_delta.length() / ball.flight_range_m
	var apex := ball.calculate_height_at_distance(ball.flight_range_m * 0.5)
	var height_a := -4.0 * apex * dp * dp
	var height_b := 4.0 * apex * dp * (1.0 - 2.0 * p0)
	var height_c := 4.0 * apex * p0 * (1.0 - p0)
	var checkpoints: Array[float] = [entry, exit_fraction]
	_append_roots(checkpoints, height_a, height_b, height_c - min_height_m,
		entry, exit_fraction)
	_append_roots(checkpoints, -height_a,
		player.end_height_m - player.start_height_m - height_b,
		player.start_height_m + reach_height_m - height_c,
		entry, exit_fraction)
	checkpoints.sort()
	for index in range(checkpoints.size()):
		var point := checkpoints[index]
		var point_height := height_a * point * point + height_b * point + height_c
		var player_point_height := lerpf(player.start_height_m, player.end_height_m, point)
		if point_height >= min_height_m - EPSILON and point_height <= player_point_height + reach_height_m + EPSILON:
			return point
		if index + 1 >= checkpoints.size():
			continue
		var right := checkpoints[index + 1]
		var midpoint := (point + right) * 0.5
		var height := height_a * midpoint * midpoint + height_b * midpoint + height_c
		var player_height := lerpf(player.start_height_m, player.end_height_m, midpoint)
		if height >= min_height_m - EPSILON and height <= player_height + reach_height_m + EPSILON:
			return point
	return -1.0


## Solves the swept circle crossing, including a player already within radius.
static func _get_planar_interval(start: Vector2, delta: Vector2, radius_m: float) -> Vector2:
	var a := delta.length_squared()
	var c := start.length_squared() - radius_m * radius_m
	if a <= EPSILON:
		return Vector2(0.0, 1.0) if c <= 0.0 else Vector2(-1.0, -1.0)
	var b := 2.0 * start.dot(delta)
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return Vector2(-1.0, -1.0)
	var root := sqrt(maxf(discriminant, 0.0))
	var entry := maxf(0.0, (-b - root) / (2.0 * a))
	var exit_fraction := minf(1.0, (-b + root) / (2.0 * a))
	return Vector2(entry, exit_fraction) if entry <= exit_fraction else Vector2(-1.0, -1.0)


## Adds exact threshold crossings so a narrow valid height window is not skipped.
static func _append_roots(
	checkpoints: Array[float], a: float, b: float, c: float,
	entry: float, exit_fraction: float,
) -> void:
	if absf(a) <= EPSILON:
		if absf(b) > EPSILON:
			_append_root(checkpoints, -c / b, entry, exit_fraction)
		return
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return
	var root := sqrt(maxf(discriminant, 0.0))
	_append_root(checkpoints, (-b - root) / (2.0 * a), entry, exit_fraction)
	_append_root(checkpoints, (-b + root) / (2.0 * a), entry, exit_fraction)


## Keeps only roots strictly inside the traversed planar contact interval.
static func _append_root(checkpoints: Array[float], root: float,
	entry: float, exit_fraction: float) -> void:
	if root > entry + EPSILON and root < exit_fraction - EPSILON:
		checkpoints.append(root)


## Makes equal-time contacts reproducible independently of registration order.
static func _comes_before(a: HeaderContactCandidate, b: HeaderContactCandidate) -> bool:
	if a.contact_fraction != b.contact_fraction:
		return a.contact_fraction < b.contact_fraction
	return a.player_id < b.player_id
