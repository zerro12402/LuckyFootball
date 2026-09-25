class_name FieldEnvironment
extends Node2D

const REQUIRED_VIEW_SIZE := Vector2(960.0, 540.0)

@onready var _left_goal: Node2D = %LeftGoal
@onready var _right_goal: Node2D = %RightGoal
@onready var _camera: Camera2D = %FieldCamera
@onready var _debug_overlay: FieldDebugOverlay = %DebugOverlay

var field_definition: FieldDefinition:
	get:
		return _field_definition

var _field_definition: FieldDefinition
var _projection: FieldArtProjection


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_camera_to_viewport)
	_fit_camera_to_viewport()


func configure(new_field_definition: FieldDefinition) -> void:
	assert(new_field_definition != null, "FieldEnvironment requires a FieldDefinition")
	_field_definition = new_field_definition
	_projection = FieldArtProjection.create_default(_field_definition)
	_left_goal.position = _projection.field_to_world(
		Vector2(
			-_field_definition.length_m * 0.5 - _field_definition.goal_depth_m,
			0.0,
		)
	)
	_right_goal.position = _projection.field_to_world(
		Vector2(
			_field_definition.length_m * 0.5 + _field_definition.goal_depth_m,
			0.0,
		)
	)
	_debug_overlay.configure(_field_definition, _projection)


func field_to_world(field_position_m: Vector2) -> Vector2:
	assert(_projection != null, "FieldEnvironment must be configured before conversion")
	return _projection.field_to_world(field_position_m)


func world_to_field(world_position: Vector2) -> Vector2:
	assert(_projection != null, "FieldEnvironment must be configured before conversion")
	return _projection.world_to_field(world_position)


func set_debug_enabled(is_enabled: bool) -> void:
	_debug_overlay.is_debug_enabled = is_enabled


func _fit_camera_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var uniform_zoom := minf(
		viewport_size.x / REQUIRED_VIEW_SIZE.x,
		viewport_size.y / REQUIRED_VIEW_SIZE.y,
	)
	_camera.zoom = Vector2.ONE * maxf(uniform_zoom, 0.01)
