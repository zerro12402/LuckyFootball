## Orders continuous player, goalkeeper and whole-ball boundary contacts by physical time.
class_name BallContactResolver
extends RefCounted

const EPSILON := 0.00000001

## Finds each body's earliest legal contact and merges the first boundary crossing.
static func find_candidates(trajectory: BallShotTrajectory, players: Array[BallContactPlayer],
		config: MatchConfigDefinition, rules: MatchRules = null,
		latched_ids: Dictionary[String, bool] = {}) -> Array[BallContactCandidate]:
	var candidates: Array[BallContactCandidate] = []
	if trajectory.duration_seconds <= 0.0:
		return candidates
	for player in players:
		var time := _first_body_contact(trajectory, player, config, latched_ids.has(player.player_id))
		if time < 0.0:
			continue
		var contact := BallContactCandidate.new()
		contact.player_id = player.player_id
		contact.kind = (BallContactCandidate.Kind.GOALKEEPER if player.is_goalkeeper
			else BallContactCandidate.Kind.PLAYER)
		contact.time_seconds = time
		contact.position_m = trajectory.position_at(time)
		contact.height_m = maxf(ContactPolynomial.evaluate(trajectory.height_coefficients, time), 0.0)
		var center := player.start_position_m.lerp(player.end_position_m,
			time / trajectory.duration_seconds)
		contact.player_position_m = center
		contact.normal = (contact.position_m - center).normalized()
		if contact.normal.is_zero_approx():
			contact.normal = -trajectory.direction
		candidates.append(contact)
	if rules != null:
		var end := trajectory.position_at(trajectory.duration_seconds)
		var boundary := rules.resolve_ball_boundary(trajectory.start_position_m, end)
		if boundary != null:
			var contact := BallContactCandidate.new()
			contact.kind = BallContactCandidate.Kind.BOUNDARY
			contact.boundary = boundary
			contact.time_seconds = trajectory.time_at_distance(
				trajectory.start_position_m.distance_to(end) * boundary.crossing_fraction)
			contact.position_m = trajectory.position_at(contact.time_seconds)
			contact.height_m = maxf(ContactPolynomial.evaluate(
				trajectory.height_coefficients, contact.time_seconds), 0.0)
			candidates.append(contact)
	candidates.sort_custom(_comes_before)
	return candidates

## Uses a total order: exact time, boundary/keeper/player priority, then stable player ID.
static func _comes_before(left: BallContactCandidate, right: BallContactCandidate) -> bool:
	var left_tick := roundi(left.time_seconds / EPSILON)
	var right_tick := roundi(right.time_seconds / EPSILON)
	if left_tick != right_tick:
		return left_tick < right_tick
	if left.kind != right.kind:
		return left.kind < right.kind
	return left.player_id < right.player_id

## Intersects planar quartic and height intervals, allowing reentry only after full separation.
static func _first_body_contact(trajectory: BallShotTrajectory, player: BallContactPlayer,
		config: MatchConfigDefinition, is_latched: bool) -> float:
	var duration := trajectory.duration_seconds
	var offset := trajectory.start_position_m - player.start_position_m
	var relative_velocity := trajectory.direction * trajectory.speed_mps - (
		player.end_position_m - player.start_position_m) / duration
	var acceleration := -trajectory.direction * trajectory.deceleration_mps2 * 0.5
	var x: Array[float] = [offset.x, relative_velocity.x, acceleration.x]
	var y: Array[float] = [offset.y, relative_velocity.y, acceleration.y]
	var planar := ContactPolynomial.multiply(x, x)
	var yy := ContactPolynomial.multiply(y, y)
	for index in range(planar.size()):
		planar[index] += yy[index]
	var radius := player.radius_m if player.radius_m > 0.0 else config.ball_impact_body_radius_m
	planar[0] -= pow(radius + config.ball_radius_m, 2.0)
	var lower: Array[float] = trajectory.height_coefficients.duplicate()
	lower[0] -= player.start_height_m - config.ball_radius_m
	lower[1] -= (player.end_height_m - player.start_height_m) / duration
	var upper: Array[float] = lower.duplicate()
	var body_height := (player.body_height_m if player.body_height_m > 0.0
		else config.ball_impact_body_height_m)
	upper[0] -= body_height + 2.0 * config.ball_radius_m
	var points: Array[float] = [0.0, duration, clampf(player.earliest_seconds, 0.0, duration),
		clampf(player.latest_seconds, 0.0, duration)]
	for polynomial in [planar, lower, upper]:
		points.append_array(ContactPolynomial.roots(polynomial, 0.0, duration))
	points.sort()
	var has_separated := not is_latched
	for index in range(points.size()):
		var point := points[index]
		if (point >= player.earliest_seconds - EPSILON
			and point <= player.latest_seconds + EPSILON and _inside(planar, lower, upper, point)):
			if has_separated:
				return point
		else:
			has_separated = true
		if index + 1 < points.size() and points[index + 1] - point > EPSILON:
			var midpoint := (point + points[index + 1]) * 0.5
			if (midpoint >= player.earliest_seconds and midpoint <= player.latest_seconds
				and _inside(planar, lower, upper, midpoint)):
				if has_separated:
					return point
			else:
				has_separated = true
	return -1.0

## Evaluates the intersection of a swept cylinder and the football's height.
static func _inside(planar: Array[float], lower: Array[float], upper: Array[float],
		time: float) -> bool:
	return (ContactPolynomial.evaluate(planar, time) <= EPSILON
		and ContactPolynomial.evaluate(lower, time) >= -EPSILON
		and ContactPolynomial.evaluate(upper, time) <= EPSILON)
