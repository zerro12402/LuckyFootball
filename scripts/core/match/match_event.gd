class_name MatchEvent
extends RefCounted

enum Type {
	MATCH_STARTED,
	MATCH_PAUSED,
	MATCH_RESUMED,
	MATCH_FINISHED,
	ACTION_ACCEPTED,
	BALL_POSSESSION_GAINED,
	SIMULATION_ADVANCED,
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

var _event_type: int
var _match_time_seconds: float
var _simulation_step: int
var _subject_id: String


func _init(
	new_event_type: int,
	new_match_time_seconds: float,
	new_simulation_step: int,
	new_subject_id: String = "",
) -> void:
	_event_type = new_event_type
	_match_time_seconds = new_match_time_seconds
	_simulation_step = new_simulation_step
	_subject_id = new_subject_id
