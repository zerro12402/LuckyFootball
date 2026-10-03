## Presents field art, actors, and optional guides from immutable match snapshots.
class_name FieldEnvironment
extends Node2D

const REQUIRED_VIEW_SIZE := Vector2(960.0, 540.0)

@onready var _left_goal: Node2D = %LeftGoal
@onready var _right_goal: Node2D = %RightGoal
@onready var _left_goal_top: Sprite2D = $Goals/LeftGoal/GoalTop
@onready var _right_goal_top: Sprite2D = $Goals/RightGoal/GoalTop
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
var _left_net_tween: Tween
var _right_net_tween: Tween


## Keeps the fixed full-field camera fitted to the current viewport.
func _ready() -> void:
	get_viewport().size_changed.connect(_fit_camera_to_viewport)
	_fit_camera_to_viewport()


## Aligns goal art and overlays with the loaded field dimensions.
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


## Converts a metre position through the perspective art projection.
func field_to_world(field_position_m: Vector2) -> Vector2:
	assert(_projection != null, "FieldEnvironment must be configured before conversion")
	return _projection.field_to_world(field_position_m)


## Converts a projected position back into field metres.
func world_to_field(world_position: Vector2) -> Vector2:
	assert(_projection != null, "FieldEnvironment must be configured before conversion")
	return _projection.world_to_field(world_position)


## Changes the existing boundary and axis guide visibility.
func set_debug_enabled(is_enabled: bool) -> void:
	_debug_overlay.is_debug_enabled = is_enabled


## Toggles metre ticks independently of the other debug guides.
func toggle_meter_ticks() -> void:
	_debug_overlay.are_meter_ticks_enabled = not _debug_overlay.are_meter_ticks_enabled


## Assigns the actors displayed by the current test scene.
func set_presented_players(player_id: String, teammate_id: String = "") -> void:
	assert(not player_id.is_empty(), "The controlled player requires an ID")
	assert(player_id != teammate_id, "Demo players require distinct IDs")
	_presented_player_ids = [player_id]
	_demo_teammate.visible = not teammate_id.is_empty()
	if not teammate_id.is_empty():
		_presented_player_ids.append(teammate_id)


## Copies a match snapshot into visible actors without changing simulation state.
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


## Shakes only the contacted goal art in response to an immutable simulation event.
func present_events(events: Array[MatchEvent]) -> void:
	for event in events:
		if event.event_type != MatchEvent.Type.GOAL_NET_CONTACT:
			continue
		var goal_top := _left_goal_top if event.side == MatchBoundaryResult.Side.LEFT else _right_goal_top
		if event.side == MatchBoundaryResult.Side.LEFT:
			if _left_net_tween != null:
				_left_net_tween.kill()
		else:
			if _right_net_tween != null:
				_right_net_tween.kill()
		goal_top.position = Vector2(0.0, -62.5)
		var kick_pixels := clampf(event.velocity_before_mps.length() * 0.18, 1.0, 5.0)
		var tween := create_tween()
		tween.tween_property(goal_top, "position:y", -62.5 - kick_pixels, 0.07)
		tween.tween_property(goal_top, "position:y", -62.5 + kick_pixels * 0.4, 0.12)
		tween.tween_property(goal_top, "position:y", -62.5, 0.18)
		if event.side == MatchBoundaryResult.Side.LEFT:
			_left_net_tween = tween
		else:
			_right_net_tween = tween


## Preserves pitch proportions while fitting the design viewport.
func _fit_camera_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var uniform_zoom := minf(
		viewport_size.x / REQUIRED_VIEW_SIZE.x,
		viewport_size.y / REQUIRED_VIEW_SIZE.y,
	)
	_camera.zoom = Vector2.ONE * maxf(uniform_zoom, 0.01)
