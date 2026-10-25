## Loads AI numeric CSV transactionally with required keys and relational range validation.
class_name AIConfigDataRepository
extends RefCounted

const KEYS: Array[String] = ["heartbeat_seconds", "hold_seconds", "plan_timeout_seconds", "arrival_m", "pressure_m", "pressure_exit_m", "press_pass_multiplier", "press_dribble_multiplier", "shot_distance_scale_m", "shot_min_multiplier", "attack_start_m", "role_forward_offset_m", "support_spacing_m", "handoff_advantage_seconds", "handoff_hold_seconds", "field_margin_m", "keeper_line_offset_m", "keeper_post_margin_m", "keeper_prediction_seconds", "keeper_hold_seconds", "aerial_receive_lead_seconds", "stamina_min_multiplier", "forward_hold", "forward_advance", "forward_pass", "forward_shoot", "forward_jump", "forward_support", "forward_press", "forward_tackle", "forward_attack", "forward_chase", "forward_return", "forward_save", "mid_hold", "mid_advance", "mid_pass", "mid_shoot", "mid_jump", "mid_support", "mid_press", "mid_tackle", "mid_attack", "mid_chase", "mid_return", "mid_save", "back_hold", "back_advance", "back_pass", "back_shoot", "back_jump", "back_support", "back_press", "back_tackle", "back_attack", "back_chase", "back_return", "back_save", "keeper_hold", "keeper_advance", "keeper_pass", "keeper_shoot", "keeper_jump", "keeper_support", "keeper_press", "keeper_tackle", "keeper_attack", "keeper_chase", "keeper_return", "keeper_save"]
var errors: PackedStringArray:
	get: return _errors.duplicate()
var _errors: PackedStringArray = []

## Returns no partial configuration on missing, duplicate, non-finite or invalid values.
func load_from_csv(path: String) -> AIBehaviorConfig:
	_errors.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Cannot open AI CSV: " + path)
		return null
	if file.get_csv_line() != PackedStringArray(["key", "value", "comment"]):
		_errors.append("Invalid AI CSV headers")
		return null
	var numbers: Dictionary[String, float] = {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].strip_edges().is_empty():
			continue
		if row.size() != 3:
			_errors.append("Invalid AI CSV row")
			continue
		var key := row[0].strip_edges()
		var raw := row[1].strip_edges()
		if not KEYS.has(key) or numbers.has(key) or not raw.is_valid_float():
			_errors.append("Unknown, duplicate or nonnumeric AI key: " + key)
			continue
		var amount := raw.to_float()
		if not is_finite(amount) or amount < 0.0:
			_errors.append("Invalid AI value: " + key)
			continue
		if (key.ends_with("_seconds") or key.ends_with("_m")) and amount <= 0.0:
			_errors.append("AI time/distance must be positive: " + key)
		numbers[key] = amount
	for key in KEYS:
		if not numbers.has(key):
			_errors.append("Missing AI key: " + key)
	if not _errors.is_empty():
		return null
	if numbers["pressure_exit_m"] < numbers["pressure_m"] or numbers["plan_timeout_seconds"] < numbers["hold_seconds"] \
			or numbers["shot_min_multiplier"] > 1.0 or numbers["stamina_min_multiplier"] > 1.0:
		_errors.append("Invalid AI relational ranges")
		return null
	return AIBehaviorConfig.new(numbers)
