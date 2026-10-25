## Derives tactics from final ownership and committed flight/contact facts, independent of trajectory type.
class_name TeamTacticalContext
extends RefCounted

enum Phase { ATTACK, DEFEND, LOOSE }

## Uncontrolled untouched passes/shots retain the releasing team's tactics; defensive contact makes both loose.
static func phase_for(snapshot: MatchStateSnapshot, team: String) -> int:
	if snapshot.ball == null:
		return Phase.LOOSE
	var ball := snapshot.ball
	var owner := snapshot.get_player(ball.owner_player_id)
	if owner != null:
		return Phase.ATTACK if owner.team_id == team else Phase.DEFEND
	if ball.motion_state == BallMatchState.MotionState.IN_FLIGHT and not ball.defensive_touched:
		var kicker := snapshot.get_player(ball.last_kicker_id)
		if kicker != null and ball.flight_kind in [BallMatchState.FlightKind.PASS, BallMatchState.FlightKind.SHOT]:
			return Phase.ATTACK if kicker.team_id == team else Phase.DEFEND
	return Phase.LOOSE
