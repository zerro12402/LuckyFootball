class_name FieldTransform
extends RefCounted

var _pixels_per_meter: float


func _init(pixels_per_meter: float) -> void:
	assert(pixels_per_meter > 0.0, "Pixels per meter must be positive")
	_pixels_per_meter = pixels_per_meter


func field_to_world(field_position_m: Vector2) -> Vector2:
	return field_position_m * _pixels_per_meter


func world_to_field(world_position_px: Vector2) -> Vector2:
	return world_position_px / _pixels_per_meter
