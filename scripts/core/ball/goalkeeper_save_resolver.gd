## Computes F04 from locked shooting, committed flight facts and real keeper skill, after legal contact.
class_name GoalkeeperSaveResolver
extends RefCounted

## Calculates distance decay without clamping the resulting effective attribute to one.
static func distance_multiplier(distance_m: float, config: MatchConfigDefinition) -> float:
	assert(is_finite(distance_m) and distance_m >= 0.0)
	var scaled := maxf(distance_m - config.shot_contest_free_distance_m, 0.0) / config.shot_contest_distance_scale_m
	return 1.0 / (1.0 + scaled * scaled)

## Applies only the committed distinct-defender knockdown count, leaving F08 base values untouched.
static func effective_shooting(shooting: int, distance_m: float, knockdowns: int,
		config: MatchConfigDefinition) -> float:
	assert(shooting >= 1 and shooting <= 100 and knockdowns >= 0)
	return shooting * distance_multiplier(distance_m, config) * pow(config.shot_contest_knockdown_retention, knockdowns)

## Returns the complement of the bounded shooting-win curve, preserving u<p_save as a catch.
static func save_probability(effective: float, keeper_skill: int, config: MatchConfigDefinition) -> float:
	assert(is_finite(effective) and effective >= 0.0)
	assert(keeper_skill >= 1 and keeper_skill <= 100)
	var win := 1.0 / (1.0 + exp(-(effective - keeper_skill) / config.keeper_contest_probability_scale))
	return 1.0 - clampf(win, config.keeper_contest_shot_win_min, config.keeper_contest_shot_win_max)

## Projects to the keeper hand plane, retaining ball radius but excluding the early-contact reach.
static func contest_distance(flight_distance_m: float, point: Vector2,
		keeper_center: Vector2, incoming_direction: Vector2, ball_radius_m: float) -> float:
	assert(flight_distance_m >= 0.0 and incoming_direction.is_normalized() and ball_radius_m >= 0.0)
	var remaining := maxf((keeper_center - point).dot(incoming_direction) - ball_radius_m, 0.0)
	return flight_distance_m + remaining

## Draws exactly once at a verified contact and copies all inputs before possession can clear context.
static func resolve(keeper_id: String, source: BallShotSource, lane: int,
		point: Vector2, height: float, keeper_skill: int, context: ShotFlightContext,
		config: MatchConfigDefinition, sampler: Callable, keeper_center: Vector2,
		incoming_direction: Vector2) -> GoalkeeperSaveResult:
	assert(source != null and context != null and context.source == source and sampler.is_valid())
	var distance := contest_distance(context.distance_m, point, keeper_center, incoming_direction, config.ball_radius_m)
	var distance_factor := distance_multiplier(distance, config)
	var knockdown_factor := pow(config.shot_contest_knockdown_retention, context.knockdown_count)
	var effective := effective_shooting(source.shooting, distance, context.knockdown_count, config)
	var probability := save_probability(effective, keeper_skill, config)
	var sample := float(sampler.call())
	assert(is_finite(sample) and sample >= 0.0 and sample < 1.0)
	return GoalkeeperSaveResult.new(keeper_id, source.sequence, lane,
		sample < probability, sample, point, height, source.shooting, keeper_skill,
		distance, context.distance_m, context.knockdown_count, distance_factor, knockdown_factor,
		effective, 1.0 - probability, probability)
