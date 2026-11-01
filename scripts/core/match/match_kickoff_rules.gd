## Pure kickoff selection and half-field geometry; only MatchSimulation commits its results.
class_name MatchKickoffRules
extends RefCounted

## Uses a dedicated stream so opening-side selection never consumes contest samples.
static func select_team(seed_value: int, home: String, away: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x4b4f4646
	return home if rng.randi() % 2 == 0 else away

## Leaves every nonkicker in its own half and places all defenders strictly outside the center circle.
static func position(spawn: Vector2, attack_direction: float, is_kicker: bool,
		is_defender: bool, field: FieldDefinition, config: MatchConfigDefinition) -> Vector2:
	if is_kicker:
		return Vector2(-attack_direction * BallRuntimeSystem.DEFAULT_DRIBBLE_OFFSET_M, 0)
	var point := spawn
	point.x = -attack_direction * maxf(absf(point.x), config.ball_radius_m)
	if is_defender:
		var radius := field.center_circle_radius_m + config.ball_radius_m + MatchRules.TIME_EPSILON
		if point.length() <= radius:
			point = point.normalized() * radius
	return point
