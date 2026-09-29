class_name PlayerRuntimeSystem
extends RefCounted

var _players_by_id: Dictionary[String, PlayerRuntime] = {}


func register_player(
	player_id: String,
	initial_position_m: Vector2,
	movement_speed_mps: float = PlayerStateMachine.DEFAULT_MOVEMENT_SPEED_MPS,
) -> bool:
	if player_id.is_empty() or _players_by_id.has(player_id):
		return false
	_players_by_id[player_id] = PlayerRuntime.new(
		player_id,
		initial_position_m,
		movement_speed_mps,
	)
	return true


func has_player(player_id: String) -> bool:
	return _players_by_id.has(player_id)


func get_player(player_id: String) -> PlayerRuntime:
	return _players_by_id.get(player_id) as PlayerRuntime


func get_players() -> Array[PlayerRuntime]:
	var player_ids: Array[String] = []
	for player_id in _players_by_id.keys():
		player_ids.append(player_id as String)
	player_ids.sort()

	var players: Array[PlayerRuntime] = []
	for player_id in player_ids:
		players.append(_players_by_id[player_id])
	return players


func apply_action(action: MatchAction) -> bool:
	var player_runtime := get_player(action.player_id)
	if player_runtime == null:
		return false
	return player_runtime.apply_action(action)


func advance(fixed_delta_seconds: float) -> void:
	for player_runtime in get_players():
		player_runtime.advance(fixed_delta_seconds)
