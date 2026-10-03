## Reports carried and free-flight motion segments, ownership, and kick events.
class_name BallAdvanceResult
extends RefCounted

var passed_by_player_id: String = ""
var shot_by_player_id: String = ""
var new_owner_player_id: String = ""
var received_by_player_id: String = ""
var was_pass_missed: bool = false
var has_motion_segment: bool = false
var has_owned_motion_segment: bool = false
var owned_motion_start_position_m: Vector2 = Vector2.ZERO
var owned_motion_end_position_m: Vector2 = Vector2.ZERO
var motion_start_position_m: Vector2 = Vector2.ZERO
var motion_end_position_m: Vector2 = Vector2.ZERO
