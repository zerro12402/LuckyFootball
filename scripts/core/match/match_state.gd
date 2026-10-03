## Holds the deterministic match clock, round phase, and goal counts.
class_name MatchState
extends RefCounted

enum Phase {
	READY,
	RUNNING,
	PAUSED,
	FINISHED,
}

enum RoundPhase {
	PLAYING,
	GOAL_RESOLVED,
	POST_GOAL_MOTION,
	OUT_RESOLVED,
	RESETTING,
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

var round_phase: int:
	get:
		return _round_phase

var left_goal_count: int:
	get:
		return _left_goal_count

var right_goal_count: int:
	get:
		return _right_goal_count

var _phase: int = Phase.READY
var _round_phase: int = RoundPhase.PLAYING
var _left_goal_count: int = 0
var _right_goal_count: int = 0
var _elapsed_seconds: float = 0.0
var _simulation_step: int = 0
var _random_seed: int


func _init(new_random_seed: int) -> void:
	_random_seed = new_random_seed


func _set_phase(new_phase: int) -> void:
	_phase = new_phase


## Increments time and fixed-step count only during an accepted match step.
func _advance(fixed_delta_seconds: float) -> void:
	_elapsed_seconds += fixed_delta_seconds
	_simulation_step += 1


## Records exactly one goal against the crossed physical goal side.
func _record_goal(side: int) -> void:
	if side == MatchBoundaryResult.Side.LEFT:
		_left_goal_count += 1
	elif side == MatchBoundaryResult.Side.RIGHT:
		_right_goal_count += 1
	else:
		assert(false, "Goals require a left or right side")


## Clears only the current test clock and scores for a full restart.
func _restart_test() -> void:
	_elapsed_seconds = 0.0
	_simulation_step = 0
	_left_goal_count = 0
	_right_goal_count = 0


func _set_round_phase(new_phase: int) -> void:
	_round_phase = new_phase
