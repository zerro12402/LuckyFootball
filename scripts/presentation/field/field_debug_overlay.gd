## Draws optional field guides and metre ticks without changing match state.
class_name FieldDebugOverlay
extends Node2D

const BOUNDARY_COLOR := Color(0.35, 0.85, 1.0, 0.9)
const AXIS_COLOR := Color(1.0, 0.75, 0.2, 0.85)
const ANCHOR_COLOR := Color(1.0, 0.3, 0.35, 0.95)
const METER_GRID_COLOR := Color(0.2, 0.9, 1.0, 0.22)
const MAJOR_GRID_COLOR := Color(0.2, 0.9, 1.0, 0.42)
const METER_TICK_COLOR := Color(0.2, 0.9, 1.0, 1.0)
const METER_TICK_SPACING_M := 1.0
const METER_TICK_LENGTH_M := 1.1
const MAJOR_TICK_INTERVAL_M := 5.0
const MAJOR_TICK_LENGTH_M := 2.0
const METER_TICK_WIDTH_PX := 2.0
const MAJOR_TICK_WIDTH_PX := 3.0

@export var is_debug_enabled: bool = false:
	set(new_value):
		is_debug_enabled = new_value
		queue_redraw()

@export var are_meter_ticks_enabled: bool = false:
	set(new_value):
		are_meter_ticks_enabled = new_value
		queue_redraw()

var _field_definition: FieldDefinition
var _projection: FieldArtProjection


## Keeps both overlays aligned with the loaded field and its art projection.
func configure(
	field_definition: FieldDefinition,
	projection: FieldArtProjection,
) -> void:
	_field_definition = field_definition
	_projection = projection
	queue_redraw()


## Draws only the guides currently enabled for this field.
func _draw() -> void:
	if _field_definition == null or _projection == null:
		return
	if is_debug_enabled:
		_draw_debug_guides()
	if are_meter_ticks_enabled:
		_draw_meter_grid()
		_draw_meter_ticks()


## Shows the existing boundary, axes, and reference anchors.
func _draw_debug_guides() -> void:
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


## Projects each 1 m field coordinate into full-width and full-height guide lines.
func _draw_meter_grid() -> void:
	var half_length_m := _field_definition.length_m * 0.5
	var half_width_m := _field_definition.width_m * 0.5
	for step in range(1, floori(_field_definition.length_m / METER_TICK_SPACING_M)):
		var x_m := -half_length_m + float(step) * METER_TICK_SPACING_M
		var is_major := fposmod(float(step) * METER_TICK_SPACING_M, MAJOR_TICK_INTERVAL_M) == 0.0
		var grid_color := MAJOR_GRID_COLOR if is_major else METER_GRID_COLOR
		var grid_width_px := 2.0 if is_major else 1.0
		var vertical_line := PackedVector2Array([
			_projection.field_to_world(Vector2(x_m, -half_width_m)),
			_projection.field_to_world(Vector2(x_m, 0.0)),
			_projection.field_to_world(Vector2(x_m, half_width_m)),
		])
		draw_polyline(vertical_line, grid_color, grid_width_px, true)
	for step in range(1, floori(_field_definition.width_m / METER_TICK_SPACING_M)):
		var y_m := -half_width_m + float(step) * METER_TICK_SPACING_M
		var is_major := fposmod(float(step) * METER_TICK_SPACING_M, MAJOR_TICK_INTERVAL_M) == 0.0
		var grid_color := MAJOR_GRID_COLOR if is_major else METER_GRID_COLOR
		var grid_width_px := 2.0 if is_major else 1.0
		draw_line(
			_projection.field_to_world(Vector2(-half_length_m, y_m)),
			_projection.field_to_world(Vector2(half_length_m, y_m)),
			grid_color,
			grid_width_px,
			true,
		)

## Places one inward-facing tick per metre on each of the four field edges.
func _draw_meter_ticks() -> void:
	var half_length_m := _field_definition.length_m * 0.5
	var half_width_m := _field_definition.width_m * 0.5
	for step in range(1, floori(_field_definition.length_m / METER_TICK_SPACING_M)):
		var x_m := -half_length_m + float(step) * METER_TICK_SPACING_M
		var is_major := fposmod(float(step) * METER_TICK_SPACING_M, MAJOR_TICK_INTERVAL_M) == 0.0
		var tick_length_m := MAJOR_TICK_LENGTH_M if is_major else METER_TICK_LENGTH_M
		_draw_meter_tick(
			Vector2(x_m, -half_width_m),
			Vector2(x_m, -half_width_m + tick_length_m),
			is_major,
		)
		_draw_meter_tick(
			Vector2(x_m, half_width_m),
			Vector2(x_m, half_width_m - tick_length_m),
			is_major,
		)
	for step in range(1, floori(_field_definition.width_m / METER_TICK_SPACING_M)):
		var y_m := -half_width_m + float(step) * METER_TICK_SPACING_M
		var is_major := fposmod(float(step) * METER_TICK_SPACING_M, MAJOR_TICK_INTERVAL_M) == 0.0
		var tick_length_m := MAJOR_TICK_LENGTH_M if is_major else METER_TICK_LENGTH_M
		_draw_meter_tick(
			Vector2(-half_length_m, y_m),
			Vector2(-half_length_m + tick_length_m, y_m),
			is_major,
		)
		_draw_meter_tick(
			Vector2(half_length_m, y_m),
			Vector2(half_length_m - tick_length_m, y_m),
			is_major,
		)


## Projects a high-contrast tick onto the perspective pitch art.
func _draw_meter_tick(start_m: Vector2, end_m: Vector2, is_major: bool) -> void:
	var line_width_px := MAJOR_TICK_WIDTH_PX if is_major else METER_TICK_WIDTH_PX
	draw_line(
		_projection.field_to_world(start_m),
		_projection.field_to_world(end_m),
		METER_TICK_COLOR,
		line_width_px,
		true,
	)
