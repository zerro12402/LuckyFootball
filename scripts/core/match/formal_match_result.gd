## Frozen official result published exactly once at the configured deadline; cancellation has no result.
class_name FormalMatchResult
extends RefCounted

enum Outcome { HOME_WIN, DRAW, AWAY_WIN }

var match_id: String:
	get: return _match_id
var _match_id: String
var home_team_id: String:
	get: return _home_team_id
var _home_team_id: String
var away_team_id: String:
	get: return _away_team_id
var _away_team_id: String
var home_score: int:
	get: return _home_score
var _home_score: int
var away_score: int:
	get: return _away_score
var _away_score: int
var random_seed: int:
	get: return _random_seed
var _random_seed: int
var elapsed_seconds: float:
	get: return _elapsed_seconds
var _elapsed_seconds: float
var outcome: int:
	get: return _outcome
var _outcome: int

## Copies final facts and derives the official home/draw/away outcome once.
func _init(new_match_id: String, new_home_team_id: String, new_away_team_id: String, new_home_score: int, new_away_score: int, new_random_seed: int, new_elapsed_seconds: float) -> void:
	_match_id = new_match_id
	_home_team_id = new_home_team_id
	_away_team_id = new_away_team_id
	_home_score = new_home_score
	_away_score = new_away_score
	_random_seed = new_random_seed
	_elapsed_seconds = new_elapsed_seconds
	_outcome = Outcome.DRAW if _home_score == _away_score else (Outcome.HOME_WIN if _home_score > _away_score else Outcome.AWAY_WIN)
