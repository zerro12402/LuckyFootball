## Records the first legal high-ball contact without changing ownership.
class_name HeaderContactCandidate
extends RefCounted

var player_id: String
var team_id: String
var contact_fraction: float
var contact_position_m: Vector2
var contact_height_m: float
var strength: int
var technique: int


## Keeps timing and contest inputs together for stable resolution.
func _init(
	new_player_id: String,
	new_team_id: String,
	new_contact_fraction: float,
	new_contact_position_m: Vector2,
	new_contact_height_m: float,
	new_strength: int,
	new_technique: int,
) -> void:
	player_id = new_player_id
	team_id = new_team_id
	contact_fraction = new_contact_fraction
	contact_position_m = new_contact_position_m
	contact_height_m = new_contact_height_m
	strength = new_strength
	technique = new_technique
