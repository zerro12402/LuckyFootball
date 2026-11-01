## Shared non-production fixture; real CSV and production assembly remain authoritative.
extends RefCounted

var data := DataRepository.new()
var teams: TeamDataRepository
var field: FieldDefinition
var errors: PackedStringArray = []

## Loads the complete production roster once for deterministic scenario construction.
func _init() -> void:
	if not data.load_all():
		errors = data.last_errors
		return
	field = data.get_field_by_id("demo_field")
	teams = data.load_formal_teams()
	if teams == null:
		errors = data.last_errors

## Uses a temporary CSV override so duration follows the same parser and validation as production.
func config(duration: float = 180.0) -> MatchConfigDefinition:
	var text := FileAccess.get_file_as_string("res://resources/data/match_configs.csv")
	var file := FileAccess.open("user://formal_fixture_config.csv", FileAccess.WRITE)
	file.store_string(text.replace("match_duration_seconds,180.0", "match_duration_seconds," + str(duration)))
	file.close()
	var parsed := MatchConfigDataRepository.new().load_from_csv("user://formal_fixture_config.csv")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://formal_fixture_config.csv"))
	return parsed.configs[0] if parsed.is_success else null

## Every scenario receives a new instance/RNG and passes through complete production validation.
func create(duration: float = 180.0, id: String = "fixture_match", seed_value: int = 42,
		use_kickoff: bool = false) -> MatchSimulation:
	return FormalMatchAssembler.new().create_match(data, teams, field, config(duration), id, seed_value, "home", "away", use_kickoff)


## Places a genuinely moving ball whose first whole-ball crossing is at an analytically known time.
func launch_boundary(simulation: MatchSimulation, at: float, goal: bool = true,
		shot: bool = true, left: bool = false) -> void:
	var config_value := simulation._match_config
	var direction := Vector2.LEFT if left else Vector2.RIGHT
	if not goal:
		direction = Vector2.UP
	var distance := 20.0 * at
	if shot:
		distance -= 0.5 * config_value.shot_ground_deceleration_mps2 * at * at
	var edge := field.length_m * 0.5 + config_value.ball_radius_m if goal else field.width_m * 0.5 + config_value.ball_radius_m
	var point := direction * (edge - distance)
	var ball := simulation._ball_runtime_system
	ball.reset_ball(point)
	if shot:
		ball.state._launch_shot(point, direction * 20.0, 100.0, 0.05)
		ball._shot_source = BallShotSource.new("swift_forward", "home", 84, 1)
		ball._shot_context = ShotFlightContext.new(ball._shot_source)
	else:
		ball.state._launch_clearance(point, direction * 20.0, 100.0, 0.05, 0.0)
	# Score attribution must not depend on the last touching team.
	ball._last_kicker_id = "formal_player_08"
