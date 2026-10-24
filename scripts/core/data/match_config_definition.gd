## Holds validated, read-only match rules loaded from a versioned CSV preset.
class_name MatchConfigDefinition
extends RefCounted

var melee_dodge_attack_advantage: float:
	get: return _melee_dodge_attack_advantage
var _melee_dodge_attack_advantage: float
var melee_dodge_probability_scale: float:
	get: return _melee_dodge_probability_scale
var _melee_dodge_probability_scale: float
var melee_dodge_probability_min: float:
	get: return _melee_dodge_probability_min
var _melee_dodge_probability_min: float
var melee_dodge_probability_max: float:
	get: return _melee_dodge_probability_max
var _melee_dodge_probability_max: float
var melee_strength_auto_win_gap: int:
	get: return _melee_strength_auto_win_gap
var _melee_strength_auto_win_gap: int


var shot_contest_free_distance_m: float:
	get: return _shot_contest_free_distance_m
var _shot_contest_free_distance_m: float
var shot_contest_distance_scale_m: float:
	get: return _shot_contest_distance_scale_m
var _shot_contest_distance_scale_m: float
var shot_contest_knockdown_retention: float:
	get: return _shot_contest_knockdown_retention
var _shot_contest_knockdown_retention: float
var keeper_contest_probability_scale: float:
	get: return _keeper_contest_probability_scale
var _keeper_contest_probability_scale: float
var keeper_contest_shot_win_min: float:
	get: return _keeper_contest_shot_win_min
var _keeper_contest_shot_win_min: float
var keeper_contest_shot_win_max: float:
	get: return _keeper_contest_shot_win_max
var _keeper_contest_shot_win_max: float

var shot_miss_probability_at_1: float:
	get: return _shot_miss_probability_at_1
var _shot_miss_probability_at_1: float
var shot_miss_probability_at_100: float:
	get: return _shot_miss_probability_at_100
var _shot_miss_probability_at_100: float
var shot_miss_margin_min_m: float:
	get: return _shot_miss_margin_min_m
var _shot_miss_margin_min_m: float
var shot_miss_margin_max_m: float:
	get: return _shot_miss_margin_max_m
var _shot_miss_margin_max_m: float

var player_speed_at_100_mps: float:
	get: return _player_speed_at_100_mps
var _player_speed_at_100_mps: float

var tackle_probability_scale: float:
	get: return _tackle_probability_scale
var tackle_probability_min: float:
	get: return _tackle_probability_min
var tackle_probability_max: float:
	get: return _tackle_probability_max
var _tackle_probability_scale: float
var _tackle_probability_min: float
var _tackle_probability_max: float

var tackle_start_range_m: float:
	get: return _tackle_start_range_m
var _tackle_start_range_m: float

var shot_aim_width_fraction: float:
	get: return _shot_aim_width_fraction
var _shot_aim_width_fraction: float

var shot_aim_goal_width_m: float:
	get: return _shot_aim_goal_width_m
var _shot_aim_goal_width_m: float

var keeper_save_probability: float:
	get: return _keeper_save_probability
var _keeper_save_probability: float

var keeper_action_duration_seconds: float:
	get: return _keeper_action_duration_seconds
var _keeper_action_duration_seconds: float

var keeper_window_start_seconds: float:
	get: return _keeper_window_start_seconds
var _keeper_window_start_seconds: float

var keeper_window_end_seconds: float:
	get: return _keeper_window_end_seconds
var _keeper_window_end_seconds: float

var keeper_hand_lateral_m: float:
	get: return _keeper_hand_lateral_m
var _keeper_hand_lateral_m: float

var keeper_hand_forward_m: float:
	get: return _keeper_hand_forward_m
var _keeper_hand_forward_m: float

var keeper_hand_height_m: float:
	get: return _keeper_hand_height_m
var _keeper_hand_height_m: float

var keeper_contact_radius_m: float:
	get: return _keeper_contact_radius_m
var _keeper_contact_radius_m: float

var keeper_contact_height_m: float:
	get: return _keeper_contact_height_m
var _keeper_contact_height_m: float



var ball_impact_min_speed_mps: float:
	get: return _ball_impact_min_speed_mps
var ball_impact_body_radius_m: float:
	get: return _ball_impact_body_radius_m
var ball_impact_body_height_m: float:
	get: return _ball_impact_body_height_m
var ball_impact_normal_retention: float:
	get: return _ball_impact_normal_retention
var ball_impact_tangent_retention: float:
	get: return _ball_impact_tangent_retention
var ball_impact_rebound_apex_height_m: float:
	get: return _ball_impact_rebound_apex_height_m
var ball_impact_knockback_distance_m: float:
	get: return _ball_impact_knockback_distance_m
