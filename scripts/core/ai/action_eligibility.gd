## Filters AI intents using copied runtime facts; simulation still revalidates every submission.
class_name ActionEligibility
extends RefCounted

## Never samples randomness, calls runtime mutators, or permits test-only lifecycle commands.
static func allows(snapshot: MatchStateSnapshot, intent: MatchAction,
		config: MatchConfigDefinition) -> bool:
	if snapshot == null or not snapshot.can_decide_player_actions or intent == null:
		return false
	var actor := snapshot.get_player(intent.player_id)
	if actor == null or snapshot.ball == null or not intent.direction.is_finite():
		return false
	if snapshot.kickoff_pending and (intent.player_id != snapshot.kickoff_player_id
		or intent.action_type not in [MatchAction.Type.MOVE, MatchAction.Type.PASS, MatchAction.Type.SHOOT]):
		return false
	if not PlayerActionAvailability.allows(intent.action_type, actor.action_state,
			actor.jump_phase, actor.possession_state,
			actor.tackle_cooldown_seconds, actor.attack_cooldown_seconds):
		return false
	var ball := snapshot.ball
	var owns := ball.owner_player_id == actor.player_id
	var target := snapshot.get_player(intent.target_player_id)
	match intent.action_type:
		MatchAction.Type.MOVE:
			return true
		MatchAction.Type.PASS:
			return owns and target != null and target.player_id != actor.player_id \
				and target.team_id == actor.team_id and target.action_state == PlayerMatchState.ActionState.IDLE \
				and target.jump_phase == PlayerMatchState.JumpPhase.NONE \
				and ball.position_m.distance_to(target.position_m) >= BallRuntimeSystem.MIN_PASS_DISTANCE_M \
				and ball.position_m.distance_to(target.position_m) <= BallRuntimeSystem.DEFAULT_MAX_PASS_DISTANCE_M \
				and (ball.control_attachment == BallMatchState.ControlAttachment.FOOT or actor.is_goalkeeper)
		MatchAction.Type.SHOOT:
			return not actor.is_goalkeeper and owns and actor.shooting_attribute > 0 \
				and is_finite(intent.power) and intent.power > 0.0 and intent.power <= 1.0
		MatchAction.Type.JUMP:
			return not actor.is_goalkeeper and (owns or (ball.flight_kind == BallMatchState.FlightKind.PASS \
				and ball.target_player_id == actor.player_id and ball.flight_apex_height_m > BallRuntimeSystem.MAX_RECEIVE_HEIGHT_M))
		MatchAction.Type.TACKLE, MatchAction.Type.ATTACK:
			if actor.is_goalkeeper or target == null or target.team_id == actor.team_id:
				return false
			if target.action_state in [PlayerMatchState.ActionState.KNOCKED_DOWN, PlayerMatchState.ActionState.GETTING_UP]:
				return false
			var range_m := config.tackle_start_range_m if intent.action_type == MatchAction.Type.TACKLE else config.knockdown_lunge_distance_m
			if actor.position_m.distance_to(target.position_m) > range_m:
				return false
			return intent.action_type == MatchAction.Type.ATTACK or ball.owner_player_id == target.player_id
		MatchAction.Type.HEADER_SHOT, MatchAction.Type.HEADER_CLEAR:
			return not actor.is_goalkeeper and not owns and ball.flight_kind == BallMatchState.FlightKind.PASS \
				and ball.flight_apex_height_m > 0.0 and (intent.action_type != MatchAction.Type.HEADER_CLEAR or not intent.direction.is_zero_approx())
		MatchAction.Type.SAVE:
			return actor.is_goalkeeper and not owns and ball.flight_kind == BallMatchState.FlightKind.SHOT
	return false
