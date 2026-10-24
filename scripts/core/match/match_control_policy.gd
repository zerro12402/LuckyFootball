## Pure global gate shared by tactical scheduling and direct simulation submissions.
class_name MatchControlPolicy
extends RefCounted

## Individual actor locks remain the runtime's responsibility after this global permission.
static func can_decide(phase: int, round_phase: int) -> bool:
	return phase == MatchState.Phase.RUNNING and round_phase == MatchState.RoundPhase.PLAYING
