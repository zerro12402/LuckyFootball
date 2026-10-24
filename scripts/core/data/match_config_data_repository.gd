## Parses match_configs.csv into typed rules without leaking partial results.
class_name MatchConfigDataRepository
extends RefCounted

const CSV_HEADERS: Array[String] = ["key", "value", "comment"]
const OPTIONAL_DEFAULTS := {
	"melee_dodge_attack_advantage": 20.0,
	"melee_dodge_probability_scale": 18.0,
	"melee_dodge_probability_min": 0.1,
	"melee_dodge_probability_max": 0.9,
	"melee_strength_auto_win_gap": 20,
	"shot_contest_free_distance_m": 5.0,
	"shot_contest_distance_scale_m": 15.0,
	"shot_contest_knockdown_retention": 0.85,
	"keeper_contest_probability_scale": 5.0,
	"keeper_contest_shot_win_min": 0.1,
	"keeper_contest_shot_win_max": 0.9,
	"shot_miss_probability_at_1": 0.45,
	"shot_miss_probability_at_100": 0.05,
	"shot_miss_margin_min_m": 0.2,
	"shot_miss_margin_max_m": 1.0,
	"tackle_start_range_m": 1.8,
	"tackle_probability_scale": 18.0,
	"tackle_probability_min": 0.1,
	"tackle_probability_max": 0.9,
	"player_speed_at_100_mps": 5.0,
	"shot_aim_width_fraction": 0.25,
	"shot_aim_goal_width_m": 4.0,
	"keeper_save_probability": 0.5,
	"keeper_action_duration_seconds": 1.2,
	"keeper_window_start_seconds": 0.0,
	"keeper_window_end_seconds": 1.1,
	"keeper_hand_lateral_m": 1.0,
	"keeper_hand_forward_m": 0.45,
	"keeper_hand_height_m": 0.8,
	"keeper_contact_radius_m": 2.0,
	"keeper_contact_height_m": 2.4,

	"ball_impact_knockback_distance_m": 1.0,
	"ball_impact_knockback_duration_seconds": 0.6,
	"ball_impact_knockback_apex_height_m": 0.6,
	"ball_impact_min_speed_mps": 8.0,
	"ball_impact_body_radius_m": 0.35,
	"ball_impact_body_height_m": 1.6,
	"ball_impact_normal_retention": 0.6,
	"ball_impact_tangent_retention": 0.8,
	"ball_impact_rebound_apex_height_m": 0.25,
	"header_contact_radius_m": 0.75,
	"header_min_contact_height_m": 0.3,
	"header_reach_height_m": 1.9,
	"header_simultaneous_window_seconds": 0.05,
	"header_strength_weight": 0.6,
	"header_technique_weight": 0.4,
	"header_shot_speed_mps": 16.0,
	"header_shot_apex_height_m": 0.65,
	"header_clear_speed_mps": 12.0,
	"header_clear_apex_height_m": 1.2,
	"header_first_frame_seconds": 0.3,
	"header_second_frame_seconds": 1.0,
}
const REQUIRED_KEYS: Array[String] = [
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
	"ball_radius_m",
	"boundary_reset_delay_seconds",
	"goal_net_back_restitution",
	"goal_net_side_restitution",
	"goal_net_tangent_retention",
	"goal_net_stop_speed_mps",
	"goal_net_max_motion_seconds",
	"tackle_range_m",
	"tackle_min_facing_dot",
	"tackle_windup_seconds",
	"tackle_recovery_seconds",
	"tackle_action_duration_seconds",
	"tackle_cooldown_seconds",
	"tackle_hit_stun_seconds",
	"tackle_lunge_distance_m",
	"knockdown_range_m",
	"knockdown_min_facing_dot",
	"knockdown_windup_seconds",
	"knockdown_recovery_seconds",
	"knockdown_action_duration_seconds",
	"knockdown_cooldown_seconds",
	"knockdown_lunge_distance_m",
	"knockdown_jump_height_m",
	"knockdown_down_seconds",
	"knockdown_get_up_seconds",
	"knockdown_landing_animation_seconds",
	"knockdown_crouch_hold_seconds",
	"knockdown_hit_window_start_seconds",
	"knockdown_hit_window_end_seconds",
	"knockdown_knockback_distance_m",
	"knockdown_knockback_duration_seconds",
	"ball_control_max_speed_mps",
	"jump_duration_seconds",
	"jump_takeoff_seconds",
	"jump_landing_seconds",
	"jump_apex_height_m",
	"ground_tackle_clearance_height_m",
]


