class_name FieldDebugOverlay
extends Node2D

const BOUNDARY_COLOR := Color(0.35, 0.85, 1.0, 0.9)
const AXIS_COLOR := Color(1.0, 0.75, 0.2, 0.85)
const ANCHOR_COLOR := Color(1.0, 0.3, 0.35, 0.95)

@export var is_debug_enabled: bool = false:
	set(new_value):
		is_debug_enabled = new_value
		queue_redraw()

var _field_definition: FieldDefinition
var _projection: FieldArtProjection


func configure(
	field_definition: FieldDefinition,
	projection: FieldArtProjection,
) -> void:
	_field_definition = field_definition
	_projection = projection
	queue_redraw()


func _draw() -> void:
	if not is_debug_enabled or _field_definition == null or _projection == null:
		return
	var boundary_points := _projection.get_boundary_points()
	var closed_boundary := PackedVector2Array(boundary_points)
	closed_boundary.append(boundary_points[0])
	draw_polyline(closed_boundary, BOUNDARY_COLOR, 2.0, true)

	var left_center := _projection.field_to_world(
		Vector2(-_field_definition.length_m * 0.5, 0.0)
	)
	var right_center := _projection.field_to_world(
		Vector2(_field_definition.length_m * 0.5, 0.0)
	)
	var top_center := _projection.field_to_world(
		Vector2(0.0, -_field_definition.width_m * 0.5)
	)
	var bottom_center := _projection.field_to_world(
		Vector2(0.0, _field_definition.width_m * 0.5)
	)
	draw_line(left_center, right_center, AXIS_COLOR, 1.0, true)
	draw_line(top_center, bottom_center, AXIS_COLOR, 1.0, true)

	var anchors: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-_field_definition.length_m * 0.5, 0.0),
		Vector2(_field_definition.length_m * 0.5, 0.0),
		Vector2(-_field_definition.length_m * 0.25, 0.0),
		Vector2(_field_definition.length_m * 0.25, 0.0),
	]
	for anchor in anchors:
		draw_circle(_projection.field_to_world(anchor), 4.0, ANCHOR_COLOR)

