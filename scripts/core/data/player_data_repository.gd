class_name PlayerDataRepository
extends RefCounted

const REQUIRED_HEADERS: Array[String] = [
	"player_id",
	"display_name",
	"default_role",
	"speed",
	"shooting",
	"strength",
	"technique",
	"stamina",
	"tackling",
	"goalkeeping",
	"trait_1_id",
	"trait_2_id",
	"trait_3_id",
	"trait_4_id",
	"trait_5_id",
	"visual_id",
]
const MIN_ATTRIBUTE_VALUE := 1
const MAX_ATTRIBUTE_VALUE := 100
const MIN_TRAIT_COUNT := 3
const MAX_TRAIT_COUNT := 5
const TRAIT_COLUMN_START := 10
const TRAIT_COLUMN_END := 15
const VISUAL_ID_COLUMN := 15


func load_from_csv(csv_path: String) -> PlayerDataLoadResult:
	var result := PlayerDataLoadResult.new()
	if not FileAccess.file_exists(csv_path):
		result._add_error("Player CSV does not exist: %s" % csv_path)
		return result

	var csv_file := FileAccess.open(csv_path, FileAccess.READ)
	if csv_file == null:
		result._add_error(
			"Cannot open player CSV %s: %s"
			% [csv_path, error_string(FileAccess.get_open_error())]
		)
		return result

	var headers := csv_file.get_csv_line()
	if not _has_required_headers(headers):
		result._add_error("Player CSV header does not match the required schema")
		return result

	var parsed_players: Array[PlayerDefinition] = []
	var known_player_ids: Dictionary[String, bool] = {}
	var row_number := 1
	while not csv_file.eof_reached():
		var columns := csv_file.get_csv_line()
		row_number += 1
		if _is_empty_row(columns):
			continue
		var player := _parse_player(columns, row_number, known_player_ids, result)
		if player != null:
			parsed_players.append(player)

	if result.is_success:
		result._replace_players(parsed_players)
	return result


func _has_required_headers(headers: PackedStringArray) -> bool:
	if headers.size() != REQUIRED_HEADERS.size():
		return false
	for index in range(REQUIRED_HEADERS.size()):
		if headers[index].strip_edges() != REQUIRED_HEADERS[index]:
			return false
	return true


func _is_empty_row(columns: PackedStringArray) -> bool:
	return columns.size() == 1 and columns[0].strip_edges().is_empty()


func _parse_player(
	columns: PackedStringArray,
	row_number: int,
	known_player_ids: Dictionary[String, bool],
	result: PlayerDataLoadResult,
) -> PlayerDefinition:
	if columns.size() != REQUIRED_HEADERS.size():
		result._add_error(
			"Row %d has %d columns; expected %d"
			% [row_number, columns.size(), REQUIRED_HEADERS.size()]
		)
		return null

	var player_id := columns[0].strip_edges()
	var display_name := columns[1].strip_edges()
	var default_role := columns[2].strip_edges()
	var visual_id := columns[VISUAL_ID_COLUMN].strip_edges()
	var row_is_valid := true

	if not _is_valid_ascii_id(player_id):
		result._add_error("Row %d has an invalid player_id: %s" % [row_number, player_id])
		row_is_valid = false
	elif known_player_ids.has(player_id):
		result._add_error("Row %d duplicates player_id: %s" % [row_number, player_id])
		row_is_valid = false
	else:
		known_player_ids[player_id] = true

	if display_name.is_empty():
		result._add_error("Row %d has an empty display_name" % row_number)
		row_is_valid = false
	if default_role.is_empty():
		result._add_error("Row %d has an empty default_role" % row_number)
		row_is_valid = false
	if not _is_valid_ascii_id(visual_id):
		result._add_error("Row %d has an invalid visual_id: %s" % [row_number, visual_id])
		row_is_valid = false

	var attributes: Array[int] = []
	for column_index in range(3, 10):
		var parsed_attribute := _parse_attribute(
			columns[column_index],
			REQUIRED_HEADERS[column_index],
			row_number,
			result,
		)
		attributes.append(parsed_attribute)
		if parsed_attribute < MIN_ATTRIBUTE_VALUE:
			row_is_valid = false

	var trait_ids := _parse_trait_ids(columns, row_number, result)
	if trait_ids.is_empty():
		row_is_valid = false

	if not row_is_valid:
		return null
	return PlayerDefinition.new(
		player_id,
		display_name,
		default_role,
		attributes[0],
		attributes[1],
		attributes[2],
		attributes[3],
		attributes[4],
		attributes[5],
		attributes[6],
		trait_ids,
		visual_id,
	)


func _parse_attribute(
	raw_value: String,
	attribute_name: String,
	row_number: int,
	result: PlayerDataLoadResult,
) -> int:
	var normalized_value := raw_value.strip_edges()
	if not normalized_value.is_valid_int():
		result._add_error(
			"Row %d has a non-integer %s: %s"
			% [row_number, attribute_name, normalized_value]
		)
		return -1
	var attribute_value := normalized_value.to_int()
	if attribute_value < MIN_ATTRIBUTE_VALUE or attribute_value > MAX_ATTRIBUTE_VALUE:
		result._add_error(
			"Row %d has %s outside %d-%d: %d"
			% [
				row_number,
				attribute_name,
				MIN_ATTRIBUTE_VALUE,
				MAX_ATTRIBUTE_VALUE,
				attribute_value,
			]
		)
		return -1
	return attribute_value


func _parse_trait_ids(
	columns: PackedStringArray,
	row_number: int,
	result: PlayerDataLoadResult,
) -> PackedStringArray:
	var trait_ids := PackedStringArray()
	var known_trait_ids: Dictionary[String, bool] = {}
	var trait_ids_are_valid := true
	for column_index in range(TRAIT_COLUMN_START, TRAIT_COLUMN_END):
		var trait_id := columns[column_index].strip_edges()
		if trait_id.is_empty():
			if column_index < TRAIT_COLUMN_START + MIN_TRAIT_COUNT:
				result._add_error(
					"Row %d has an empty %s"
					% [row_number, REQUIRED_HEADERS[column_index]]
				)
				trait_ids_are_valid = false
			continue
		if not _is_valid_ascii_id(trait_id):
			result._add_error("Row %d has an invalid trait_id: %s" % [row_number, trait_id])
			trait_ids_are_valid = false
		elif known_trait_ids.has(trait_id):
			result._add_error("Row %d duplicates trait_id: %s" % [row_number, trait_id])
			trait_ids_are_valid = false
		else:
			known_trait_ids[trait_id] = true
			trait_ids.append(trait_id)

	if trait_ids.size() < MIN_TRAIT_COUNT or trait_ids.size() > MAX_TRAIT_COUNT:
		trait_ids_are_valid = false
	if not trait_ids_are_valid:
		return PackedStringArray()
	return trait_ids


func _is_valid_ascii_id(identifier: String) -> bool:
	if identifier.is_empty():
		return false
	for index in range(identifier.length()):
		var character_code := identifier.unicode_at(index)
		var is_lowercase_letter := character_code >= 97 and character_code <= 122
		var is_digit := character_code >= 48 and character_code <= 57
		if index == 0 and not is_lowercase_letter:
			return false
		if not is_lowercase_letter and not is_digit and character_code != 95:
			return false
	return true
