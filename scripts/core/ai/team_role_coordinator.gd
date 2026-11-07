## Maintains one eligible field-player pursuer per team with deterministic tie breaks and handoff hysteresis.
class_name TeamRoleCoordinator
extends RefCounted

var _leaders: Dictionary[String, String] = {}
var _assigned_at: Dictionary[String, float] = {}

## Keeps a valid incumbent until a materially earlier eligible teammate can take over.
func select_primary(snapshot: MatchStateSnapshot, team: String, target: Vector2,
		config: AIBehaviorConfig) -> String:
	if TeamTacticalContext.is_defending_keeper_possession(snapshot, team):
		clear_team(team)
		return ""
	var best: PlayerStateSnapshot = null
	var best_time := INF
	for player in snapshot.players:
		if not _can_pursue(player, team):
			continue
		var arrival := player.position_m.distance_to(target) / player.movement_speed_mps
		if arrival < best_time or (is_equal_approx(arrival, best_time) and (best == null or player.player_id < best.player_id)):
			best = player
			best_time = arrival
	var current := snapshot.get_player(_leaders.get(team, ""))
	if current != null and _can_pursue(current, team):
		var current_time := current.position_m.distance_to(target) / current.movement_speed_mps
		if snapshot.elapsed_seconds < _assigned_at.get(team, 0.0) + config.number("handoff_hold_seconds") \
				or best_time + config.number("handoff_advantage_seconds") >= current_time:
			return current.player_id
	var chosen := best.player_id if best != null else ""
	if chosen != _leaders.get(team, ""):
		_assigned_at[team] = snapshot.elapsed_seconds
	_leaders[team] = chosen
	return chosen

## Excludes locked or airborne actors so an actionable field player can take over immediately.
func _can_pursue(player: PlayerStateSnapshot, team: String) -> bool:
	return player.team_id == team and not player.is_goalkeeper \
		and player.action_state == PlayerMatchState.ActionState.IDLE \
		and player.jump_phase == PlayerMatchState.JumpPhase.NONE

## Invalidates obsolete responsibilities without ever mutating player state.
func clear() -> void:
	_leaders.clear()
	_assigned_at.clear()

## Changes one team's strategy without discarding the other team's valid assignment.
func clear_team(team: String) -> void:
	_leaders.erase(team)
	_assigned_at.erase(team)
