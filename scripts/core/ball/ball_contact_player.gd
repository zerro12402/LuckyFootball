## Provides one player's continuous remaining-step body path and contact route.
class_name BallContactPlayer
extends RefCounted

var player_id: String
var start_position_m: Vector2
var end_position_m: Vector2
var start_height_m: float
var end_height_m: float
var is_goalkeeper: bool = false

## Copies the remaining interval from simulation-owned player data.
func _init(id: String, start: Vector2, end: Vector2, height_start: float,
		height_end: float, goalkeeper: bool = false) -> void:
	player_id = id
	start_position_m = start
	end_position_m = end
	start_height_m = height_start
	end_height_m = height_end
	is_goalkeeper = goalkeeper
