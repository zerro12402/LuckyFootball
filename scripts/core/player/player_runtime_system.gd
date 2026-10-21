## Registers and advances player runtimes in stable ID order.
class_name PlayerRuntimeSystem
extends RefCounted

var _players_by_id: Dictionary[String, PlayerRuntime] = {}


## Rejects duplicate player IDs before constructing runtime state.
func register_player(
	player_id: String,
	initial_position_m: Vector2,
	movement_speed_mps: float = PlayerStateMachine.DEFAULT_MOVEMENT_SPEED_MPS,
	team_id: String = "default_team",
	shooting_attribute: int = 0,
	strength_attribute: int = 50,
	technique_attribute: int = 50,
) -> bool:
	if player_id.is_empty() or team_id.is_empty() or _players_by_id.has(player_id):
		return false
	if shooting_attribute < 0 or shooting_attribute > 100:
		return false
	_players_by_id[player_id] = PlayerRuntime.new(
		player_id,
		initial_position_m,
		movement_speed_mps,
		team_id,
		shooting_attribute,
		strength_attribute,
		technique_attribute,
	)
	return true


func has_player(player_id: String) -> bool:
	return _players_by_id.has(player_id)


func get_player(player_id: String) -> PlayerRuntime:
	return _players_by_id.get(player_id) as PlayerRuntime


## Returns players in deterministic order for fixed-step simulation.
func get_players() -> Array[PlayerRuntime]:
	var player_ids: Array[String] = []
	for player_id in _players_by_id.keys():
		player_ids.append(player_id as String)
	player_ids.sort()
	var players: Array[PlayerRuntime] = []
	for player_id in player_ids:
		players.append(_players_by_id[player_id])
	return players


## Restores every registered player in stable order for a new round.
func reset_all_players() -> void:
	for player_runtime in get_players():
		player_runtime.reset_to_spawn()



## Stops every player, cancelling actions when carried-ball out requires idle.
func stop_all_players_for_settlement(should_cancel_actions: bool) -> void:
	for player_runtime in get_players():
		player_runtime.state_machine.stop_for_settlement(should_cancel_actions)


## Delegates a validated command to its registered player.
func apply_action(action: MatchAction) -> bool:
	var player_runtime := get_player(action.player_id)
	if player_runtime == null:
		return false
	return player_runtime.apply_action(action)


## Advances every player once without relying on scene-tree order.
func advance(fixed_delta_seconds: float) -> void:
	for player_runtime in get_players():
		player_runtime.advance(fixed_delta_seconds)
