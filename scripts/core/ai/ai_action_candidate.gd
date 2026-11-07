## Groups targets by behavior so teammate count cannot multiply category probability.
class_name AIActionCandidate
extends RefCounted

enum Behavior { HOLD, ADVANCE, PASS, SHOOT, JUMP, SUPPORT, PRESS, TACKLE, ATTACK, CHASE, RETURN, SAVE, HEADER_SHOT, HEADER_CLEAR,
	DROP_SUPPORT, CENTRAL_SUPPORT, BACK_SUPPORT, COVER_LANE, MARK, PROTECT_GOAL, KEEPER_POSITION }
var behavior: int:
	get: return _behavior
var weight: float:
	get: return _weight
var targets: Array[AITargetOption]:
	get: return _targets.duplicate()
var _behavior: int
var _weight: float
var _targets: Array[AITargetOption]

func _init(kind: int, base_weight: float, options: Array[AITargetOption]) -> void:
	_behavior = kind
	_weight = base_weight
	_targets = options.duplicate()
