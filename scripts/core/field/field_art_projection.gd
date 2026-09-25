class_name FieldArtProjection
extends RefCounted

var _field_definition: FieldDefinition
var _top_left: Vector2
var _top_right: Vector2
var _middle_left: Vector2
var _middle_right: Vector2
var _bottom_left: Vector2
var _bottom_right: Vector2


static func create_default(field_definition: FieldDefinition) -> FieldArtProjection:
	return FieldArtProjection.new(
		field_definition,
		Vector2(-358.0, -136.0),
		Vector2(365.0, -136.0),
		Vector2(-376.0, 0.0),
		Vector2(376.0, 0.0),
		Vector2(-394.0, 163.0),
		Vector2(393.0, 163.0),
	)


func _init(
	field_definition: FieldDefinition,
	top_left: Vector2,
	top_right: Vector2,
	middle_left: Vector2,
	middle_right: Vector2,
	bottom_left: Vector2,
	bottom_right: Vector2,
) -> void:
	_field_definition = field_definition
	_top_left = top_left
	_top_right = top_right
	_middle_left = middle_left
	_middle_right = middle_right
	_bottom_left = bottom_left
	_bottom_right = bottom_right


func field_to_world(field_position_m: Vector2) -> Vector2:
	var normalized_x := field_position_m.x / _field_definition.length_m + 0.5
	var normalized_y := field_position_m.y / _field_definition.width_m + 0.5
	var row := _get_row(normalized_y)
	return row[0].lerp(row[1], normalized_x)


func world_to_field(world_position: Vector2) -> Vector2:
	var low_y := -0.25
	var high_y := 1.25
	for iteration in range(32):
		var first_y := lerpf(low_y, high_y, 1.0 / 3.0)
		var second_y := lerpf(low_y, high_y, 2.0 / 3.0)
		if _distance_to_row_squared(world_position, first_y) < (
			_distance_to_row_squared(world_position, second_y)
		):
			high_y = second_y
		else:
			low_y = first_y
	var normalized_y := (low_y + high_y) * 0.5
	var row := _get_row(normalized_y)
	var row_vector: Vector2 = row[1] - row[0]
	var normalized_x := (world_position - row[0]).dot(row_vector) / row_vector.length_squared()
	return Vector2(
		(normalized_x - 0.5) * _field_definition.length_m,
		(normalized_y - 0.5) * _field_definition.width_m,
	)


func get_boundary_points() -> PackedVector2Array:
	return PackedVector2Array([
		_top_left,
		_top_right,
		_bottom_right,
		_bottom_left,
	])


func _get_row(normalized_y: float) -> Array[Vector2]:
	if normalized_y <= 0.5:
		var top_weight := normalized_y * 2.0
		return [
			_top_left.lerp(_middle_left, top_weight),
			_top_right.lerp(_middle_right, top_weight),
		]
	var bottom_weight := (normalized_y - 0.5) * 2.0
	return [
		_middle_left.lerp(_bottom_left, bottom_weight),
		_middle_right.lerp(_bottom_right, bottom_weight),
	]


func _distance_to_row_squared(world_position: Vector2, normalized_y: float) -> float:
	var row := _get_row(normalized_y)
	var row_vector: Vector2 = row[1] - row[0]
	var row_weight := clampf(
		(world_position - row[0]).dot(row_vector) / row_vector.length_squared(),
		0.0,
		1.0,
	)
	return world_position.distance_squared_to(row[0].lerp(row[1], row_weight))
