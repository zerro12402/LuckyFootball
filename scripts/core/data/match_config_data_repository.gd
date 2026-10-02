## Parses match_configs.csv into typed rules without leaking partial results.
class_name MatchConfigDataRepository
extends RefCounted

const REQUIRED_HEADERS: Array[String] = [
	"config_id",
	"shot_base_speed_mps",
	"shot_min_attribute_multiplier",
	"shot_max_attribute_multiplier",
	"shot_ground_deceleration_mps2",
	"shot_stop_speed_mps",
	"shot_windup_seconds",
	"shot_recovery_seconds",
	"shot_action_duration_seconds",
	"shot_reacquire_delay_seconds",
	"shot_apex_height_m",
]


## Validates the full table before exposing any configuration definitions.
func load_from_csv(csv_path: String) -> MatchConfigDataLoadResult:
	var result := MatchConfigDataLoadResult.new()
	if not FileAccess.file_exists(csv_path):
		result._add_error("Match config CSV does not exist: %s" % csv_path)
		return result
	var csv_file := FileAccess.open(csv_path, FileAccess.READ)
	if csv_file == null:
		result._add_error("Cannot open match config CSV: %s" % csv_path)
		return result
	if not _has_required_headers(csv_file.get_csv_line()):
		result._add_error("Match config CSV header does not match the required schema")
		return result
	var parsed_configs: Array[MatchConfigDefinition] = []
	var known_ids: Dictionary[String, bool] = {}
	var row_number := 1
	while not csv_file.eof_reached():
		var columns := csv_file.get_csv_line()
		row_number += 1
		if columns.size() == 1 and columns[0].strip_edges().is_empty():
			continue
		var config := _parse_config(columns, row_number, known_ids, result)
		if config != null:
			parsed_configs.append(config)
	if parsed_configs.is_empty():
		result._add_error("Match config CSV requires at least one row")
	if result.is_success:
		result._replace_configs(parsed_configs)
	return result


## Requires a fixed header order so malformed rows cannot change rule meanings.
func _has_required_headers(headers: PackedStringArray) -> bool:
	if headers.size() != REQUIRED_HEADERS.size():
		return false
	for index in range(REQUIRED_HEADERS.size()):
		if headers[index].strip_edges() != REQUIRED_HEADERS[index]:
			return false
	return true


## Rejects duplicate IDs, invalid numbers, and inconsistent action timings.
func _parse_config(
	columns: PackedStringArray,
	row_number: int,
	known_ids: Dictionary[String, bool],
	result: MatchConfigDataLoadResult,
) -> MatchConfigDefinition:
	if columns.size() != REQUIRED_HEADERS.size():
		result._add_error("Match config row %d has an invalid column count" % row_number)
		return null
	var config_id := columns[0].strip_edges()
	if not _is_valid_ascii_id(config_id) or known_ids.has(config_id):
		result._add_error("Match config row %d has an invalid or duplicate config_id" % row_number)
		return null
	known_ids[config_id] = true
	var values: Array[float] = []
	for index in range(1, REQUIRED_HEADERS.size()):
		var raw_value := columns[index].strip_edges()
		if not raw_value.is_valid_float():
			result._add_error("Match config row %d has invalid %s" % [row_number, REQUIRED_HEADERS[index]])
			return null
		var parsed_value := raw_value.to_float()
		if not is_finite(parsed_value):
			result._add_error("Match config row %d has non-finite %s" % [row_number, REQUIRED_HEADERS[index]])
			return null
		values.append(parsed_value)
	if (
		values[0] <= 0.0 or values[1] <= 0.0 or values[2] < values[1]
		or values[3] <= 0.0 or values[4] < 0.0 or values[5] <= 0.0
		or values[6] <= values[5] or values[7] <= values[6] or values[8] < 0.0
		or values[9] <= 0.0
	):
		result._add_error("Match config row %d has invalid shot parameters" % row_number)
		return null
	return MatchConfigDefinition.new(
		config_id, values[0], values[1], values[2], values[3],
		values[4], values[5], values[6], values[7], values[8], values[9],
	)



## Limits preset IDs to portable lowercase ASCII snake_case names.
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
