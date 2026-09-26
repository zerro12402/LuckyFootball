class_name MatchState
extends RefCounted

enum Phase {
	READY,
	RUNNING,
	PAUSED,
	FINISHED,
}

var phase: int:
	get:
		return _phase

var elapsed_seconds: float:
	get:
		return _elapsed_seconds

var simulation_step: int:
	get:
		return _simulation_step

var random_seed: int:
	get:
		return _random_seed

var _phase: int = Phase.READY
var _elapsed_seconds: float = 0.0
var _simulation_step: int = 0
var _random_seed: int


func _init(new_random_seed: int) -> void:
	_random_seed = new_random_seed


func _set_phase(new_phase: int) -> void:
	_phase = new_phase


func _advance(fixed_delta_seconds: float) -> void:
	_elapsed_seconds += fixed_delta_seconds
	_simulation_step += 1
