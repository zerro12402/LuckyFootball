## Maps legal internal candidates to versioned values and resolves public identifiers back to them.
class_name ScriptedAIContract
extends RefCounted

const VERSION := 1
const BEHAVIORS := {
	"hold": AIActionCandidate.Behavior.HOLD,
	"dribble": AIActionCandidate.Behavior.ADVANCE,
	"pass": AIActionCandidate.Behavior.PASS,
	"shoot": AIActionCandidate.Behavior.SHOOT,
	"support": AIActionCandidate.Behavior.SUPPORT,
	"run_forward": AIActionCandidate.Behavior.SUPPORT,
	"press": AIActionCandidate.Behavior.PRESS,
	"tackle": AIActionCandidate.Behavior.TACKLE,
	"chase": AIActionCandidate.Behavior.CHASE,
	"return": AIActionCandidate.Behavior.RETURN,
}
const FIELDS := {
	"self.id": TYPE_STRING, "self.x": TYPE_FLOAT, "self.y": TYPE_FLOAT, "self.owns_ball": TYPE_BOOL,
	"self.goal_distance_m": TYPE_FLOAT, "self.pressured": TYPE_BOOL,
	"ball.x": TYPE_FLOAT, "ball.y": TYPE_FLOAT, "ball.height_m": TYPE_FLOAT,
	"ball.vx": TYPE_FLOAT, "ball.vy": TYPE_FLOAT, "ball.owner_id": TYPE_STRING,
	"phase": TYPE_STRING, "teammate_count": TYPE_INT, "opponent_count": TYPE_INT,
	"nearest_teammate_m": TYPE_FLOAT, "nearest_opponent_m": TYPE_FLOAT,
}


## Copies meters, team-relative axes and the current legal choices without exposing simulation references.
static func make_view(snapshot: MatchStateSnapshot, player_id: String,
		goal: Vector2, pressured: bool, legal: Array[AIActionCandidate]) -> Dictionary:
	var actor := snapshot.get_player(player_id)
	var sign_x := signf(goal.x)
	var teammates: Array[Dictionary] = []
	var opponents: Array[Dictionary] = []
	var nearest_teammate := INF
	var nearest_opponent := INF
	for player in snapshot.players:
		if player.player_id == player_id:
			continue
		var info := {"id": player.player_id, "x": player.position_m.x * sign_x, "y": player.position_m.y}
		var distance := player.position_m.distance_to(actor.position_m)
		if player.team_id == actor.team_id:
			teammates.append(info)
			nearest_teammate = minf(nearest_teammate, distance)
		else:
			opponents.append(info)
			nearest_opponent = minf(nearest_opponent, distance)
	var ball := snapshot.ball
	var phase: String = ["attack", "defend", "loose"][TeamTacticalContext.phase_for(snapshot, actor.team_id)]
	return {"version": VERSION, "self": {"id": player_id, "x": actor.position_m.x * sign_x, "y": actor.position_m.y,
		"owns_ball": ball.owner_player_id == player_id, "goal_distance_m": actor.position_m.distance_to(goal),
		"pressured": pressured}, "ball": {"x": ball.position_m.x * sign_x, "y": ball.position_m.y,
		"height_m": ball.height_m, "vx": ball.velocity_mps.x * sign_x, "vy": ball.velocity_mps.y,
		"owner_id": ball.owner_player_id}, "phase": phase, "teammates": teammates, "opponents": opponents,
		"teammate_count": teammates.size(), "opponent_count": opponents.size(),
		"nearest_teammate_m": nearest_teammate if is_finite(nearest_teammate) else -1.0,
		"nearest_opponent_m": nearest_opponent if is_finite(nearest_opponent) else -1.0,
		"candidates": _public_candidates(legal, actor.position_m.x * sign_x, sign_x)}


## A forward run is the existing support route when its destination advances the attack.
static func _public_candidates(legal: Array[AIActionCandidate], actor_x: float, sign_x: float) -> Dictionary:
	var candidates := {}
	for id in BEHAVIORS:
		for candidate in legal:
			if candidate.behavior != BEHAVIORS[id]:
				continue
			var targets: Array[Dictionary] = []
			for option in candidate.targets:
				var point := option.destination_m
				if id == "run_forward" and (not point.is_finite() or point.x * sign_x <= actor_x):
					continue
				var target := {"id": option.action.target_player_id, "weight": option.weight}
				if point.is_finite():
					target["x"] = point.x * sign_x
					target["y"] = point.y
				targets.append(target)
			if not targets.is_empty():
				candidates[id] = {"weight": candidate.weight, "targets": targets}
			break
	return candidates


## Resolves a direct selection using only a target advertised in the current decision.
static func select(legal: Array[AIActionCandidate], public_choices: Dictionary,
		behavior: String, target_id: String) -> AITargetOption:
	if not public_choices.has(behavior):
		return null
	var allowed_targets: Array = public_choices[behavior]["targets"]
	var resolved_id := String(allowed_targets[0]["id"]) if target_id == "first" else target_id
	if not allowed_targets.any(func(target: Dictionary) -> bool: return target["id"] == resolved_id):
		return null
	for candidate in legal:
		if candidate.behavior == BEHAVIORS[behavior]:
			for option in candidate.targets:
				if option.action.target_player_id == resolved_id:
					return option
	return null