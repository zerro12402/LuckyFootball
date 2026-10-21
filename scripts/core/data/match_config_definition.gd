## Holds validated, read-only match rules loaded from a versioned CSV preset.
class_name MatchConfigDefinition
extends RefCounted

var header_contact_radius_m: float:
	get: return _header_contact_radius_m
var header_min_contact_height_m: float:
	get: return _header_min_contact_height_m
var header_reach_height_m: float:
	get: return _header_reach_height_m
var header_simultaneous_window_seconds: float:
	get: return _header_simultaneous_window_seconds
var header_strength_weight: float:
	get: return _header_strength_weight
var header_technique_weight: float:
	get: return _header_technique_weight
var header_shot_speed_mps: float:
	get: return _header_shot_speed_mps
var header_shot_apex_height_m: float:
	get: return _header_shot_apex_height_m
var header_clear_speed_mps: float:
	get: return _header_clear_speed_mps
var header_clear_apex_height_m: float:
	get: return _header_clear_apex_height_m
var header_first_frame_seconds: float:
	get: return _header_first_frame_seconds
var header_second_frame_seconds: float:
	get: return _header_second_frame_seconds

var _header_contact_radius_m: float
var _header_min_contact_height_m: float
var _header_reach_height_m: float
var _header_simultaneous_window_seconds: float
var _header_strength_weight: float
var _header_technique_weight: float
var _header_shot_speed_mps: float
var _header_shot_apex_height_m: float
var _header_clear_speed_mps: float
var _header_clear_apex_height_m: float
var _header_first_frame_seconds: float
var _header_second_frame_seconds: float

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

var ball_control_max_speed_mps: float:
	get:
		return _ball_control_max_speed_mps

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

var shot_apex_height_m: float:
	get:
		return _shot_apex_height_m

var ball_radius_m: float:
	get:
		return _ball_radius_m

var jump_duration_seconds: float:
	get:
		return _jump_duration_seconds

var jump_takeoff_seconds: float:
	get:
		return _jump_takeoff_seconds

var jump_landing_seconds: float:
	get:
		return _jump_landing_seconds

var jump_apex_height_m: float:
	get:
		return _jump_apex_height_m

var ground_tackle_clearance_height_m: float:
	get:
		return _ground_tackle_clearance_height_m

var boundary_reset_delay_seconds: float:
	get:
		return _boundary_reset_delay_seconds

var goal_net_back_restitution: float:
	get:
		return _goal_net_back_restitution

var goal_net_side_restitution: float:
	get:
		return _goal_net_side_restitution

var goal_net_tangent_retention: float:
	get:
		return _goal_net_tangent_retention

var goal_net_stop_speed_mps: float:
	get:
		return _goal_net_stop_speed_mps

var goal_net_max_motion_seconds: float:
	get:
		return _goal_net_max_motion_seconds

var tackle_range_m: float:
	get:
		return _tackle_range_m

var tackle_min_facing_dot: float:
	get:
		return _tackle_min_facing_dot

var tackle_windup_seconds: float:
	get:
		return _tackle_windup_seconds

var tackle_recovery_seconds: float:
	get:
		return _tackle_recovery_seconds

var tackle_action_duration_seconds: float:
	get:
		return _tackle_action_duration_seconds

var tackle_cooldown_seconds: float:
	get:
		return _tackle_cooldown_seconds

var tackle_hit_stun_seconds: float:
	get:
		return _tackle_hit_stun_seconds

var tackle_lunge_distance_m: float:
	get:
		return _tackle_lunge_distance_m

var knockdown_range_m: float:
	get:
		return _knockdown_range_m

var knockdown_min_facing_dot: float:
	get:
		return _knockdown_min_facing_dot

var knockdown_windup_seconds: float:
	get:
		return _knockdown_windup_seconds

var knockdown_recovery_seconds: float:
	get:
		return _knockdown_recovery_seconds

var knockdown_action_duration_seconds: float:
	get:
		return _knockdown_action_duration_seconds

var knockdown_cooldown_seconds: float:
	get:
		return _knockdown_cooldown_seconds

var knockdown_lunge_distance_m: float:
	get:
		return _knockdown_lunge_distance_m

var knockdown_jump_height_m: float:
	get:
		return _knockdown_jump_height_m

var knockdown_hit_window_start_seconds: float:
	get:
		return _knockdown_hit_window_start_seconds

var knockdown_hit_window_end_seconds: float:
	get:
		return _knockdown_hit_window_end_seconds

var knockdown_knockback_duration_seconds: float:
	get:
		return _knockdown_knockback_duration_seconds

var knockdown_knockback_distance_m: float:
	get:
		return _knockdown_knockback_distance_m

var knockdown_landing_animation_seconds: float:
	get:
		return _knockdown_landing_animation_seconds

