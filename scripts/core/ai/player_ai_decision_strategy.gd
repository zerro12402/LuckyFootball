## Receives only detached public decision data and returns a proposed policy result.
class_name PlayerAIDecisionStrategy
extends RefCounted


func interface_version() -> int:
	return 1


func decide(_view: Dictionary) -> Dictionary:
	return {}