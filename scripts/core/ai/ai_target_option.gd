## Immutable legal-target proposal; action intent never owns writable match state.
class_name AITargetOption
extends RefCounted

var action: MatchAction:
	get: return _action
var weight: float:
	get: return _weight
var _action: MatchAction
var _weight: float
var destination_m: Vector2:
	get: return _destination_m
var _destination_m: Vector2

func _init(intent: MatchAction, target_weight: float = 1.0, destination: Vector2 = Vector2.INF) -> void:
	_action = intent
	_weight = target_weight
	_destination_m = destination
