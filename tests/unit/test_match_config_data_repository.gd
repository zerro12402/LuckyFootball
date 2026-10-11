## Checks typed CSV match rules and transactional validation.
extends SceneTree

var _failures: PackedStringArray = []


## Runs valid, missing, malformed, and duplicate configuration cases.
func _init() -> void:
	test_valid_config_is_indexed_by_stable_id()
	test_missing_config_reports_error_without_data()
	test_invalid_header_reports_error_without_data()
	test_reordered_keys_load_by_name()
	test_missing_key_reports_error_without_data()
	test_duplicate_key_reports_error_without_data()
	test_unknown_key_reports_error_without_data()
	test_invalid_speed_reports_error_without_data()
	test_invalid_shot_height_reports_error_without_data()
	test_invalid_ball_radius_reports_error_without_data()
	test_invalid_reset_delay_reports_error_without_data()
	test_invalid_hit_stun_reports_error_without_data()
	test_invalid_lunge_distance_reports_error_without_data()
	test_non_ascii_id_reports_error_without_data()
	test_duplicate_id_reports_error_without_data()
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


## Reads the production row through both the parser and the aggregate repository.
func test_valid_config_is_indexed_by_stable_id() -> void:
	var result := MatchConfigDataRepository.new().load_from_csv(
		"res://resources/data/match_configs.csv")
	_expect(result.is_success, "Valid match config CSV did not load")
	_expect(result.configs.size() == 1, "Expected one typed match config")
	var repository := DataRepository.new()
	_expect(repository.load_all(), "DataRepository did not load match config")
	var config := repository.get_match_config_by_id("demo_match")
	_expect(config != null, "Match config ID lookup failed")
	if config != null:
		_expect(is_equal_approx(config.shot_base_speed_mps, 20.0),
			"Shot speed was parsed incorrectly")
		_expect(is_equal_approx(config.shot_windup_seconds, 0.2),
			"Shot windup was parsed incorrectly")
		_expect(is_equal_approx(config.shot_apex_height_m, 0.75),
			"Shot apex height was parsed incorrectly")
		_expect(is_equal_approx(config.ball_radius_m, 0.55),
			"Ball radius was parsed incorrectly")
		_expect(is_equal_approx(config.boundary_reset_delay_seconds, 2.0),
			"Boundary reset delay was parsed incorrectly")
		_expect(is_equal_approx(config.tackle_hit_stun_seconds, 1.0),
			"Tackle hit stun was parsed incorrectly")
		_expect(is_equal_approx(config.tackle_action_duration_seconds, 1.0),
			"Tackle action duration was parsed incorrectly")
		_expect(is_equal_approx(config.tackle_lunge_distance_m, 1.0),
			"Tackle lunge distance was parsed incorrectly")
	_expect(repository.get_match_config_by_id("unknown") == null,
		"Unknown match config ID resolved")


## Rejects a missing required table with an explicit diagnostic.
func test_missing_config_reports_error_without_data() -> void:
	_expect_failure("missing_match_configs.csv")


## Rejects an incompatible CSV schema before reading rows.
func test_invalid_header_reports_error_without_data() -> void:
	_expect_failure("match_configs_invalid_header.csv")


## Confirms parameter rows can be moved without changing their meanings.
func test_reordered_keys_load_by_name() -> void:
	var result := MatchConfigDataRepository.new().load_from_csv(
		"res://tests/fixtures/match_configs_reordered_keys.csv")
	_expect(result.is_success, "Reordered match config keys did not load")
	_expect(result.configs.size() == 1, "Reordered keys lost the preset")
	if not result.configs.is_empty():
		_expect(is_equal_approx(result.configs[0].shot_base_speed_mps, 20.0),
			"Reordered shot speed was parsed incorrectly")
		_expect(is_equal_approx(result.configs[0].tackle_lunge_distance_m, 1.0),
			"Reordered tackle distance was parsed incorrectly")


## Requires every rule key in each preset.
func test_missing_key_reports_error_without_data() -> void:
	_expect_failure("match_configs_missing_key.csv")


## Rejects a repeated parameter instead of silently overriding it.
func test_duplicate_key_reports_error_without_data() -> void:
	_expect_failure("match_configs_duplicate_key.csv")


## Rejects misspelled or unsupported parameter names.
func test_unknown_key_reports_error_without_data() -> void:
	_expect_failure("match_configs_unknown_key.csv")


## Rejects negative shot speed as an invalid rule value.
func test_invalid_speed_reports_error_without_data() -> void:
	_expect_failure("match_configs_invalid_speed.csv")


## Rejects a nonpositive fixed shot apex.
func test_invalid_shot_height_reports_error_without_data() -> void:
	_expect_failure("match_configs_invalid_shot_height.csv")


## Rejects a nonpositive effective ball radius.
func test_invalid_ball_radius_reports_error_without_data() -> void:
	_expect_failure("match_configs_invalid_ball_radius.csv")


## Rejects zero seconds because result and reset must occupy separate steps.
func test_invalid_reset_delay_reports_error_without_data() -> void:
	_expect_failure("match_configs_invalid_reset_delay.csv")


## Rejects zero seconds so a successful tackle always has a visible hit reaction.
func test_invalid_hit_stun_reports_error_without_data() -> void:
	_expect_failure("match_configs_invalid_hit_stun.csv")


## Rejects a nonpositive lunge distance before constructing match rules.
func test_invalid_lunge_distance_reports_error_without_data() -> void:
	_expect_failure("match_configs_invalid_lunge_distance.csv")


## Rejects IDs that cannot be used as stable lowercase ASCII keys.
func test_non_ascii_id_reports_error_without_data() -> void:
	_expect_failure("match_configs_invalid_id.csv")


## Rejects duplicate IDs and discards the otherwise valid first row.
func test_duplicate_id_reports_error_without_data() -> void:
	_expect_failure("match_configs_duplicate_id.csv")


## Ensures malformed input never exposes a partial configuration set.
func _expect_failure(file_name: String) -> void:
	var result := MatchConfigDataRepository.new().load_from_csv(
		"res://tests/fixtures".path_join(file_name))
	_expect(not result.is_success, "Invalid config should fail: " + file_name)
	_expect(result.configs.is_empty(), "Invalid config leaked rows: " + file_name)
	_expect(not result.errors.is_empty(), "Invalid config lacks error: " + file_name)


## Collects all failures before exiting with one process status.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
