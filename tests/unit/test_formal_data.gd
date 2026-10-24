## Verifies formal CSV publication, invalid rosters, fixture isolation and complete production assembly.
extends SceneTree

var _failures: PackedStringArray = []
const Fixture = preload("res://tests/support/formal_match_fixture.gd")

## Mutates temporary CSV copies to exercise every declared roster rejection through the real loader.
func _init() -> void:
	var fixture := Fixture.new()
	_check(fixture.errors.is_empty(), "all formal data loads: " + str(fixture.errors))
	if fixture.teams == null:
		_finish()
		return
	var simulation := fixture.create()
	_check(simulation != null, "valid two-team assembly publishes a match")
	if simulation != null:
		_check(not simulation.register_player("late", Vector2.ZERO) and not simulation.register_ball(Vector2.ONE) and not simulation.register_team_attacking_goal("extra", Vector2(25, 0)), "validated formal roster and initial ball cannot be altered through registration APIs")
		var snapshot := simulation.create_snapshot()
		_check(snapshot.players.size() == 12 and snapshot.phase == MatchState.Phase.READY and snapshot.elapsed_seconds == 0.0, "twelve players wait in READY")
		_check(snapshot.ball.owner_player_id.is_empty() and snapshot.ball.position_m == Vector2.ZERO, "initial ball is free at center")
	_check(FormalMatchAssembler.new().create_match(fixture.data, fixture.teams, fixture.field, fixture.config(), "bad", 1, "home", "home") == null, "identical teams rejected")
	var copied := fixture.teams.teams
	copied.clear()
	_check(fixture.teams.teams.size() == 2, "published team collection does not alias")
	var dir := "user://formal_bad_roster"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var original_teams := FileAccess.get_file_as_string("res://resources/data/teams.csv")
	var original_roster := FileAccess.get_file_as_string("res://resources/data/team_players.csv").replace("\r\n", "\n")
	var original_positions := FileAccess.get_file_as_string("res://resources/data/formation_positions.csv")
	for kind in range(9):
		var team_text := original_teams
		var roster_text := original_roster
		var position_text := original_positions
		match kind:
			0: roster_text = roster_text.replace("home,swift_forward,6,forward\n", "")
			1: roster_text = roster_text.replace("home,steady_keeper,1,keeper", "home,formal_player_08,1,keeper")
			2: roster_text = roster_text.replace("home,iron_guard,2,back_left", "home,formal_player_09,2,back_left").replace("away,formal_player_09,1,keeper", "away,iron_guard,1,keeper")
			3: roster_text = roster_text.replace("away,formal_player_04,2,back_left", "away,iron_guard,2,back_left")
			4: position_text = position_text.replace("keeper,-23,0", "keeper,-100,0")
			5: roster_text = roster_text.replace("home,swift_forward,6,forward", "missing,swift_forward,6,forward")
			6: roster_text = roster_text.replace("home,swift_forward,6,forward", "home,unknown_player,6,forward")
			7: roster_text = roster_text.replace("home,swift_forward,6,forward", "home,swift_forward,5,forward")
			8: roster_text = roster_text.replace("home,swift_forward,6,forward", "home,swift_forward,6,unknown_position")
		_write(dir.path_join("teams.csv"), team_text)
		_write(dir.path_join("team_players.csv"), roster_text)
		_write(dir.path_join("formation_positions.csv"), position_text)
		var repository := TeamDataRepository.new()
		_check(not repository.load_all(dir, fixture.data, fixture.field), "invalid roster rejected: %d" % kind)
		_check(repository.teams.is_empty() and repository.team_players.is_empty() and not repository.errors.is_empty(), "invalid tables publish no partial roster")
	_write(dir.path_join("teams.csv"), original_teams.replace("one_two_two_one,-1", "one_two_two_one,1"))
	_write(dir.path_join("team_players.csv"), original_roster)
	_write(dir.path_join("formation_positions.csv"), original_positions)
	var same_direction := TeamDataRepository.new()
	_check(same_direction.load_all(dir, fixture.data, fixture.field), "individual teams can load independently of match selection")
	_check(FormalMatchAssembler.new().create_match(fixture.data, same_direction, fixture.field, fixture.config(), "bad", 1, "home", "away") == null, "same attack direction rejected at assembly")
	for file in ["teams.csv", "team_players.csv", "formation_positions.csv"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	_finish()

## Writes fixture-only input, never changing any production CSV.
func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

## Aggregates independent static validation failures.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

## Exits once after all invalid data paths have been inspected.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print("Formal data failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)
