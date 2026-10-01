## Holds validated, read-only match rules loaded from a versioned CSV row.
class_name MatchConfigDefinition
extends RefCounted

var config_id: String:
	get:
		return _config_id

var shot_base_speed_mps: float:
	get:
		return _shot_base_speed_mps

var shot_min_attribute_multiplier: float:
	get:
		return _shot_min_attribute_multiplier

var shot_max_attribute_multiplier: float:
	get:
		return _shot_max_attribute_multiplier

var shot_ground_deceleration_mps2: float:
	get:
		return _shot_ground_deceleration_mps2

var shot_stop_speed_mps: float:
	get:
		return _shot_stop_speed_mps

var shot_windup_seconds: float:
	get:
		return _shot_windup_seconds

var shot_recovery_seconds: float:
	get:
		return _shot_recovery_seconds

var shot_action_duration_seconds: float:
	get:
		return _shot_action_duration_seconds

var shot_reacquire_delay_seconds: float:
	get:
		return _shot_reacquire_delay_seconds

var _config_id: String
var _shot_base_speed_mps: float
var _shot_min_attribute_multiplier: float
var _shot_max_attribute_multiplier: float
var _shot_ground_deceleration_mps2: float
var _shot_stop_speed_mps: float
var _shot_windup_seconds: float
var _shot_recovery_seconds: float
var _shot_action_duration_seconds: float
var _shot_reacquire_delay_seconds: float


## Rejects impossible timings and velocities before any match uses the definition.
func _init(
	new_config_id: String,
	new_shot_base_speed_mps: float,
	new_shot_min_attribute_multiplier: float,
	new_shot_max_attribute_multiplier: float,
	new_shot_ground_deceleration_mps2: float,
	new_shot_stop_speed_mps: float,
	new_shot_windup_seconds: float,
	new_shot_recovery_seconds: float,
	new_shot_action_duration_seconds: float,
	new_shot_reacquire_delay_seconds: float,
) -> void:
	assert(not new_config_id.is_empty(), "Match config requires an ID")
	assert(new_shot_base_speed_mps > 0.0, "Shot base speed must be positive")
	assert(new_shot_min_attribute_multiplier > 0.0, "Shot multiplier must be positive")
	assert(
		new_shot_max_attribute_multiplier >= new_shot_min_attribute_multiplier,
		"Shot multiplier range must be ordered"
	)
	assert(new_shot_ground_deceleration_mps2 > 0.0, "Shot deceleration must be positive")
	assert(new_shot_stop_speed_mps >= 0.0, "Shot stop speed cannot be negative")
	assert(new_shot_windup_seconds > 0.0, "Shot windup must be positive")
	assert(new_shot_recovery_seconds > new_shot_windup_seconds, "Shot recovery must follow windup")
	assert(
		new_shot_action_duration_seconds > new_shot_recovery_seconds,
		"Shot duration must exceed recovery start"
	)
	assert(new_shot_reacquire_delay_seconds >= 0.0, "Shot reacquire delay cannot be negative")
	_config_id = new_config_id
	_shot_base_speed_mps = new_shot_base_speed_mps
	_shot_min_attribute_multiplier = new_shot_min_attribute_multiplier
	_shot_max_attribute_multiplier = new_shot_max_attribute_multiplier
	_shot_ground_deceleration_mps2 = new_shot_ground_deceleration_mps2
	_shot_stop_speed_mps = new_shot_stop_speed_mps
	_shot_windup_seconds = new_shot_windup_seconds
	_shot_recovery_seconds = new_shot_recovery_seconds
	_shot_action_duration_seconds = new_shot_action_duration_seconds
	_shot_reacquire_delay_seconds = new_shot_reacquire_delay_seconds
