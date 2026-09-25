class_name DataRepository
extends RefCounted

const DEFAULT_DATA_DIRECTORY := "res://resources/data"

var player_definitions: Array[PlayerDefinition]:
	get:
		return _player_definitions.duplicate()

var last_errors: PackedStringArray:
	get:
		return _last_errors.duplicate()

var _player_definitions: Array[PlayerDefinition] = []
var _players_by_id: Dictionary[String, PlayerDefinition] = {}
var _last_errors: PackedStringArray = []


func load_all(data_directory: String = DEFAULT_DATA_DIRECTORY) -> bool:
	var player_result := PlayerDataRepository.new().load_from_csv(
		data_directory.path_join("players.csv")
	)
	if not player_result.is_success:
		_player_definitions.clear()
		_players_by_id.clear()
		_last_errors = player_result.errors
		return false

	_player_definitions = player_result.players
	_players_by_id.clear()
	for player_definition in _player_definitions:
		_players_by_id[player_definition.player_id] = player_definition
	_last_errors.clear()
	return true


func get_player_by_id(player_id: String) -> PlayerDefinition:
	return _players_by_id.get(player_id) as PlayerDefinition
