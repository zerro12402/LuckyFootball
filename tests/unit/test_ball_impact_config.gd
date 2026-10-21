## Verifies production impact parameters are typed and invalid values are rejected atomically.
extends SceneTree

var _failures: PackedStringArray = []

## Loads CSV data and probes threshold, body dimensions and energy-retention bounds.
func _init() -> void:
	var repository := MatchConfigDataRepository.new()
	var result := repository.load_from_csv("res://resources/data/match_configs.csv")
	_check(result.is_success, "Production config must remain valid")
	var original := FileAccess.get_file_as_string("res://resources/data/match_configs.csv")
	var invalid_rows: Array[String] = [
		"ball_impact_min_speed_mps,8.0,|ball_impact_min_speed_mps,0,",
		"ball_impact_body_radius_m,0.35,|ball_impact_body_radius_m,-1,",
		"ball_impact_body_height_m,1.6,|ball_impact_body_height_m,0,",
		"ball_impact_normal_retention,0.6,|ball_impact_normal_retention,1.1,",
		"ball_impact_tangent_retention,0.8,|ball_impact_tangent_retention,-0.1,",
		"ball_impact_rebound_apex_height_m,0.25,|ball_impact_rebound_apex_height_m,0,",
		"ball_impact_knockback_distance_m,1.0,|ball_impact_knockback_distance_m,-1,",
		"ball_impact_knockback_duration_seconds,0.6,|ball_impact_knockback_duration_seconds,0,",
		"ball_impact_knockback_duration_seconds,0.6,|ball_impact_knockback_duration_seconds,2,",
		"ball_impact_knockback_apex_height_m,0.6,|ball_impact_knockback_apex_height_m,-1,",
	]
	var path := "user://invalid_ball_impact_config.csv"
	for row in invalid_rows:
		var pair := row.split("|")
		var csv := FileAccess.open(path, FileAccess.WRITE)
		csv.store_string(original.replace(pair[0], pair[1]))
		csv.close()
		var invalid := repository.load_from_csv(path)
		_check(not invalid.is_success, "Invalid impact value must fail: " + pair[1])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: ball impact config")
	quit(0 if _failures.is_empty() else 1)

## Reports invalid-config acceptance without masking other validation failures.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
