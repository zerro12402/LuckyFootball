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


const V2_BEHAVIORS := {
	"drop_support": AIActionCandidate.Behavior.DROP_SUPPORT,
	"central_support": AIActionCandidate.Behavior.CENTRAL_SUPPORT,
	"back_support": AIActionCandidate.Behavior.BACK_SUPPORT,
	"cover_lane": AIActionCandidate.Behavior.COVER_LANE,
	"mark": AIActionCandidate.Behavior.MARK,
	"protect_goal": AIActionCandidate.Behavior.PROTECT_GOAL,
	"jump": AIActionCandidate.Behavior.JUMP,
	"air_shoot": AIActionCandidate.Behavior.SHOOT,
	"header_shot": AIActionCandidate.Behavior.HEADER_SHOT,
	"header_clear": AIActionCandidate.Behavior.HEADER_CLEAR,
	"attack": AIActionCandidate.Behavior.ATTACK,
	"keeper_position": AIActionCandidate.Behavior.KEEPER_POSITION,
	"keeper_slide": AIActionCandidate.Behavior.RETURN,
	"keeper_save": AIActionCandidate.Behavior.SAVE,
}
const V2_FIELDS := {"self.role": TYPE_STRING, "self.position": TYPE_STRING,
	"self.duty": TYPE_STRING, "ball.relation": TYPE_STRING, "ball.source": TYPE_STRING,
	"ball.last_kicker_id": TYPE_STRING}


## Keeps v1 names stable while adding explicitly versioned choices.
static func behaviors(version: int) -> Dictionary:
	return BEHAVIORS.merged(V2_BEHAVIORS) if version == 2 else BEHAVIORS


## Validates public names and exact-target availability conditions at compile time.
static func field_type(field: String, version: int) -> int:
	if field.begins_with("has.") and behaviors(version).has(field.substr(4)):
		return TYPE_BOOL
	if version == 2:
		if field.begins_with("has_target."):
			var parts := field.split(".", false, 2)
			if parts.size() == 3 and behaviors(version).has(parts[1]) and parts[2].length() <= 64:
				return TYPE_BOOL
		if V2_FIELDS.has(field):
			return V2_FIELDS[field]
	return FIELDS.get(field, TYPE_NIL)


## Looks up a current legal target ID without exposing an action object.
static func has_target(choices: Dictionary, behavior: String, target_id: String) -> bool:
	if not choices.has(behavior):
		return false
	var targets: Array = choices[behavior]["targets"]
	return target_id == "first" or targets.any(func(target: Dictionary) -> bool: return target["id"] == target_id)


## Copies meters, team-relative axes and the current legal choices without exposing simulation references.
static func make_view(snapshot: MatchStateSnapshot, player_id: String,
		goal: Vector2, pressured: bool, legal: Array[AIActionCandidate], version: int = VERSION,
		context: Dictionary = {}) -> Dictionary:
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
	var view := {"version": version, "self": {"id": player_id, "x": actor.position_m.x * sign_x, "y": actor.position_m.y,
		"owns_ball": ball.owner_player_id == player_id, "goal_distance_m": actor.position_m.distance_to(goal),
		"pressured": pressured}, "ball": {"x": ball.position_m.x * sign_x, "y": ball.position_m.y,
		"height_m": ball.height_m, "vx": ball.velocity_mps.x * sign_x, "vy": ball.velocity_mps.y,
		"owner_id": ball.owner_player_id}, "phase": phase, "teammates": teammates, "opponents": opponents,
		"teammate_count": teammates.size(), "opponent_count": opponents.size(),
		"nearest_teammate_m": nearest_teammate if is_finite(nearest_teammate) else -1.0,
		"nearest_opponent_m": nearest_opponent if is_finite(nearest_opponent) else -1.0,
		"candidates": _public_candidates(legal, actor.position_m.x * sign_x, sign_x, version,
			context.get("role", ""), actor.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE)}
	if version == 2:
		var owner := snapshot.get_player(ball.owner_player_id)
		var relation := "none"
		if owner != null:
			relation = "self" if owner.player_id == player_id else ("teammate" if owner.team_id == actor.team_id else "opponent")
		view["self"].merge({"role": context.get("role", ""), "position": context.get("position", ""),
			"duty": context.get("duty", "positioning")})
		view["ball"].merge({"relation": relation, "source": ["none", "pass", "shot", "clearance", "roll"][ball.flight_kind],
			"last_kicker_id": ball.last_kicker_id})
	return view


## A forward run is the existing support route when its destination advances the attack.
static func _public_candidates(legal: Array[AIActionCandidate], actor_x: float, sign_x: float,
		version: int, role: String, airborne: bool) -> Dictionary:
	var candidates := {}
	var names := behaviors(version)
	for id in names:
		if version == 2 and not _visible_for_role(id, role, airborne):
			continue
		for candidate in legal:
			if candidate.behavior != names[id]:
				continue
			var targets: Array[Dictionary] = []
			for option in candidate.targets:
				var point := option.destination_m
				if id == "run_forward" and (not point.is_finite() or point.x * sign_x <= actor_x):
					continue
				var target := {"id": _target_id(id, option), "weight": option.weight}
				if point.is_finite():
					target["x"] = point.x * sign_x
					target["y"] = point.y
				targets.append(target)
			if not targets.is_empty():
				candidates[id] = {"weight": candidate.weight, "targets": targets}
			break
	return candidates


## Adds descriptive aliases only for relevant roles and keeps the keeper whitelist closed.
static func _visible_for_role(id: String, role: String, airborne: bool) -> bool:
	if role == "keeper":
		return id in ["hold", "pass", "keeper_position", "keeper_slide", "keeper_save"]
	match id:
		"drop_support", "central_support", "cover_lane": return role == "mid" or (id == "cover_lane" and role == "back")
		"back_support", "protect_goal", "mark": return role == "back"
		"air_shoot": return airborne
		"shoot": return not airborne
		"keeper_position", "keeper_slide", "keeper_save": return false
	return true


## Save lanes are stable public targets; normal movement still has a single host-generated point.
static func _target_id(behavior: String, option: AITargetOption) -> String:
	if behavior == "keeper_save":
		return ["upper", "center", "lower"][int(option.action.direction.y) + 1]
	return option.action.target_player_id


## Resolves a direct selection using only a target advertised in the current decision.
static func select(legal: Array[AIActionCandidate], public_choices: Dictionary,
		behavior: String, target_id: String, version: int = VERSION) -> AITargetOption:
	if not public_choices.has(behavior):
		return null
	var allowed_targets: Array = public_choices[behavior]["targets"]
	var resolved_id := String(allowed_targets[0]["id"]) if target_id == "first" else target_id
	if not allowed_targets.any(func(target: Dictionary) -> bool: return target["id"] == resolved_id):
		return null
	for candidate in legal:
		if candidate.behavior == behaviors(version)[behavior]:
			for option in candidate.targets:
				if _target_id(behavior, option) == resolved_id:
					return option
	return null