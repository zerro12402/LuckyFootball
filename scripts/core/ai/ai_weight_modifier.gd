## Neutral extension point; traits may modify weights but cannot add targets or restore eligibility.
class_name AIWeightModifier
extends RefCounted

func multiplier(_snapshot: MatchStateSnapshot, _player_id: String, _behavior: int) -> float:
	return 1.0
