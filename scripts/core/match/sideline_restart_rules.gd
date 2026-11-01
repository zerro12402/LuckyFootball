## Resolves sideline restart ownership, boundary geometry and a deterministic nonkeeper taker without mutation.
class_name SidelineRestartRules
extends RefCounted

## An unknown artificial touch falls back to exchanging the previous restart team without drawing randomness.
static func restart_team(last_touch_team: String, home: String, away: String, previous: String) -> String:
	if last_touch_team == home:
		return away
	if last_touch_team == away:
		return home
	return away if previous == home else home

## Projects the locked complete-ball crossing onto the touchline, keeping corner restarts inside the end line.
static func ball_position(crossing: Vector2, side: int, field: FieldDefinition, radius: float) -> Vector2:
	return Vector2(clampf(crossing.x, -field.length_m * 0.5 + radius, field.length_m * 0.5 - radius),
		-field.width_m * 0.5 if side == MatchBoundaryResult.Side.TOP else field.width_m * 0.5)

## Returns the closest outfield teammate, using stable IDs to settle equal distances.
static func select_taker(players: Array[PlayerStateSnapshot], team: String, point: Vector2) -> String:
	var best_id := ""
	var best_distance := INF
	for player in players:
		if player.team_id != team or player.is_goalkeeper:
			continue
		var distance := player.position_m.distance_squared_to(point)
		if distance < best_distance - MatchRules.TIME_EPSILON or (
				absf(distance - best_distance) <= MatchRules.TIME_EPSILON
				and (best_id.is_empty() or player.player_id < best_id)):
			best_distance = distance
			best_id = player.player_id
	return best_id
