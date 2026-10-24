## Replaceable tactical source contract; lifecycle and mutation authority stay with the simulation.
class_name MatchActionSource
extends RefCounted

## Receives the same readonly snapshot as every source called for this fixed step.
func propose_actions(_snapshot: MatchStateSnapshot) -> Array[MatchAction]:
	return []

## Lets future AI discard cached intent on every lifecycle or round control revision.
func invalidate_control(_snapshot: MatchStateSnapshot) -> void:
	pass