var knockdown_crouch_hold_seconds: float:
	get:
		return _knockdown_crouch_hold_seconds

var knockdown_down_seconds: float:
	get:
		return _knockdown_down_seconds

var knockdown_get_up_seconds: float:
	get:
		return _knockdown_get_up_seconds

var _knockdown_range_m: float
var _knockdown_min_facing_dot: float
var _knockdown_windup_seconds: float
var _knockdown_recovery_seconds: float
var _knockdown_action_duration_seconds: float
var _knockdown_cooldown_seconds: float
var _knockdown_lunge_distance_m: float
var _knockdown_jump_height_m: float
var _knockdown_hit_window_start_seconds: float
var _knockdown_hit_window_end_seconds: float
var _knockdown_knockback_duration_seconds: float
var _knockdown_knockback_distance_m: float
var _knockdown_landing_animation_seconds: float
var _knockdown_crouch_hold_seconds: float
var _knockdown_down_seconds: float
var _knockdown_get_up_seconds: float

var _config_id: String
var _shot_base_speed_mps: float
var _shot_min_attribute_multiplier: float
var _shot_max_attribute_multiplier: float
var _shot_ground_deceleration_mps2: float
var _shot_stop_speed_mps: float
var _ball_control_max_speed_mps: float
var _shot_windup_seconds: float
var _shot_recovery_seconds: float
var _shot_action_duration_seconds: float
var _shot_reacquire_delay_seconds: float
var _shot_apex_height_m: float
var _ball_radius_m: float
var _jump_duration_seconds: float
var _jump_takeoff_seconds: float
var _jump_landing_seconds: float
var _jump_apex_height_m: float
var _ground_tackle_clearance_height_m: float
var _boundary_reset_delay_seconds: float
var _goal_net_back_restitution: float
var _goal_net_side_restitution: float
var _goal_net_tangent_retention: float
var _goal_net_stop_speed_mps: float
var _goal_net_max_motion_seconds: float
var _tackle_range_m: float
var _tackle_min_facing_dot: float
var _tackle_windup_seconds: float
var _tackle_recovery_seconds: float
var _tackle_action_duration_seconds: float
var _tackle_cooldown_seconds: float
var _tackle_hit_stun_seconds: float
var _tackle_lunge_distance_m: float



