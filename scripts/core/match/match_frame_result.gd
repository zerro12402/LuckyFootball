class_name MatchFrameResult
extends RefCounted

var snapshot: MatchStateSnapshot:
	get:
		return _snapshot

var events: Array[MatchEvent]:
	get:
		return _events.duplicate()

var simulation_steps: int:
	get:
		return _simulation_steps

var interpolation_alpha: float:
	get:
		return _interpolation_alpha

var _snapshot: MatchStateSnapshot
var _events: Array[MatchEvent] = []
var _simulation_steps: int
var _interpolation_alpha: float


func _init(
	new_snapshot: MatchStateSnapshot,
	new_events: Array[MatchEvent],
	new_simulation_steps: int,
	new_interpolation_alpha: float,
) -> void:
	_snapshot = new_snapshot
	_events = new_events.duplicate()
	_simulation_steps = new_simulation_steps
	_interpolation_alpha = new_interpolation_alpha

