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

var _phase: int
var _elapsed_seconds: float
var _simulation_step: int
var _random_seed: int
var _players: Array[PlayerStateSnapshot]


func _init(
	new_phase: int,
	new_elapsed_seconds: float,
	new_simulation_step: int,
	new_random_seed: int,
	new_players: Array[PlayerStateSnapshot] = [],
) -> void:
	_phase = new_phase
	_elapsed_seconds = new_elapsed_seconds
	_simulation_step = new_simulation_step
	_random_seed = new_random_seed
	_players = new_players.duplicate()


func get_player(player_id: String) -> PlayerStateSnapshot:
	for player_snapshot in _players:
		if player_snapshot.player_id == player_id:
			return player_snapshot
	return null
