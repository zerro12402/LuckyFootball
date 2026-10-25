## Optional read-only stamina adapter; negative means unavailable, never a fabricated full reservoir.
class_name AIStaminaSource
extends RefCounted

func ratio(_snapshot: MatchStateSnapshot, _player_id: String) -> float:
	return -1.0