## Validates every key/value block before exposing any configuration definitions.
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
	var config_values: Dictionary[String, String] = {}
	var config_id := ""
	var config_row := 0
	var has_config := false
	var row_number := 1
	while not csv_file.eof_reached():
		var columns := csv_file.get_csv_line()
		row_number += 1
		if columns.size() == 1 and columns[0].strip_edges().is_empty():
			continue
		if columns.size() != CSV_HEADERS.size():
			result._add_error("Match config row %d has an invalid column count" % row_number)
			continue
		var key := columns[0].strip_edges()
		var raw_value := columns[1].strip_edges()
		if key == "config_id":
			if has_config:
				var previous_config := _parse_config(
					config_id, config_values, config_row, known_ids, result)
				if previous_config != null:
					parsed_configs.append(previous_config)
			config_id = raw_value
			config_values = {}
			config_row = row_number
			has_config = true
		elif not has_config:
			result._add_error("Match config row %d appears before config_id" % row_number)
		elif not REQUIRED_KEYS.has(key) and not OPTIONAL_DEFAULTS.has(key):
			result._add_error("Match config row %d has unknown key %s" % [row_number, key])
		elif config_values.has(key):
			result._add_error("Match config row %d has duplicate key %s" % [row_number, key])
		else:
			config_values[key] = raw_value
	if has_config:
		var last_config := _parse_config(
			config_id, config_values, config_row, known_ids, result)
		if last_config != null:
			parsed_configs.append(last_config)
	if parsed_configs.is_empty():
		result._add_error("Match config CSV requires at least one valid config_id block")
	if result.is_success:
		result._replace_configs(parsed_configs)
	return result


## Checks only the three structural columns; parameter rows may be reordered freely.
func _has_required_headers(headers: PackedStringArray) -> bool:
	if headers.size() != CSV_HEADERS.size():
		return false
	for index in range(CSV_HEADERS.size()):
		if headers[index].strip_edges() != CSV_HEADERS[index]:
			return false
	return true


