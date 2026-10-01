## Loads and indexes validated static definitions before match creation.
class_name DataRepository
extends RefCounted

const DEFAULT_DATA_DIRECTORY := "res://resources/data"

var player_definitions: Array[PlayerDefinition]:
	get:
		return _player_definitions.duplicate()

var field_definitions: Array[FieldDefinition]:
	get:
		return _field_definitions.duplicate()

var match_config_definitions: Array[MatchConfigDefinition]:
	get:
		return _match_config_definitions.duplicate()

var last_errors: PackedStringArray:
	get:
		return _last_errors.duplicate()

var _player_definitions: Array[PlayerDefinition] = []
var _players_by_id: Dictionary[String, PlayerDefinition] = {}
var _field_definitions: Array[FieldDefinition] = []
var _fields_by_id: Dictionary[String, FieldDefinition] = {}
var _match_config_definitions: Array[MatchConfigDefinition] = []
var _match_configs_by_id: Dictionary[String, MatchConfigDefinition] = {}
var _last_errors: PackedStringArray = []


## Loads every required table transactionally so no partial rules remain on failure.
func load_all(data_directory: String = DEFAULT_DATA_DIRECTORY) -> bool:
	var player_result := PlayerDataRepository.new().load_from_csv(
		data_directory.path_join("players.csv")
	)
	if not player_result.is_success:
		_clear_loaded_data()
		_last_errors = player_result.errors
		return false
	var field_result := FieldDataRepository.new().load_from_csv(
		data_directory.path_join("fields.csv")
	)
	if not field_result.is_success:
		_clear_loaded_data()
		_last_errors = field_result.errors
		return false
	var config_result := MatchConfigDataRepository.new().load_from_csv(
		data_directory.path_join("match_configs.csv")
	)
	if not config_result.is_success:
		_clear_loaded_data()
		_last_errors = config_result.errors
		return false
	_index_players(player_result.players)
	_index_fields(field_result.fields)
	_index_match_configs(config_result.configs)
	_last_errors.clear()
	return true


func get_player_by_id(player_id: String) -> PlayerDefinition:
	return _players_by_id.get(player_id) as PlayerDefinition


func get_field_by_id(field_id: String) -> FieldDefinition:
	return _fields_by_id.get(field_id) as FieldDefinition


func get_match_config_by_id(config_id: String) -> MatchConfigDefinition:
	return _match_configs_by_id.get(config_id) as MatchConfigDefinition


## Copies definitions into an ID index after CSV validation succeeds.
func _index_players(new_players: Array[PlayerDefinition]) -> void:
	_player_definitions = new_players.duplicate()
	_players_by_id.clear()
	for player_definition in _player_definitions:
		_players_by_id[player_definition.player_id] = player_definition


## Keeps field lookup independent of presentation scene paths.
func _index_fields(new_fields: Array[FieldDefinition]) -> void:
	_field_definitions = new_fields.duplicate()
	_fields_by_id.clear()
	for field_definition in _field_definitions:
		_fields_by_id[field_definition.field_id] = field_definition


## Makes the selected match preset available by stable ID.
func _index_match_configs(new_configs: Array[MatchConfigDefinition]) -> void:
	_match_config_definitions = new_configs.duplicate()
	_match_configs_by_id.clear()
	for config_definition in _match_config_definitions:
		_match_configs_by_id[config_definition.config_id] = config_definition


## Clears all indexes together after any required table fails to load.
func _clear_loaded_data() -> void:
	_player_definitions.clear()
	_players_by_id.clear()
	_field_definitions.clear()
	_fields_by_id.clear()
	_match_config_definitions.clear()
	_match_configs_by_id.clear()
