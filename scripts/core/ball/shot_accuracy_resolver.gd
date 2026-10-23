## Computes F11 accuracy and planar targets from explicit inputs; never samples or writes match state.
class_name ShotAccuracyResolver
extends RefCounted

## Uses only the locked base shooting attribute; fatigue and keeper data are deliberately absent.
static func calculate_miss_probability(shooting: int, config: MatchConfigDefinition) -> float:
	assert(shooting >= 1 and shooting <= 100)
	return lerpf(config.shot_miss_probability_at_1, config.shot_miss_probability_at_100,
		float(shooting - 1) / 99.0)

## Locks an immutable target; misses remain outside the whole ball radius, never clamped inside.
static func create_aim(shooting: int, config: MatchConfigDefinition, goal: Vector2,
		width: float, missed: bool, sample: float, lane: int, side: int = 0,
		margin_m: float = 0.0) -> ShotAim:
	var probability := calculate_miss_probability(shooting, config)
	var offset: float
	if missed:
		assert(side == -1 or side == 1)
		assert(margin_m >= config.shot_miss_margin_min_m and margin_m <= config.shot_miss_margin_max_m)
		offset = float(side) * (width * 0.5 + config.ball_radius_m + margin_m)
		lane = ShotAim.Lane.UPPER if side < 0 else ShotAim.Lane.LOWER
	else:
		assert(lane >= ShotAim.Lane.UPPER and lane <= ShotAim.Lane.LOWER)
		var inset := minf(width * config.shot_aim_width_fraction,
			maxf(width * 0.5 - config.ball_radius_m - MatchRules.LINE_EPSILON_M, 0.0))
		offset = float(lane - ShotAim.Lane.CENTER) * inset
	return ShotAim.new(lane, goal + Vector2(0, offset), missed, shooting,
		probability, sample, side, margin_m)
