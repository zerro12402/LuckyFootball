## Reports carried and free-flight motion segments, headers, ownership, and kicks.
class_name BallAdvanceResult
extends RefCounted

var passed_by_player_id: String = ""
var shot_by_player_id: String = ""
var new_owner_player_id: String = ""
var received_by_player_id: String = ""
var was_pass_missed: bool = false
var header_by_player_id: String = ""
var header_action_type: int = MatchAction.Type.NONE
var header_contact_position_m: Vector2 = Vector2.ZERO
var has_pre_header_segment: bool = false
var pre_header_start_position_m: Vector2 = Vector2.ZERO
var pre_header_end_position_m: Vector2 = Vector2.ZERO
var has_motion_segment: bool = false
var has_owned_motion_segment: bool = false
var owned_motion_start_position_m: Vector2 = Vector2.ZERO
var owned_motion_end_position_m: Vector2 = Vector2.ZERO
var motion_start_position_m: Vector2 = Vector2.ZERO
var motion_end_position_m: Vector2 = Vector2.ZERO
var deferred_shot_seconds: float = 0.0