var ball_impact_knockback_duration_seconds: float:
	get: return _ball_impact_knockback_duration_seconds
var ball_impact_knockback_apex_height_m: float:
	get: return _ball_impact_knockback_apex_height_m

var _ball_impact_min_speed_mps: float
var _ball_impact_body_radius_m: float
var _ball_impact_body_height_m: float
var _ball_impact_normal_retention: float
var _ball_impact_tangent_retention: float
var _ball_impact_rebound_apex_height_m: float
var _ball_impact_knockback_distance_m: float
var _ball_impact_knockback_duration_seconds: float
var _ball_impact_knockback_apex_height_m: float

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
	new_ball_impact_min_speed_mps: float = 8.0,
	new_ball_impact_body_radius_m: float = 0.35,
	new_ball_impact_body_height_m: float = 1.6,
	new_ball_impact_normal_retention: float = 0.6,
	new_ball_impact_tangent_retention: float = 0.8,
	new_ball_impact_rebound_apex_height_m: float = 0.25,
	new_ball_impact_knockback_distance_m: float = 1.0,
	new_ball_impact_knockback_duration_seconds: float = 0.6,
	new_ball_impact_knockback_apex_height_m: float = 0.6,
	new_shot_aim_width_fraction: float = 0.25,
	new_shot_aim_goal_width_m: float = 4.0,
	new_keeper_save_probability: float = 0.5,
	new_keeper_action_duration_seconds: float = 1.2,
	new_keeper_window_start_seconds: float = 0.0,
	new_keeper_window_end_seconds: float = 1.1,
	new_keeper_hand_lateral_m: float = 1.0,
	new_keeper_hand_forward_m: float = 0.45,
	new_keeper_hand_height_m: float = 0.8,
	new_keeper_contact_radius_m: float = 2.0,
	new_keeper_contact_height_m: float = 2.4,
	new_player_speed_at_100_mps: float = 5.0,
	new_tackle_probability_scale: float = 18.0,
	new_tackle_probability_min: float = 0.1,
	new_tackle_probability_max: float = 0.9,
	new_tackle_start_range_m: float = 1.8,
	new_shot_miss_probability_at_1: float = 0.45,
	new_shot_miss_probability_at_100: float = 0.05,
	new_shot_miss_margin_min_m: float = 0.2,
	new_shot_miss_margin_max_m: float = 1.0,
	new_shot_contest_free_distance_m: float = 5.0,
	new_shot_contest_distance_scale_m: float = 15.0,
	new_shot_contest_knockdown_retention: float = 0.85,
	new_keeper_contest_probability_scale: float = 5.0,
	new_keeper_contest_shot_win_min: float = 0.1,
	new_keeper_contest_shot_win_max: float = 0.9,
	new_melee_dodge_attack_advantage: float = 20.0,
	new_melee_dodge_probability_scale: float = 18.0,
	new_melee_dodge_probability_min: float = 0.1,
	new_melee_dodge_probability_max: float = 0.9,
	new_melee_strength_auto_win_gap: int = 20,
) -> void:
	assert(is_finite(new_melee_dodge_attack_advantage) and new_melee_dodge_attack_advantage >= 0.0)
	assert(is_finite(new_melee_dodge_probability_scale) and new_melee_dodge_probability_scale > 0.0)
	assert(is_finite(new_melee_dodge_probability_min) and is_finite(new_melee_dodge_probability_max))
	assert(new_melee_dodge_probability_min >= 0.0 and new_melee_dodge_probability_max <= 1.0
		and new_melee_dodge_probability_min <= new_melee_dodge_probability_max)
	assert(new_melee_strength_auto_win_gap > 0)
	_melee_dodge_attack_advantage = new_melee_dodge_attack_advantage
	_melee_dodge_probability_scale = new_melee_dodge_probability_scale
	_melee_dodge_probability_min = new_melee_dodge_probability_min
	_melee_dodge_probability_max = new_melee_dodge_probability_max
	_melee_strength_auto_win_gap = new_melee_strength_auto_win_gap
	assert(is_finite(new_shot_contest_free_distance_m))
	assert(is_finite(new_shot_contest_distance_scale_m))
	assert(is_finite(new_shot_contest_knockdown_retention))
	assert(is_finite(new_keeper_contest_probability_scale))
	assert(is_finite(new_keeper_contest_shot_win_min))
	assert(is_finite(new_keeper_contest_shot_win_max))
	assert(new_shot_contest_free_distance_m >= 0.0 and new_shot_contest_distance_scale_m > 0.0)
	assert(new_shot_contest_knockdown_retention > 0.0 and new_shot_contest_knockdown_retention <= 1.0)
	assert(new_keeper_contest_probability_scale > 0.0)
	assert(new_keeper_contest_shot_win_min >= 0.0 and new_keeper_contest_shot_win_max <= 1.0
		and new_keeper_contest_shot_win_min <= new_keeper_contest_shot_win_max)
	_shot_contest_free_distance_m = new_shot_contest_free_distance_m
	_shot_contest_distance_scale_m = new_shot_contest_distance_scale_m
	_shot_contest_knockdown_retention = new_shot_contest_knockdown_retention
	_keeper_contest_probability_scale = new_keeper_contest_probability_scale
	_keeper_contest_shot_win_min = new_keeper_contest_shot_win_min
	_keeper_contest_shot_win_max = new_keeper_contest_shot_win_max
	assert(is_finite(new_shot_miss_probability_at_1) and is_finite(new_shot_miss_probability_at_100))
	assert(new_shot_miss_probability_at_100 >= 0.0
		and new_shot_miss_probability_at_100 <= new_shot_miss_probability_at_1
		and new_shot_miss_probability_at_1 <= 1.0)
	assert(is_finite(new_shot_miss_margin_min_m) and is_finite(new_shot_miss_margin_max_m)
		and new_shot_miss_margin_min_m > 0.0
		and new_shot_miss_margin_max_m >= new_shot_miss_margin_min_m)
	_shot_miss_probability_at_1 = new_shot_miss_probability_at_1
	_shot_miss_probability_at_100 = new_shot_miss_probability_at_100
	_shot_miss_margin_min_m = new_shot_miss_margin_min_m
	_shot_miss_margin_max_m = new_shot_miss_margin_max_m
	assert(is_finite(new_tackle_start_range_m) and new_tackle_start_range_m >= new_tackle_range_m)
	_tackle_start_range_m = new_tackle_start_range_m
	assert(is_finite(new_tackle_probability_scale) and new_tackle_probability_scale > 0.0)
	assert(new_tackle_probability_min >= 0.0 and new_tackle_probability_max <= 1.0
		and new_tackle_probability_min <= new_tackle_probability_max)
	_tackle_probability_scale = new_tackle_probability_scale
	_tackle_probability_min = new_tackle_probability_min
	_tackle_probability_max = new_tackle_probability_max
	assert(is_finite(new_player_speed_at_100_mps) and new_player_speed_at_100_mps > 0.0)
	_player_speed_at_100_mps = new_player_speed_at_100_mps
	_shot_aim_width_fraction = new_shot_aim_width_fraction
	_shot_aim_goal_width_m = new_shot_aim_goal_width_m
	_keeper_save_probability = new_keeper_save_probability
	_keeper_action_duration_seconds = new_keeper_action_duration_seconds
	_keeper_window_start_seconds = new_keeper_window_start_seconds
	_keeper_window_end_seconds = new_keeper_window_end_seconds
	_keeper_hand_lateral_m = new_keeper_hand_lateral_m
	_keeper_hand_forward_m = new_keeper_hand_forward_m
	_keeper_hand_height_m = new_keeper_hand_height_m
	_keeper_contact_radius_m = new_keeper_contact_radius_m
	_keeper_contact_height_m = new_keeper_contact_height_m
	assert(new_ball_impact_knockback_distance_m >= 0.0)
	assert(new_ball_impact_knockback_apex_height_m >= 0.0)
	assert(new_ball_impact_knockback_duration_seconds > 0.0
		and new_ball_impact_knockback_duration_seconds <= new_knockdown_down_seconds)
	_ball_impact_knockback_distance_m = new_ball_impact_knockback_distance_m
	_ball_impact_knockback_duration_seconds = new_ball_impact_knockback_duration_seconds
	_ball_impact_knockback_apex_height_m = new_ball_impact_knockback_apex_height_m
	assert(new_ball_impact_min_speed_mps > 0.0 and new_ball_impact_body_radius_m > 0.0)
	assert(new_ball_impact_body_height_m > 0.0 and new_ball_impact_rebound_apex_height_m > 0.0)
	assert(new_ball_impact_normal_retention > 0.0 and new_ball_impact_normal_retention <= 1.0)
	assert(new_ball_impact_tangent_retention >= 0.0 and new_ball_impact_tangent_retention <= 1.0)
	_ball_impact_min_speed_mps = new_ball_impact_min_speed_mps
	_ball_impact_body_radius_m = new_ball_impact_body_radius_m
	_ball_impact_body_height_m = new_ball_impact_body_height_m
	_ball_impact_normal_retention = new_ball_impact_normal_retention
	_ball_impact_tangent_retention = new_ball_impact_tangent_retention
	_ball_impact_rebound_apex_height_m = new_ball_impact_rebound_apex_height_m
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
