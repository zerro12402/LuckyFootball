## Accumulates committed planar travel and distinct F08 victims for one locked shot sequence.
class_name ShotFlightContext
extends RefCounted

var source: BallShotSource:
	get: return _source
var distance_m: float:
	get: return _distance_m
var knockdown_count: int:
	get: return _knocked_down_ids.size()
var knocked_down_ids: PackedStringArray:
	get: return PackedStringArray(_knocked_down_ids.keys())
var _source: BallShotSource
var _distance_m: float = 0.0
var _knocked_down_ids: Dictionary[String, bool] = {}

func _init(shot: BallShotSource) -> void:
	_source = shot

## Adds only the interval already accepted by the motion/contact scheduler.
func _advance_distance(meters: float) -> void:
	assert(is_finite(meters) and meters >= 0.0)
	_distance_m += meters

## Records successful non-keeper F08 commits once, even if the ball rebounds and returns.
func _record_knockdown(player_id: String) -> void:
	assert(not player_id.is_empty())
	_knocked_down_ids[player_id] = true
