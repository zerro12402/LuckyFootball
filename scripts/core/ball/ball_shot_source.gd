## Locks the shooter and base attribute once at legal shot or header release.
class_name BallShotSource
extends RefCounted

var player_id: String:
	get: return _player_id
var team_id: String:
	get: return _team_id
var shooting: int:
	get: return _shooting
var sequence: int:
	get: return _sequence

var _player_id: String
var _team_id: String
var _shooting: int
var _sequence: int

func _init(id: String, team: String, base_shooting: int, shot_sequence: int) -> void:
	_player_id = id
	_team_id = team
	_shooting = base_shooting
	_sequence = shot_sequence
