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

var player_states: Array[PlayerMatchState]:
	get:
		return _player_states.duplicate()

var _phase: int = Phase.READY
var _elapsed_seconds: float = 0.0
var _simulation_step: int = 0
var _random_seed: int
var _player_states: Array[PlayerMatchState] = []
var _players_by_id: Dictionary[String, PlayerMatchState] = {}


func _init(new_random_seed: int) -> void:
	_random_seed = new_random_seed


func _set_phase(new_phase: int) -> void:
	_phase = new_phase


func _advance(fixed_delta_seconds: float) -> void:
	_elapsed_seconds += fixed_delta_seconds
	_simulation_step += 1


func _register_player(player_state: PlayerMatchState) -> void:
	assert(player_state != null, "Cannot register null player state")
	assert(
		not _players_by_id.has(player_state.player_id),
		"Duplicate player ID: %s" % player_state.player_id,
	)
	_player_states.append(player_state)
	_players_by_id[player_state.player_id] = player_state


func _get_player_state(player_id: String) -> PlayerMatchState:
	return _players_by_id.get(player_id) as PlayerMatchState
