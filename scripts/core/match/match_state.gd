## Holds the deterministic match clock, round phase, and goal counts.
class_name MatchState
extends RefCounted

enum Phase {
	READY,
	RUNNING,
	PAUSED,
	FINISHED,
	CANCELLED,
}

enum RoundPhase {
	PLAYING,
	GOAL_RESOLVED,
	POST_GOAL_MOTION,
	OUT_RESOLVED,
	RESETTING,
}

var match_id: String:
	get: return _match_id
var _match_id: String = ""
var home_team_id: String:
	get: return _home_team_id
var _home_team_id: String = ""
var away_team_id: String:
	get: return _away_team_id
var _away_team_id: String = ""
var duration_seconds: float:
	get: return _duration_seconds
var _duration_seconds: float = 0
var round_sequence: int:
	get: return _round_sequence
var _round_sequence: int = 0
var control_revision: int:
	get: return _control_revision
var _control_revision: int = 0
var home_score: int:
	get: return _home_score
var _home_score: int = 0
var away_score: int:
	get: return _away_score
var _away_score: int = 0
var cancellation_reason: String:
	get: return _cancellation_reason
var _cancellation_reason: String = ""
var result: FormalMatchResult:
	get: return _result
var _result: FormalMatchResult

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


## Invalidates control envelopes whenever lifecycle authority changes.
func _set_phase(new_phase: int) -> void:
	if _phase != new_phase:
		_control_revision += 1
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


## Invalidates old round intent while retaining the independent lifecycle.
func _set_round_phase(new_phase: int) -> void:
	if _round_phase != new_phase:
		_control_revision += 1
	_round_phase = new_phase


## Copies formal identity before play; this metadata is never supplied through actor commands.
func _configure_formal(id: String, home: String, away: String, duration: float) -> void:
	_match_id = id
	_home_team_id = home
	_away_team_id = away
	_duration_seconds = duration
	_round_sequence = 1

## Scores by the team attacking a physical goal, independently of the last kicker.
func _record_team_goal(team_id: String) -> void:
	if team_id == _home_team_id:
		_home_score += 1
	elif team_id == _away_team_id:
		_away_score += 1

## Invalidates old control batches without changing the match's simulation step or random sequence.
func _revise_control() -> void:
	_control_revision += 1

## Advances only the round identity when all actors have been restored atomically.
func _next_round() -> void:
	_round_sequence += 1

## Stores only the immutable result constructed at the official deadline.
func _set_result(value: FormalMatchResult) -> void:
	_result = value

## Records cancellation independently of the normal result channel.
func _set_cancellation_reason(value: String) -> void:
	_cancellation_reason = value


## Clamps the final clock to the configured duration without adding an extra simulation step.
func _clamp_elapsed(seconds: float) -> void:
	_elapsed_seconds = seconds
