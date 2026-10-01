class_name FieldEnvironment
extends Node2D

const REQUIRED_VIEW_SIZE := Vector2(960.0, 540.0)

@onready var _left_goal: Node2D = %LeftGoal
@onready var _right_goal: Node2D = %RightGoal
@onready var _camera: Camera2D = %FieldCamera
@onready var _debug_overlay: FieldDebugOverlay = %DebugOverlay
@onready var _demo_player: PlayerActor = %DemoPlayer
@onready var _demo_teammate: PlayerActor = %DemoTeammate
@onready var _ball: BallActor = %Ball

var field_definition: FieldDefinition:
	get:
		return _field_definition

var _field_definition: FieldDefinition
var _projection: FieldArtProjection
var _presented_player_ids: Array[String] = []


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


func set_presented_players(player_id: String, teammate_id: String) -> void:
	assert(not player_id.is_empty(), "The controlled player requires an ID")
	assert(not teammate_id.is_empty(), "The teammate requires an ID")
	assert(player_id != teammate_id, "Demo players require distinct IDs")
	_presented_player_ids = [player_id, teammate_id]


func present(snapshot: MatchStateSnapshot) -> void:
	if _projection == null:
		return
	var player_actors: Array[PlayerActor] = [_demo_player, _demo_teammate]
	for player_index in range(_presented_player_ids.size()):
		var player_snapshot := snapshot.get_player(_presented_player_ids[player_index])
		if player_snapshot != null:
			player_actors[player_index].present(player_snapshot, _projection)
	if snapshot.ball != null:
		_ball.present(snapshot.ball, _projection)


func _fit_camera_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var uniform_zoom := minf(
		viewport_size.x / REQUIRED_VIEW_SIZE.x,
		viewport_size.y / REQUIRED_VIEW_SIZE.y,
	)
	_camera.zoom = Vector2.ONE * maxf(uniform_zoom, 0.01)
