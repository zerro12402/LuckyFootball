## Predicts observable flight geometry and height from copied facts, never hidden aim or future samples.
class_name AIBallPrediction
extends RefCounted

## Converts copied distance-based height inputs into the exact existing flight arc.
static func height_at(ball: BallStateSnapshot, extra_distance: float) -> float:
	if ball.flight_range_m <= 0.0:
		return ball.height_m
	var progress := clampf((ball.flight_distance_m + extra_distance) / ball.flight_range_m, 0.0, 1.0)
	return maxf(0.0, ball.flight_start_height_m * (1.0 - progress)
		+ 4.0 * ball.flight_apex_height_m * progress * (1.0 - progress))

## Returns time until the ball reaches a point's along-path coordinate, or -1 if moving away/stopped.
static func time_to(ball: BallStateSnapshot, point: Vector2, config: MatchConfigDefinition) -> float:
	var speed := ball.velocity_mps.length()
	if speed <= 0.0:
		return -1.0
	var distance := (point - ball.position_m).dot(ball.velocity_mps / speed)
	if distance < 0.0:
		return -1.0
	if ball.flight_kind != BallMatchState.FlightKind.SHOT:
		return distance / speed
	var deceleration := config.shot_ground_deceleration_mps2
	var discriminant := speed * speed - 2.0 * deceleration * distance
	if discriminant < 0.0:
		return -1.0
	return (speed - sqrt(discriminant)) / deceleration

## Targets a bounded, observable predicted point rather than reading the preselected shot aim.
static func point_at(ball: BallStateSnapshot, seconds: float, config: MatchConfigDefinition) -> Vector2:
	var speed := ball.velocity_mps.length()
	var decay := config.shot_ground_deceleration_mps2 if ball.flight_kind == BallMatchState.FlightKind.SHOT else 0.0
	var distance := maxf(0.0, speed * seconds - 0.5 * decay * seconds * seconds)
	distance = minf(distance, maxf(ball.flight_range_m - ball.flight_distance_m, 0.0))
	return ball.position_m + ball.velocity_mps.normalized() * distance
