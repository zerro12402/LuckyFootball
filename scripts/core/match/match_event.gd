## Identifies observable results emitted by deterministic match steps.
class_name MatchEvent
extends RefCounted


enum Type {
	MATCH_STARTED,
	MATCH_PAUSED,
	MATCH_RESUMED,
	MATCH_FINISHED,
	ACTION_ACCEPTED,
	BALL_POSSESSION_GAINED,
	BALL_PASSED,
	BALL_PASS_RECEIVED,
	BALL_PASS_MISSED,
	SIMULATION_ADVANCED,
	BALL_SHOT,
	GOAL_SCORED,
	GOAL_NET_CONTACT,
	TACKLE_SUCCEEDED,
	BALL_OUT_OF_BOUNDS,
	RESET_COMPLETED,
	PLAYER_KNOCKED_DOWN,
	PLAYER_RECOVERED,
	KNOCKDOWN_MISSED,
	ATTACK_RECOILED,
	HEADER_CONTEST_WON,
	BALL_HEADED,
	BALL_CONTACT,
	BALL_DODGED,
	BALL_HIT,
	BALL_CONTINUED,
	BALL_REBOUNDED,
	GOALKEEPER_CONTACT,
}

enum ResetReason {
	NONE,
	GOAL,
	OUT,
	MANUAL_ROUND,
	RESTART_TEST,
}

var event_type: int:
	get:
		return _event_type

var match_time_seconds: float:
	get:
		return _match_time_seconds

var simulation_step: int:
	get:
		return _simulation_step

var subject_id: String:
	get:
		return _subject_id

var reason: int:
	get:
		return _reason

var side: int:
	get:
		return _side

var ball_position_m: Vector2:
	get:
		return _ball_position_m

var last_kicker_id: String:
	get:
		return _last_kicker_id

var goal_count: int:
	get:
		return _goal_count

var is_corner: bool:
	get:
		return _is_corner

var net_surface: int:
	get:
		return _net_surface

var contact_position_m: Vector2:
	get:
		return _contact_position_m

var velocity_before_mps: Vector2:
	get:
		return _velocity_before_mps

var velocity_after_mps: Vector2:
	get:
		return _velocity_after_mps

var target_player_id: String:
	get:
		return _target_player_id

var previous_owner_id: String:
	get:
		return _previous_owner_id

var new_owner_id: String:
	get:
		return _new_owner_id

var ball_impact: BallImpactResult:
	get: return _ball_impact

var _ball_impact: BallImpactResult

var _target_player_id: String = ""
var _previous_owner_id: String = ""
var _new_owner_id: String = ""
var _net_surface: int
var _contact_position_m: Vector2
var _velocity_before_mps: Vector2
var _velocity_after_mps: Vector2
var _event_type: int
var _reason: int
var _side: int
var _ball_position_m: Vector2
var _last_kicker_id: String
var _goal_count: int
var _is_corner: bool
var _match_time_seconds: float
var _simulation_step: int
var _subject_id: String


## Captures a fact and its immutable optional net or player-impact payload.
func _init(
	new_event_type: int,
	new_match_time_seconds: float,
	new_simulation_step: int,
	new_subject_id: String = "",
	new_reason: int = ResetReason.NONE,
	new_side: int = MatchBoundaryResult.Side.NONE,
	new_ball_position_m: Vector2 = Vector2.ZERO,
	new_last_kicker_id: String = "",
	new_goal_count: int = 0,
	new_is_corner: bool = false,
	new_net_contact: GoalNetContact = null,
	new_target_player_id: String = "",
	new_previous_owner_id: String = "",
	new_new_owner_id: String = "",
	new_ball_impact: BallImpactResult = null,
) -> void:
	_event_type = new_event_type
	_match_time_seconds = new_match_time_seconds
	_simulation_step = new_simulation_step
	_subject_id = new_subject_id
	_reason = new_reason
	_side = new_side
	_ball_position_m = new_ball_position_m
	_last_kicker_id = new_last_kicker_id
	_goal_count = new_goal_count
	_is_corner = new_is_corner
	_target_player_id = new_target_player_id
	_previous_owner_id = new_previous_owner_id
	_new_owner_id = new_new_owner_id
	_ball_impact = new_ball_impact
	if new_ball_impact != null:
		_contact_position_m = new_ball_impact.position_m
		_velocity_before_mps = new_ball_impact.velocity_before_mps
		_velocity_after_mps = new_ball_impact.velocity_after_mps
	if new_net_contact != null:
		_net_surface = new_net_contact.surface
		_contact_position_m = new_net_contact.contact_position_m
		_velocity_before_mps = new_net_contact.velocity_before_mps
		_velocity_after_mps = new_net_contact.velocity_after_mps