## Builds one preset by key, rejecting missing values before numeric validation.
func _parse_config(
	config_id: String,
	config_values: Dictionary[String, String],
	row_number: int,
	known_ids: Dictionary[String, bool],
	result: MatchConfigDataLoadResult,
) -> MatchConfigDefinition:
	if not _is_valid_ascii_id(config_id) or known_ids.has(config_id):
		result._add_error("Match config row %d has an invalid or duplicate config_id" % row_number)
		return null
	known_ids[config_id] = true
	var values: Array[float] = []
	for key in REQUIRED_KEYS:
		if not config_values.has(key):
			result._add_error("Match config row %d is missing %s" % [row_number, key])
			return null
		var raw_value := config_values[key]
		if not raw_value.is_valid_float():
			result._add_error("Match config row %d has invalid %s" % [row_number, key])
			return null
		var parsed_value := raw_value.to_float()
		if not is_finite(parsed_value):
			result._add_error("Match config row %d has non-finite %s" % [row_number, key])
			return null
		values.append(parsed_value)
	if (
		values[0] <= 0.0 or values[1] <= 0.0 or values[2] < values[1]
		or values[3] <= 0.0 or values[4] < 0.0 or values[5] <= 0.0
		or values[6] <= values[5] or values[7] <= values[6] or values[8] < 0.0
		or values[9] <= 0.0 or values[10] <= 0.0
	):
		result._add_error("Match config row %d has invalid match parameters" % row_number)
		return null
	if values[11] <= 0.0:
		result._add_error(
			"Match config row %d has invalid boundary_reset_delay_seconds" % row_number
		)
		return null
	if (values[10] >= 0.75 or values[12] < 0.0 or values[12] > 1.0
		or values[13] < 0.0 or values[13] > 1.0 or values[14] < 0.0
		or values[14] > 1.0 or values[15] <= 0.0 or values[16] <= 0.0):
		result._add_error("Match config row %d has invalid goal net parameters" % row_number)
		return null
	if (values[17] <= 0.0 or values[18] < -1.0 or values[18] > 1.0
		or values[19] <= 0.0 or values[20] <= values[19]
		or values[21] <= values[20] or values[22] < 0.0
		or values[23] <= 0.0 or values[24] <= 0.0):
		result._add_error("Match config row %d has invalid tackle parameters" % row_number)
		return null
	if (values[25] <= 0.0 or values[26] < -1.0 or values[26] > 1.0
		or values[27] <= 0.0 or values[28] <= values[27]
		or values[29] <= values[28] or values[30] < 0.0
		or values[31] <= 0.0 or values[32] < 0.0
		or values[33] <= 0.0 or values[34] <= 0.0
		or values[35] <= 0.0 or values[36] < 0.0
		or values[37] < 0.0 or values[38] <= values[37]
		or values[38] > values[29] or values[39] < 0.0
		or values[40] <= 0.0 or values[40] > values[33]):
		result._add_error("Match config row %d has invalid knockdown parameters" % row_number)
		return null
	if values[41] <= 0.0:
		result._add_error("Match config row %d has invalid ball_control_max_speed_mps" % row_number)
		return null
	if (
		values[42] <= 0.0 or values[43] <= 0.0 or values[44] <= 0.0
		or values[43] + values[44] >= values[42]
		or values[46] <= 0.0 or values[45] <= values[46]
	):
		result._add_error("Match config row %d has invalid jump parameters" % row_number)
		return null
	var header_values: Dictionary[String, float] = {}
	for key in OPTIONAL_DEFAULTS:
		var value: float = OPTIONAL_DEFAULTS[key]
		if config_values.has(key):
			var raw_header_value := config_values[key]
			if not raw_header_value.is_valid_float() or not is_finite(raw_header_value.to_float()):
				result._add_error("Match config row %d has invalid %s" % [row_number, key])
				return null
			value = raw_header_value.to_float()
		header_values[key] = value
	if (header_values["melee_dodge_attack_advantage"] < 0.0
		or header_values["melee_dodge_probability_scale"] <= 0.0
		or header_values["melee_dodge_probability_min"] < 0.0
		or header_values["melee_dodge_probability_max"] > 1.0
		or header_values["melee_dodge_probability_min"] > header_values["melee_dodge_probability_max"]
		or header_values["melee_strength_auto_win_gap"] <= 0.0
		or header_values["melee_strength_auto_win_gap"] != floorf(header_values["melee_strength_auto_win_gap"])):
		result._add_error("Match config row %d has invalid melee contest parameters" % row_number)
		return null
	if (header_values["shot_contest_free_distance_m"] < 0.0
		or header_values["shot_contest_distance_scale_m"] <= 0.0
		or header_values["shot_contest_knockdown_retention"] <= 0.0
		or header_values["shot_contest_knockdown_retention"] > 1.0
		or header_values["keeper_contest_probability_scale"] <= 0.0
		or header_values["keeper_contest_shot_win_min"] < 0.0
		or header_values["keeper_contest_shot_win_max"] > 1.0
		or header_values["keeper_contest_shot_win_min"] > header_values["keeper_contest_shot_win_max"]):
		result._add_error("Match config row %d has invalid keeper contest parameters" % row_number)
		return null
	if (header_values["shot_miss_probability_at_100"] < 0.0
		or header_values["shot_miss_probability_at_1"] > 1.0
		or header_values["shot_miss_probability_at_100"] > header_values["shot_miss_probability_at_1"]
		or header_values["shot_miss_margin_min_m"] <= 0.0
		or header_values["shot_miss_margin_max_m"] < header_values["shot_miss_margin_min_m"]):
		result._add_error("Match config row %d has invalid shot miss parameters" % row_number)
		return null
	if header_values["player_speed_at_100_mps"] <= 0.0:
		result._add_error("Match config row %d has invalid player_speed_at_100_mps" % row_number)
		return null
	if header_values["tackle_start_range_m"] < values[17]:
		result._add_error("Match config row %d has invalid tackle_start_range_m" % row_number)
		return null
	if (header_values["tackle_probability_scale"] <= 0.0
		or header_values["tackle_probability_min"] < 0.0
		or header_values["tackle_probability_max"] > 1.0
		or header_values["tackle_probability_min"] > header_values["tackle_probability_max"]):
		result._add_error("Match config row %d has invalid tackle probability parameters" % row_number)
		return null
	if (header_values["ball_impact_min_speed_mps"] <= 0.0
		or header_values["ball_impact_knockback_distance_m"] < 0.0
		or header_values["ball_impact_knockback_apex_height_m"] < 0.0
		or header_values["ball_impact_knockback_duration_seconds"] <= 0.0
		or header_values["ball_impact_knockback_duration_seconds"] > values[33]
		or header_values["ball_impact_body_radius_m"] <= 0.0
		or header_values["ball_impact_body_height_m"] <= 0.0
		or header_values["ball_impact_rebound_apex_height_m"] <= 0.0
		or header_values["ball_impact_normal_retention"] <= 0.0
		or header_values["ball_impact_normal_retention"] > 1.0
		or header_values["ball_impact_tangent_retention"] < 0.0
		or header_values["ball_impact_tangent_retention"] > 1.0):
		result._add_error("Match config row %d has invalid ball impact parameters" % row_number)
		return null
	if (header_values["header_contact_radius_m"] <= 0.0
		or header_values["header_min_contact_height_m"] <= 0.2
		or header_values["header_reach_height_m"] <= header_values["header_min_contact_height_m"]
		or header_values["header_simultaneous_window_seconds"] < 0.0
		or header_values["header_strength_weight"] < 0.0
		or header_values["header_technique_weight"] < 0.0
		or header_values["header_strength_weight"] + header_values["header_technique_weight"] <= 0.0
		or header_values["header_shot_speed_mps"] <= values[4]
		or header_values["header_shot_apex_height_m"] <= 0.0
		or header_values["header_clear_speed_mps"] <= 0.0
		or header_values["header_clear_apex_height_m"] <= 0.0
		or header_values["header_first_frame_seconds"] <= 0.0
		or header_values["header_second_frame_seconds"] <= 0.0):
		result._add_error("Match config row %d has invalid header parameters" % row_number)
		return null
	if (header_values["shot_aim_width_fraction"] <= 0.0
		or header_values["shot_aim_width_fraction"] >= 0.5
		or header_values["shot_aim_goal_width_m"] <= values[10] * 2.0
		or header_values["keeper_save_probability"] < 0.0
		or header_values["keeper_save_probability"] > 1.0
		or header_values["keeper_action_duration_seconds"] <= 0.0
		or header_values["keeper_window_start_seconds"] < 0.0
		or header_values["keeper_window_end_seconds"] <= header_values["keeper_window_start_seconds"]
		or header_values["keeper_window_end_seconds"] > header_values["keeper_action_duration_seconds"]
		or header_values["keeper_hand_lateral_m"] < 0.0
		or header_values["keeper_hand_forward_m"] < 0.0
		or header_values["keeper_hand_height_m"] < 0.0
		or header_values["keeper_contact_radius_m"] <= 0.0
		or header_values["keeper_contact_height_m"] <= 0.0):
		result._add_error("Match config row %d has invalid goalkeeper parameters" % row_number)
		return null
	return MatchConfigDefinition.new(
		# Optional defaults preserve older fixtures; production presets declare every value.
		config_id, values[0], values[1], values[2], values[3],
		values[4], values[5], values[6], values[7], values[8], values[9], values[10],
		values[11], values[12], values[13], values[14], values[15], values[16],
		values[17], values[18], values[19], values[20], values[21], values[22],
		values[23], values[24],
		values[25], values[26], values[27], values[28], values[29],
		values[30], values[31], values[32], values[33], values[34],
		values[35], values[36], values[37], values[38], values[39], values[40],
		values[41], values[42], values[43], values[44], values[45], values[46],
		header_values["header_contact_radius_m"],
		header_values["header_min_contact_height_m"],
		header_values["header_reach_height_m"],
		header_values["header_simultaneous_window_seconds"],
		header_values["header_strength_weight"],
		header_values["header_technique_weight"],
		header_values["header_shot_speed_mps"],
		header_values["header_shot_apex_height_m"],
		header_values["header_clear_speed_mps"],
		header_values["header_clear_apex_height_m"],
		header_values["header_first_frame_seconds"],
		header_values["header_second_frame_seconds"],
		header_values["ball_impact_min_speed_mps"],
		header_values["ball_impact_body_radius_m"],
		header_values["ball_impact_body_height_m"],
		header_values["ball_impact_normal_retention"],
		header_values["ball_impact_tangent_retention"],
		header_values["ball_impact_rebound_apex_height_m"],
		header_values["ball_impact_knockback_distance_m"],
		header_values["ball_impact_knockback_duration_seconds"],
		header_values["ball_impact_knockback_apex_height_m"],
		header_values["shot_aim_width_fraction"],
		header_values["shot_aim_goal_width_m"],
		header_values["keeper_save_probability"],
		header_values["keeper_action_duration_seconds"],
		header_values["keeper_window_start_seconds"],
		header_values["keeper_window_end_seconds"],
		header_values["keeper_hand_lateral_m"],
		header_values["keeper_hand_forward_m"],
		header_values["keeper_hand_height_m"],
		header_values["keeper_contact_radius_m"],
		header_values["keeper_contact_height_m"],
		header_values["player_speed_at_100_mps"],
		header_values["tackle_probability_scale"],
		header_values["tackle_probability_min"],
		header_values["tackle_probability_max"],
		header_values["tackle_start_range_m"],
		header_values["shot_miss_probability_at_1"],
		header_values["shot_miss_probability_at_100"],
		header_values["shot_miss_margin_min_m"],
		header_values["shot_miss_margin_max_m"],
		header_values["shot_contest_free_distance_m"],
		header_values["shot_contest_distance_scale_m"],
		header_values["shot_contest_knockdown_retention"],
		header_values["keeper_contest_probability_scale"],
		header_values["keeper_contest_shot_win_min"],
		header_values["keeper_contest_shot_win_max"],
		header_values["melee_dodge_attack_advantage"],
		header_values["melee_dodge_probability_scale"],
		header_values["melee_dodge_probability_min"],
		header_values["melee_dodge_probability_max"],
		int(header_values["melee_strength_auto_win_gap"]),
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