## Rejects impossible rule values before any match uses the definition.
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
	new_shot_apex_height_m: float,
	new_ball_radius_m: float,
	new_boundary_reset_delay_seconds: float,
	new_goal_net_back_restitution: float,
	new_goal_net_side_restitution: float,
	new_goal_net_tangent_retention: float,
	new_goal_net_stop_speed_mps: float,
	new_goal_net_max_motion_seconds: float,
	new_tackle_range_m: float,
	new_tackle_min_facing_dot: float,
	new_tackle_windup_seconds: float,
	new_tackle_recovery_seconds: float,
	new_tackle_action_duration_seconds: float,
	new_tackle_cooldown_seconds: float,
	new_tackle_hit_stun_seconds: float,
	new_tackle_lunge_distance_m: float,
	new_knockdown_range_m: float,
	new_knockdown_min_facing_dot: float,
	new_knockdown_windup_seconds: float,
	new_knockdown_recovery_seconds: float,
	new_knockdown_action_duration_seconds: float,
	new_knockdown_cooldown_seconds: float,
	new_knockdown_lunge_distance_m: float,
	new_knockdown_jump_height_m: float,
	new_knockdown_down_seconds: float,
	new_knockdown_get_up_seconds: float,
	new_knockdown_landing_animation_seconds: float,
	new_knockdown_crouch_hold_seconds: float,
	new_knockdown_hit_window_start_seconds: float,
	new_knockdown_hit_window_end_seconds: float,
	new_knockdown_knockback_distance_m: float,
	new_knockdown_knockback_duration_seconds: float,
	new_ball_control_max_speed_mps: float,
	new_jump_duration_seconds: float,
	new_jump_takeoff_seconds: float,
	new_jump_landing_seconds: float,
	new_jump_apex_height_m: float,
	new_ground_tackle_clearance_height_m: float,
	new_header_contact_radius_m: float = 0.75,
	new_header_min_contact_height_m: float = 0.3,
	new_header_reach_height_m: float = 1.9,
	new_header_simultaneous_window_seconds: float = 0.05,
	new_header_strength_weight: float = 0.6,
	new_header_technique_weight: float = 0.4,
	new_header_shot_speed_mps: float = 16.0,
	new_header_shot_apex_height_m: float = 0.65,
	new_header_clear_speed_mps: float = 12.0,
	new_header_clear_apex_height_m: float = 1.2,
	new_header_first_frame_seconds: float = 0.3,
	new_header_second_frame_seconds: float = 1.0,
) -> void:
	assert(new_header_contact_radius_m > 0.0)
	assert(new_header_min_contact_height_m > 0.2)
	assert(new_header_reach_height_m > new_header_min_contact_height_m)
	assert(new_header_simultaneous_window_seconds >= 0.0)
	assert(new_header_strength_weight >= 0.0 and new_header_technique_weight >= 0.0)
	assert(new_header_strength_weight + new_header_technique_weight > 0.0)
	assert(new_header_shot_speed_mps > new_shot_stop_speed_mps
		and new_header_clear_speed_mps > 0.0)
	assert(new_header_shot_apex_height_m > 0.0 and new_header_clear_apex_height_m > 0.0)
	assert(new_header_first_frame_seconds > 0.0 and new_header_second_frame_seconds > 0.0)
	_header_contact_radius_m = new_header_contact_radius_m
	_header_min_contact_height_m = new_header_min_contact_height_m
	_header_reach_height_m = new_header_reach_height_m
	_header_simultaneous_window_seconds = new_header_simultaneous_window_seconds
	_header_strength_weight = new_header_strength_weight
	_header_technique_weight = new_header_technique_weight
	_header_shot_speed_mps = new_header_shot_speed_mps
	_header_shot_apex_height_m = new_header_shot_apex_height_m
	_header_clear_speed_mps = new_header_clear_speed_mps
	_header_clear_apex_height_m = new_header_clear_apex_height_m
	_header_first_frame_seconds = new_header_first_frame_seconds
	_header_second_frame_seconds = new_header_second_frame_seconds
	assert(not new_config_id.is_empty(), "Match config requires an ID")
	assert(new_shot_base_speed_mps > 0.0, "Shot base speed must be positive")
	assert(new_shot_min_attribute_multiplier > 0.0, "Shot multiplier must be positive")
	assert(
		new_shot_max_attribute_multiplier >= new_shot_min_attribute_multiplier,
		"Shot multiplier range must be ordered"
	)
	assert(new_shot_ground_deceleration_mps2 > 0.0, "Shot deceleration must be positive")
	assert(new_shot_stop_speed_mps >= 0.0, "Shot stop speed cannot be negative")
	assert(new_ball_control_max_speed_mps > 0.0, "Ball control speed must be positive")
	assert(new_shot_windup_seconds > 0.0, "Shot windup must be positive")
	assert(new_shot_recovery_seconds > new_shot_windup_seconds, "Shot recovery must follow windup")
	assert(
		new_shot_action_duration_seconds > new_shot_recovery_seconds,
		"Shot duration must exceed recovery start"
	)
	assert(new_shot_reacquire_delay_seconds >= 0.0, "Shot reacquire delay cannot be negative")
	assert(new_shot_apex_height_m > 0.0, "Shot apex height must be positive")
	assert(new_ball_radius_m > 0.0, "Ball radius must be positive")
	assert(new_jump_duration_seconds > 0.0, "Jump duration must be positive")
	assert(new_jump_takeoff_seconds > 0.0, "Jump takeoff must be positive")
	assert(new_jump_landing_seconds > 0.0, "Jump landing must be positive")
	assert(
		new_jump_takeoff_seconds + new_jump_landing_seconds < new_jump_duration_seconds,
		"Jump phases must fit inside the duration"
	)
	assert(new_ground_tackle_clearance_height_m > 0.0)
	assert(new_jump_apex_height_m > new_ground_tackle_clearance_height_m)
	assert(new_boundary_reset_delay_seconds > 0.0, "Boundary reset delay must be positive")
	assert(new_ball_radius_m < 0.75, "Ball must fit inside goal depth")
	assert(new_goal_net_back_restitution >= 0.0 and new_goal_net_back_restitution <= 1.0)
	assert(new_goal_net_side_restitution >= 0.0 and new_goal_net_side_restitution <= 1.0)
	assert(new_goal_net_tangent_retention >= 0.0 and new_goal_net_tangent_retention <= 1.0)
	assert(new_goal_net_stop_speed_mps > 0.0)
	assert(new_goal_net_max_motion_seconds > 0.0)
	assert(new_tackle_range_m > 0.0)
	assert(new_tackle_min_facing_dot >= -1.0 and new_tackle_min_facing_dot <= 1.0)
	assert(new_tackle_windup_seconds > 0.0)
	assert(new_tackle_recovery_seconds > new_tackle_windup_seconds)
	assert(new_tackle_action_duration_seconds > new_tackle_recovery_seconds)
	assert(new_tackle_cooldown_seconds >= 0.0)
	assert(new_tackle_hit_stun_seconds > 0.0)
	assert(new_tackle_lunge_distance_m > 0.0)
	_config_id = new_config_id
	_shot_base_speed_mps = new_shot_base_speed_mps
	_shot_min_attribute_multiplier = new_shot_min_attribute_multiplier
	_shot_max_attribute_multiplier = new_shot_max_attribute_multiplier
	_shot_ground_deceleration_mps2 = new_shot_ground_deceleration_mps2
	_shot_stop_speed_mps = new_shot_stop_speed_mps
	_ball_control_max_speed_mps = new_ball_control_max_speed_mps
	_shot_windup_seconds = new_shot_windup_seconds
	_shot_recovery_seconds = new_shot_recovery_seconds
	_shot_action_duration_seconds = new_shot_action_duration_seconds
	_shot_reacquire_delay_seconds = new_shot_reacquire_delay_seconds
	_shot_apex_height_m = new_shot_apex_height_m
	_ball_radius_m = new_ball_radius_m
	_jump_duration_seconds = new_jump_duration_seconds
	_jump_takeoff_seconds = new_jump_takeoff_seconds
	_jump_landing_seconds = new_jump_landing_seconds
	_jump_apex_height_m = new_jump_apex_height_m
	_ground_tackle_clearance_height_m = new_ground_tackle_clearance_height_m
	_boundary_reset_delay_seconds = new_boundary_reset_delay_seconds
	_goal_net_back_restitution = new_goal_net_back_restitution
	_goal_net_side_restitution = new_goal_net_side_restitution
	_goal_net_tangent_retention = new_goal_net_tangent_retention
	_goal_net_stop_speed_mps = new_goal_net_stop_speed_mps
	_goal_net_max_motion_seconds = new_goal_net_max_motion_seconds
	_tackle_range_m = new_tackle_range_m
	_tackle_min_facing_dot = new_tackle_min_facing_dot
	_tackle_windup_seconds = new_tackle_windup_seconds
	_tackle_recovery_seconds = new_tackle_recovery_seconds
	_tackle_action_duration_seconds = new_tackle_action_duration_seconds
	_tackle_cooldown_seconds = new_tackle_cooldown_seconds
	_tackle_hit_stun_seconds = new_tackle_hit_stun_seconds
	assert(new_knockdown_range_m > 0.0)
	assert(new_knockdown_min_facing_dot >= -1.0 and new_knockdown_min_facing_dot <= 1.0)
	assert(new_knockdown_windup_seconds > 0.0)
	assert(new_knockdown_recovery_seconds > new_knockdown_windup_seconds)
	assert(new_knockdown_action_duration_seconds > new_knockdown_recovery_seconds)
	assert(new_knockdown_cooldown_seconds >= 0.0)
	assert(new_knockdown_lunge_distance_m > 0.0)
	assert(new_knockdown_jump_height_m >= 0.0)
	assert(new_knockdown_down_seconds > 0.0)
	assert(new_knockdown_get_up_seconds > 0.0)
	assert(new_knockdown_landing_animation_seconds > 0.0)
	assert(new_knockdown_crouch_hold_seconds >= 0.0)
	assert(new_knockdown_hit_window_start_seconds >= 0.0)
	assert(new_knockdown_hit_window_end_seconds > new_knockdown_hit_window_start_seconds)
	assert(new_knockdown_hit_window_end_seconds <= new_knockdown_action_duration_seconds)
	assert(new_knockdown_knockback_distance_m >= 0.0)
	assert(new_knockdown_knockback_duration_seconds > 0.0)
	assert(new_knockdown_knockback_duration_seconds <= new_knockdown_down_seconds)
	_tackle_lunge_distance_m = new_tackle_lunge_distance_m
	_knockdown_range_m = new_knockdown_range_m
	_knockdown_min_facing_dot = new_knockdown_min_facing_dot
	_knockdown_windup_seconds = new_knockdown_windup_seconds
	_knockdown_recovery_seconds = new_knockdown_recovery_seconds
	_knockdown_action_duration_seconds = new_knockdown_action_duration_seconds
	_knockdown_cooldown_seconds = new_knockdown_cooldown_seconds
	_knockdown_lunge_distance_m = new_knockdown_lunge_distance_m
	_knockdown_jump_height_m = new_knockdown_jump_height_m
	_knockdown_down_seconds = new_knockdown_down_seconds
	_knockdown_get_up_seconds = new_knockdown_get_up_seconds
	_knockdown_landing_animation_seconds = new_knockdown_landing_animation_seconds
	_knockdown_crouch_hold_seconds = new_knockdown_crouch_hold_seconds
	_knockdown_hit_window_start_seconds = new_knockdown_hit_window_start_seconds
	_knockdown_hit_window_end_seconds = new_knockdown_hit_window_end_seconds
	_knockdown_knockback_distance_m = new_knockdown_knockback_distance_m
	_knockdown_knockback_duration_seconds = new_knockdown_knockback_duration_seconds
