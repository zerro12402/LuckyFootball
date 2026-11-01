## Exposes a read-only fixed-step view of match phase, players, ball, and scores.
class_name MatchStateSnapshot
extends RefCounted

var match_id: String:
	get: return _match_id
var _match_id: String
var kickoff_team_id: String:
	get: return _kickoff_team_id
var kickoff_player_id: String:
	get: return _kickoff_player_id
var kickoff_pending: bool:
	get: return _kickoff_pending
var _kickoff_team_id: String = ""
var _kickoff_player_id: String = ""
var _kickoff_pending: bool = false
var home_team_id: String:
	get: return _home_team_id
var _home_team_id: String
var away_team_id: String:
	get: return _away_team_id
var _away_team_id: String
var duration_seconds: float:
	get: return _duration_seconds
var _duration_seconds: float
var round_sequence: int:
	get: return _round_sequence
var _round_sequence: int
var control_revision: int:
	get: return _control_revision
var _control_revision: int
var home_score: int:
	get: return _home_score
var _home_score: int
var away_score: int:
	get: return _away_score
var _away_score: int
var cancellation_reason: String:
	get: return _cancellation_reason
var _cancellation_reason: String
var result: FormalMatchResult:
	get: return _result
var _result: FormalMatchResult
var remaining_seconds: float:
	get: return maxf(_duration_seconds - _elapsed_seconds, 0.0)
var can_decide_player_actions: bool:
	get: return MatchControlPolicy.can_decide(_phase, _round_phase)

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

var _control_owner_token: int = 0
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
	formal_state: MatchState = null,
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
	if formal_state != null:
		_kickoff_team_id = formal_state.kickoff_team_id
		_kickoff_player_id = formal_state.kickoff_player_id
		_kickoff_pending = formal_state.kickoff_pending
		_control_owner_token = formal_state.get_instance_id()
		_match_id = formal_state.match_id
		_home_team_id = formal_state.home_team_id
		_away_team_id = formal_state.away_team_id
		_duration_seconds = formal_state.duration_seconds
		_round_sequence = formal_state.round_sequence
		_control_revision = formal_state.control_revision
		_home_score = formal_state.home_score
		_away_score = formal_state.away_score
		_cancellation_reason = formal_state.cancellation_reason
		_result = formal_state.result



## Resolves a player from the immutable snapshot copy by stable ID.
func get_player(player_id: String) -> PlayerStateSnapshot:
	for player_snapshot in _players:
		if player_snapshot.player_id == player_id:
			return player_snapshot
	return null
