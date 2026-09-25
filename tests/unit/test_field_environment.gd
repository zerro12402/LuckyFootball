extends SceneTree

var _failures: PackedStringArray = []


func _init() -> void:
	test_field_csv_when_loaded_returns_documented_dimensions()
	test_field_transform_when_round_tripped_preserves_position()
	test_art_projection_when_given_key_anchors_matches_pitch_art()
	test_art_projection_when_round_tripped_preserves_field_position()

	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func test_field_csv_when_loaded_returns_documented_dimensions() -> void:
	var result := FieldDataRepository.new().load_from_csv(
		"res://resources/data/fields.csv"
	)
	_expect(result.is_success, "Expected fields.csv to load")
	_expect(result.fields.size() == 1, "Expected one field definition")
	if result.fields.is_empty():
		return
	var field := result.fields[0]
	_expect(is_equal_approx(field.length_m, 50.0), "Expected 50 metre length")
	_expect(is_equal_approx(field.width_m, 30.0), "Expected 30 metre width")
	_expect(is_equal_approx(field.goal_width_m, 4.0), "Expected 4 metre goal")


func test_field_transform_when_round_tripped_preserves_position() -> void:
	var transform := FieldTransform.new(32.0)
	var field_position := Vector2(12.5, -7.25)
	var world_position := transform.field_to_world(field_position)
	_expect(world_position == Vector2(400.0, -232.0), "Expected 32 px per metre")
	_expect(
		transform.world_to_field(world_position).is_equal_approx(field_position),
		"Expected uniform transform round trip",
	)


func test_art_projection_when_given_key_anchors_matches_pitch_art() -> void:
	var projection := FieldArtProjection.create_default(_create_field_definition())
	_expect(
		projection.field_to_world(Vector2.ZERO).is_equal_approx(Vector2.ZERO),
		"Expected pitch centre at world origin",
	)
	_expect(
		projection.field_to_world(Vector2(-25.0, 0.0)).is_equal_approx(
			Vector2(-376.0, 0.0)
		),
		"Expected left goal centre to match art",
	)
	_expect(
		projection.field_to_world(Vector2(25.0, 0.0)).is_equal_approx(
			Vector2(376.0, 0.0)
		),
		"Expected right goal centre to match art",
	)


func test_art_projection_when_round_tripped_preserves_field_position() -> void:
	var projection := FieldArtProjection.create_default(_create_field_definition())
	var positions: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-25.0, -15.0),
		Vector2(25.0, 15.0),
		Vector2(12.5, -6.0),
	]
	for field_position in positions:
		var round_trip := projection.world_to_field(
			projection.field_to_world(field_position)
		)
		_expect(
			round_trip.distance_to(field_position) < 0.02,
			"Expected art projection round trip for %s" % field_position,
		)


func _create_field_definition() -> FieldDefinition:
	return FieldDefinition.new(
		"test_field",
		50.0,
		30.0,
		4.0,
		1.5,
		8.0,
		16.0,
		4.0,
		32.0,
		"default_pitch",
	)


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
