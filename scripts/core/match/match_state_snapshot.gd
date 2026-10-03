## Exposes a read-only fixed-step view of match phase, players, ball, and scores.
class_name MatchStateSnapshot
extends RefCounted

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

var players: Array[PlayerStateSnapshot]:
	get:
		return _players.duplicate()

var ball: BallStateSnapshot:
	get:
		return _ball

var round_phase: int:
	get:
		return _round_phase

var left_goal_count: int:
	get:
		return _left_goal_count

var right_goal_count: int:
	get:
		return _right_goal_count

var _phase: int
var _round_phase: int
var _left_goal_count: int
var _right_goal_count: int
var _elapsed_seconds: float
var _simulation_step: int
var _random_seed: int
var _players: Array[PlayerStateSnapshot]
var _ball: BallStateSnapshot


func _init(
	new_phase: int,
	new_elapsed_seconds: float,
	new_simulation_step: int,
	new_random_seed: int,
	new_players: Array[PlayerStateSnapshot] = [],
	new_ball: BallStateSnapshot = null,
	new_round_phase: int = MatchState.RoundPhase.PLAYING,
	new_left_goal_count: int = 0,
	new_right_goal_count: int = 0,
) -> void:
	_phase = new_phase
	_elapsed_seconds = new_elapsed_seconds
	_simulation_step = new_simulation_step
	_random_seed = new_random_seed
	_players = new_players.duplicate()
	_ball = new_ball
	_round_phase = new_round_phase
	_left_goal_count = new_left_goal_count
	_right_goal_count = new_right_goal_count


## Resolves a player from the immutable snapshot copy by stable ID.
func get_player(player_id: String) -> PlayerStateSnapshot:
	for player_snapshot in _players:
		if player_snapshot.player_id == player_id:
			return player_snapshot
	return null
