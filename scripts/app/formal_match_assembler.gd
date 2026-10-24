## Validates complete formal rosters before publishing a simulation; has no scene or development dependencies.
class_name FormalMatchAssembler
extends RefCounted

var errors: PackedStringArray:
	get: return _errors.duplicate()
var _errors: PackedStringArray = []

## Builds all twelve actors transactionally, with a centered free ball and opposite configured goals.
func create_match(data: DataRepository, teams: TeamDataRepository, field: FieldDefinition,
		config: MatchConfigDefinition, id: String, seed_value: int,
		home_id: String, away_id: String) -> MatchSimulation:
	_errors.clear()
	if data == null or teams == null or field == null or config == null or id.is_empty():
		_errors.append("Validated data, field, config and a match ID are required")
		return null
	var home := teams.get_team(home_id)
	var away := teams.get_team(away_id)
	if home == null or away == null or home_id == away_id or home.attacking_direction != -away.attacking_direction:
		_errors.append("Two different teams with opposite attacking directions are required")
		return null
	var simulation := MatchSimulation.new(seed_value, config, field)
	for team in [home, away]:
		var roster := teams.get_roster(team.team_id)
		if roster.size() != 6:
			_errors.append("Each team must field exactly six players")
			return null
		var goal := Vector2(field.length_m * 0.5 * team.attacking_direction, 0)
		if not simulation.register_team_attacking_goal(team.team_id, goal):
			_errors.append("Invalid attacking goal")
			return null
		for entry in roster:
			var definition := data.get_player_by_id(entry.player_id)
			var point := teams.get_position(team.default_formation, entry.default_position)
			if definition == null or point == null:
				_errors.append("Invalid player or formation reference")
				return null
			var position := Vector2(point.position_m.x * team.attacking_direction, point.position_m.y)
			if absf(position.x) >= field.length_m * 0.5 or absf(position.y) >= field.width_m * 0.5 or not simulation.register_player_from_definition(definition, position, team.team_id, definition.default_role == "goalkeeper"):
				_errors.append("Invalid spawn or duplicate player")
				return null
	if not simulation.register_ball(Vector2.ZERO) or not simulation.configure_formal_match(id, home_id, away_id):
		_errors.append("Invalid complete formal roster, identity or configuration")
		return null
	return simulation
