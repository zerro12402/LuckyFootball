## Loads team, roster and formation tables transactionally; publication follows complete validation.
class_name TeamDataRepository
extends RefCounted

var teams: Array[TeamDefinition]:
	get: return _teams.duplicate()
var team_players: Array[TeamPlayerDefinition]:
	get: return _team_players.duplicate()
var positions: Array[FormationPositionDefinition]:
	get: return _positions.duplicate()
var errors: PackedStringArray:
	get: return _errors.duplicate()
var _teams: Array[TeamDefinition] = []
var _team_players: Array[TeamPlayerDefinition] = []
var _positions: Array[FormationPositionDefinition] = []
var _errors: PackedStringArray = []

## Loads only formal tables; legacy isolated static-data fixtures need not contain team tables.
func load_all(directory: String, players: DataRepository, field: FieldDefinition) -> bool:
	_teams.clear()
	_team_players.clear()
	_positions.clear()
	_errors.clear()
	var team_rows := _read(directory.path_join("teams.csv"), ["team_id", "display_name", "default_formation", "attacking_direction"])
	var roster_rows := _read(directory.path_join("team_players.csv"), ["team_id", "player_id", "slot", "default_position"])
	var formation_rows := _read(directory.path_join("formation_positions.csv"), ["formation_id", "position_id", "x_m", "y_m"])
	for row in team_rows:
		if not _valid_id(row[0]) or row[1].is_empty() or not _valid_id(row[2]) or not row[3].is_valid_int() or absi(row[3].to_int()) != 1 or get_team(row[0]) != null:
			_errors.append("Invalid or duplicate team: " + row[0])
			continue
		_teams.append(TeamDefinition.new(row[0], row[1], row[2], row[3].to_int()))
	for row in formation_rows:
		if not _valid_id(row[0]) or not _valid_id(row[1]) or not row[2].is_valid_float() or not row[3].is_valid_float():
			_errors.append("Invalid formation row")
			continue
		var point := Vector2(row[2].to_float(), row[3].to_float())
		if not point.is_finite() or absf(point.x) >= field.length_m * 0.5 or absf(point.y) >= field.width_m * 0.5 or get_position(row[0], row[1]) != null:
			_errors.append("Invalid or duplicate formation position: " + row[1])
			continue
		_positions.append(FormationPositionDefinition.new(row[0], row[1], point))
	var used: Dictionary[String, bool] = {}
	for row in roster_rows:
		var team := get_team(row[0])
		if team == null or players.get_player_by_id(row[1]) == null or not row[2].is_valid_int() or row[2].to_int() < 1 or row[2].to_int() > 6 or used.has(row[1]):
			_errors.append("Invalid roster reference, slot or duplicate player: " + row[1])
			continue
		if get_position(team.default_formation, row[3]) == null:
			_errors.append("Unknown formation position: " + row[3])
			continue
		used[row[1]] = true
		_team_players.append(TeamPlayerDefinition.new(row[0], row[1], row[2].to_int(), row[3]))
	for team in _teams:
		_validate_roster(team, players)
	if _teams.is_empty():
		_errors.append("No teams configured")
	if not _errors.is_empty():
		_teams.clear()
		_team_players.clear()
		_positions.clear()
	return _errors.is_empty()

## Requires six different slots/positions and exactly one role-qualified goalkeeper per team.
func _validate_roster(team: TeamDefinition, players: DataRepository) -> void:
	var roster := get_roster(team.team_id)
	var slots: Dictionary[int, bool] = {}
	var points: Dictionary[Vector2, bool] = {}
	var keepers := 0
	for entry in roster:
		var point := get_position(team.default_formation, entry.default_position).position_m
		if slots.has(entry.slot) or points.has(point):
			_errors.append("Duplicate roster slot/position: " + team.team_id)
		slots[entry.slot] = true
		points[point] = true
		if players.get_player_by_id(entry.player_id).default_role == "goalkeeper":
			keepers += 1
	if roster.size() != 6 or keepers != 1:
		_errors.append("Team requires six players and one goalkeeper: " + team.team_id)

## Resolves a validated team without exposing a writable index.
func get_team(id: String) -> TeamDefinition:
	for team in _teams:
		if team.team_id == id:
			return team
	return null

## Returns roster entries in stable slot order, independent of CSV row order.
func get_roster(id: String) -> Array[TeamPlayerDefinition]:
	var found: Array[TeamPlayerDefinition] = []
	for entry in _team_players:
		if entry.team_id == id:
			found.append(entry)
	found.sort_custom(func(a: TeamPlayerDefinition, b: TeamPlayerDefinition) -> bool: return a.slot < b.slot)
	return found

## Resolves one versioned formation position by its compound stable key.
func get_position(formation: String, id: String) -> FormationPositionDefinition:
	for point in _positions:
		if point.formation_id == formation and point.position_id == id:
			return point
	return null

## Parses exact UTF-8 schemas, rejecting malformed rows without leaking partially valid definitions.
func _read(path: String, headers: PackedStringArray) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Cannot open " + path)
		return rows
	if file.get_csv_line() != headers:
		_errors.append("Invalid CSV headers: " + path)
		return rows
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].strip_edges().is_empty():
			continue
		if row.size() != headers.size():
			_errors.append("Invalid CSV row: " + path)
			continue
		for i in range(row.size()):
			row[i] = row[i].strip_edges()
		rows.append(row)
	return rows

## Restricts stable identifiers to lowercase ASCII without platform-dependent whitespace or separators.
func _valid_id(id: String) -> bool:
	if id.is_empty() or id[0] < "a" or id[0] > "z":
		return false
	for character in id:
		if not ((character >= "a" and character <= "z") or (character >= "0" and character <= "9") or character == "_"):
			return false
	return true
