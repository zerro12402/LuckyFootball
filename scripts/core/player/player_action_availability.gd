## Shares pure action-lock eligibility between runtime transitions and snapshot-driven AI.
class_name PlayerActionAvailability
extends RefCounted

## Checks only personal state; ownership, targets and physical contacts remain simulation rules.
static func allows(kind: int, action: int, jump: int, possession: int,
		tackle_cooldown: float = 0.0, attack_cooldown: float = 0.0) -> bool:
	if action != PlayerMatchState.ActionState.IDLE:
		return false
	var grounded := jump == PlayerMatchState.JumpPhase.NONE
	match kind:
		MatchAction.Type.MOVE:
			return true
		MatchAction.Type.PASS:
			return grounded and possession == PlayerMatchState.PossessionState.POSSESSING
		MatchAction.Type.SHOOT:
			return jump in [PlayerMatchState.JumpPhase.NONE, PlayerMatchState.JumpPhase.AIRBORNE]
		MatchAction.Type.JUMP:
			return grounded
		MatchAction.Type.TACKLE:
			return grounded and possession == PlayerMatchState.PossessionState.NO_BALL and tackle_cooldown <= 0.0
		MatchAction.Type.ATTACK:
			return grounded and attack_cooldown <= 0.0
		MatchAction.Type.SAVE:
			return grounded and possession == PlayerMatchState.PossessionState.NO_BALL
	return false
