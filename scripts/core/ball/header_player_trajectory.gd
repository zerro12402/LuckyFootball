## Describes one player's fixed-step path and explicit aerial contest inputs.
class_name HeaderPlayerTrajectory
extends RefCounted

var player_id: String
var team_id: String
var start_position_m: Vector2
var end_position_m: Vector2
var start_height_m: float
var end_height_m: float
var strength: int
var technique: int
var is_eligible: bool


## Captures immutable inputs before the ball path is tested for contact.
func _init(
	new_player_id: String,
	new_team_id: String,
	new_start_position_m: Vector2,
	new_end_position_m: Vector2,
	new_start_height_m: float,
	new_end_height_m: float,
	new_strength: int,
	new_technique: int,
	new_is_eligible: bool = true,
) -> void:
	assert(not new_player_id.is_empty() and not new_team_id.is_empty())
	assert(new_start_position_m.is_finite() and new_end_position_m.is_finite())
	assert(new_start_height_m >= 0.0 and new_end_height_m >= 0.0)
	assert(new_strength >= 0 and new_strength <= 100)
	assert(new_technique >= 0 and new_technique <= 100)
	player_id = new_player_id
	team_id = new_team_id
	start_position_m = new_start_position_m
	end_position_m = new_end_position_m
	start_height_m = new_start_height_m
	end_height_m = new_end_height_m
	strength = new_strength
	technique = new_technique
	is_eligible = new_is_eligible
