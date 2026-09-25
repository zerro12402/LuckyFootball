class_name FieldDataRepository
extends RefCounted

const REQUIRED_HEADERS: Array[String] = [
	"field_id",
	"length_m",
	"width_m",
	"goal_width_m",
	"goal_depth_m",
	"penalty_area_depth_m",
	"penalty_area_width_m",
	"center_circle_radius_m",
	"pixels_per_meter",
	"visual_id",
]


func load_from_csv(csv_path: String) -> FieldDataLoadResult:
	var result := FieldDataLoadResult.new()
	if not FileAccess.file_exists(csv_path):
		result._add_error("Field CSV does not exist: %s" % csv_path)
		return result

	var csv_file := FileAccess.open(csv_path, FileAccess.READ)
	if csv_file == null:
		result._add_error("Cannot open field CSV: %s" % csv_path)
		return result
	var headers := csv_file.get_csv_line()
	if not _has_required_headers(headers):
		result._add_error("Field CSV header does not match the required schema")
		return result

	var parsed_fields: Array[FieldDefinition] = []
	var known_ids: Dictionary[String, bool] = {}
	var row_number := 1
	while not csv_file.eof_reached():
		var columns := csv_file.get_csv_line()
		row_number += 1
		if columns.size() == 1 and columns[0].strip_edges().is_empty():
			continue
		var field := _parse_field(columns, row_number, known_ids, result)
		if field != null:
			parsed_fields.append(field)

	if result.is_success:
		result._replace_fields(parsed_fields)
	return result


func _has_required_headers(headers: PackedStringArray) -> bool:
	if headers.size() != REQUIRED_HEADERS.size():
		return false
	for index in range(REQUIRED_HEADERS.size()):
		if headers[index].strip_edges() != REQUIRED_HEADERS[index]:
			return false
	return true


func _parse_field(
	columns: PackedStringArray,
	row_number: int,
	known_ids: Dictionary[String, bool],
	result: FieldDataLoadResult,
) -> FieldDefinition:
	if columns.size() != REQUIRED_HEADERS.size():
		result._add_error("Field row %d has an invalid column count" % row_number)
		return null

	var field_id := columns[0].strip_edges()
	var visual_id := columns[9].strip_edges()
	var row_is_valid := true
	if field_id.is_empty() or known_ids.has(field_id):
		result._add_error("Field row %d has an invalid or duplicate field_id" % row_number)
		row_is_valid = false
	else:
		known_ids[field_id] = true
	if visual_id.is_empty():
		result._add_error("Field row %d has an empty visual_id" % row_number)
		row_is_valid = false

	var values: Array[float] = []
	for column_index in range(1, 9):
		var parsed_value := _parse_positive_float(
			columns[column_index],
			REQUIRED_HEADERS[column_index],
			row_number,
			result,
		)
		values.append(parsed_value)
		if parsed_value <= 0.0:
			row_is_valid = false

	if row_is_valid and (
		values[2] >= values[1]
		or values[4] >= values[0] * 0.5
		or values[5] > values[1]
		or values[6] >= values[1] * 0.5
	):
		result._add_error("Field row %d has inconsistent dimensions" % row_number)
		row_is_valid = false

	if not row_is_valid:
		return null
	return FieldDefinition.new(
		field_id,
		values[0],
		values[1],
		values[2],
		values[3],
		values[4],
		values[5],
		values[6],
		values[7],
		visual_id,
	)


func _parse_positive_float(
	raw_value: String,
	field_name: String,
	row_number: int,
	result: FieldDataLoadResult,
) -> float:
	var normalized_value := raw_value.strip_edges()
	if not normalized_value.is_valid_float():
		result._add_error(
			"Field row %d has a non-number %s: %s"
			% [row_number, field_name, normalized_value]
		)
		return -1.0
	var parsed_value := normalized_value.to_float()
	if parsed_value <= 0.0:
		result._add_error(
			"Field row %d has a non-positive %s" % [row_number, field_name]
		)
		return -1.0
	return parsed_value
