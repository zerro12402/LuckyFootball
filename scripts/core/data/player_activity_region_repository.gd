## Loads a complete six-position, three-phase activity table without publishing partial definitions.
class_name PlayerActivityRegionRepository
extends RefCounted

const POSITIONS: Array[String] = ["keeper", "back_left", "back_right", "mid", "forward_left", "forward_right"]
const PHASES: Array[String] = ["attack", "defend", "loose"]
var errors: PackedStringArray:
	get: return _errors.duplicate()
var regions: Array[PlayerActivityRegionDefinition]:
	get: return _regions.duplicate()
var _errors: PackedStringArray = []
var _regions: Array[PlayerActivityRegionDefinition] = []

## Validates exact schema, finite normalized bounds, duplicate keys and complete coverage.
func load_from_csv(path: String) -> bool:
	_errors.clear()
	_regions.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Cannot open activity regions: " + path)
		return false
	if file.get_csv_line() != PackedStringArray(["position_id", "phase", "space",
			"min_u", "max_u", "min_v", "max_v", "comment"]):
		_errors.append("Invalid activity region CSV headers")
		return false
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].strip_edges().is_empty():
			continue
		if row.size() != 8:
			_errors.append("Invalid region column count")
			continue
		var phase_index := PHASES.find(row[1])
		if not POSITIONS.has(row[0]) or phase_index < 0 or row[2] not in ["field", "own_penalty"]:
			_errors.append("Unknown activity region identity or space")
			continue
		if (row[0] == "keeper") != (row[2] == "own_penalty"):
			_errors.append("Only keepers use penalty-local regions")
			continue
		var valid := true
		for index in range(3, 7):
			if not row[index].is_valid_float() or not is_finite(row[index].to_float()) \
					or row[index].to_float() < 0.0 or row[index].to_float() > 1.0:
				valid = false
		if not valid:
			_errors.append("Region coordinates must be finite values in [0,1]")
			continue
		var minimum := Vector2(row[3].to_float(), row[5].to_float())
		var maximum := Vector2(row[4].to_float(), row[6].to_float())
		if minimum.x >= maximum.x or minimum.y >= maximum.y or get_region(row[0], phase_index) != null:
			_errors.append("Invalid or duplicate activity region: " + row[0])
			continue
		_regions.append(PlayerActivityRegionDefinition.new(row[0], phase_index, row[2], minimum, maximum))
	for position in POSITIONS:
		for phase in range(PHASES.size()):
			if get_region(position, phase) == null:
				_errors.append("Missing activity region: " + position + "/" + PHASES[phase])
	if not _errors.is_empty():
		_regions.clear()
	return _errors.is_empty()

## Resolves one immutable definition using the tactical enum values shared by the AI context.
func get_region(position: String, phase: int) -> PlayerActivityRegionDefinition:
	for region in _regions:
		if region.position_id == position and region.phase == phase:
			return region
	return null
