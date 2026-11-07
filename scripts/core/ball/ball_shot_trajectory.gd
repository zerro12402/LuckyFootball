## Predicts a shot, pass or clearance segment without changing the live ball.
class_name BallShotTrajectory
extends RefCounted

const DEFAULT_GROUND_DECELERATION_MPS2 := 12.0
const DEFAULT_STOP_SPEED_MPS := 0.5

var start_position_m: Vector2
var direction: Vector2
var speed_mps: float
var deceleration_mps2: float
var duration_seconds: float
var height_coefficients: Array[float]

## Captures a bounded motion interval and the exact distance-based height polynomial.
func _init(ball: BallMatchState, seconds: float, config: MatchConfigDefinition) -> void:
	start_position_m = ball.position_m
	speed_mps = ball.velocity_mps.length()
	direction = ball.velocity_mps.normalized()
	deceleration_mps2 = 0.0
	if ball.flight_kind in [BallMatchState.FlightKind.SHOT, BallMatchState.FlightKind.ROLL]:
		deceleration_mps2 = ground_deceleration(config)
		duration_seconds = minf(seconds, maxf(
			(speed_mps - stop_speed(config)) / deceleration_mps2, 0.0))
		if ball.flight_kind == BallMatchState.FlightKind.ROLL:
			height_coefficients = [0.0, 0.0, 0.0, 0.0, 0.0]
			return
	else:
		duration_seconds = minf(seconds, maxf(
			(ball.flight_range_m - ball.flight_distance_m) / speed_mps, 0.0))
	if ball.flight_kind == BallMatchState.FlightKind.SHOT:
		if ball.flight_distance_m >= ball.flight_range_m - ContactPolynomial.EPSILON:
			height_coefficients = [0.0, 0.0, 0.0, 0.0, 0.0]
			return
		duration_seconds = minf(duration_seconds,
			time_at_distance(ball.flight_range_m - ball.flight_distance_m))
	var progress: Array[float] = [ball.flight_distance_m / ball.flight_range_m,
		speed_mps / ball.flight_range_m, -0.5 * deceleration_mps2 / ball.flight_range_m]
	var squared := ContactPolynomial.multiply(progress, progress)
	height_coefficients = []
	height_coefficients.resize(5)
	height_coefficients.fill(0.0)
	height_coefficients[0] = ball.flight_start_height_m
	for index in range(progress.size()):
		height_coefficients[index] += progress[index] * (
			4.0 * ball.flight_apex_height_m - ball.flight_start_height_m)
	for index in range(squared.size()):
		height_coefficients[index] -= 4.0 * ball.flight_apex_height_m * squared[index]

## Shares the production ground friction with configuration-free simulation fixtures.
static func ground_deceleration(config: MatchConfigDefinition) -> float:
	return config.shot_ground_deceleration_mps2 if config != null else DEFAULT_GROUND_DECELERATION_MPS2


## Keeps the same stopping rule for shots and pass rollouts.
static func stop_speed(config: MatchConfigDefinition) -> float:
	return config.shot_stop_speed_mps if config != null else DEFAULT_STOP_SPEED_MPS


## Converts elapsed seconds into the shot's traveled distance.
func distance_at(seconds: float) -> float:
	return speed_mps * seconds - 0.5 * deceleration_mps2 * seconds * seconds

## Projects traveled distance along the segment's fixed direction.
func position_at(seconds: float) -> Vector2:
	return start_position_m + direction * distance_at(seconds)

## Converts a swept planar distance to the same physical time used for player contacts.
func time_at_distance(distance_m: float) -> float:
	if is_zero_approx(deceleration_mps2):
		return distance_m / speed_mps
	return (speed_mps - sqrt(maxf(
		speed_mps * speed_mps - 2.0 * deceleration_mps2 * distance_m, 0.0
	))) / deceleration_mps2
