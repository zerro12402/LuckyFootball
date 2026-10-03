## Records one deterministic contact between a scored ball and a goal net surface.
class_name GoalNetContact
extends RefCounted

enum Surface {
	BACK,
	TOP,
	BOTTOM,
}

var surface: int
var contact_position_m: Vector2
var velocity_before_mps: Vector2
var velocity_after_mps: Vector2

func _init(
	new_surface: int,
	new_contact_position_m: Vector2,
	new_velocity_before_mps: Vector2,
	new_velocity_after_mps: Vector2,
) -> void:
	surface = new_surface
	contact_position_m = new_contact_position_m
	velocity_before_mps = new_velocity_before_mps
	velocity_after_mps = new_velocity_after_mps
