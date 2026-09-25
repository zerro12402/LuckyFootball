class_name DataRepository
extends RefCounted

const DEFAULT_DATA_DIRECTORY := "res://resources/data"

var player_definitions: Array[PlayerDefinition]:
	get:
		return _player_definitions.duplicate()

var field_definitions: Array[FieldDefinition]:
	get:
		return _field_definitions.duplicate()

var last_errors: PackedStringArray:
	get:
		return _last_errors.duplicate()

var _player_definitions: Array[PlayerDefinition] = []
var _players_by_id: Dictionary[String, PlayerDefinition] = {}
var _field_definitions: Array[FieldDefinition] = []
var _fields_by_id: Dictionary[String, FieldDefinition] = {}
var _last_errors: PackedStringArray = []


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

	_index_players(player_result.players)
	_index_fields(field_result.fields)
	_last_errors.clear()
	return true


func get_player_by_id(player_id: String) -> PlayerDefinition:
	return _players_by_id.get(player_id) as PlayerDefinition


func get_field_by_id(field_id: String) -> FieldDefinition:
	return _fields_by_id.get(field_id) as FieldDefinition


func _index_players(new_players: Array[PlayerDefinition]) -> void:
	_player_definitions = new_players.duplicate()
	_players_by_id.clear()
	for player_definition in _player_definitions:
		_players_by_id[player_definition.player_id] = player_definition


func _index_fields(new_fields: Array[FieldDefinition]) -> void:
	_field_definitions = new_fields.duplicate()
	_fields_by_id.clear()
	for field_definition in _field_definitions:
		_fields_by_id[field_definition.field_id] = field_definition


func _clear_loaded_data() -> void:
	_player_definitions.clear()
	_players_by_id.clear()
	_field_definitions.clear()
	_fields_by_id.clear()
