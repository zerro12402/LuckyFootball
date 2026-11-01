## Presents field art, actors, and optional guides from immutable match snapshots.
class_name FieldEnvironment
extends Node2D

const PLAYER_SCENE := preload("res://scenes/actors/player_actor.tscn")

const REQUIRED_VIEW_SIZE := Vector2(960.0, 540.0)

@onready var _left_goal: Node2D = %LeftGoal
@onready var _right_goal: Node2D = %RightGoal
@onready var _left_goal_top: Sprite2D = $Goals/LeftGoal/GoalTop
@onready var _right_goal_top: Sprite2D = $Goals/RightGoal/GoalTop
@onready var _camera: Camera2D = %FieldCamera
@onready var _debug_overlay: FieldDebugOverlay = %DebugOverlay
@onready var _demo_player: PlayerActor = %DemoPlayer
@onready var _demo_teammate: PlayerActor = %DemoTeammate
@onready var _demo_opponent: PlayerActor = %DemoOpponent
@onready var _demo_challenger: PlayerActor = %DemoChallenger
@onready var _ball: BallActor = %Ball

var field_definition: FieldDefinition:
	get:
		return _field_definition

var _field_definition: FieldDefinition
var _projection: FieldArtProjection
var _keeper_save_duration: float = 1.2

var _presented_player_ids: Array[String] = []
var _roster_actors: Dictionary[String, PlayerActor] = {}
var _player_names: Dictionary[String, String] = {}
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


## Synchronizes both actor hit animations with the match configuration.
func configure_hit_stun(duration_seconds: float) -> void:
	_demo_player.configure_hit_stun(duration_seconds)
	_demo_teammate.configure_hit_stun(duration_seconds)
	_demo_opponent.configure_hit_stun(duration_seconds)
	_demo_challenger.configure_hit_stun(duration_seconds)


## Synchronizes tackle playback with its configured fixed-step duration.
func configure_tackle_duration(duration_seconds: float) -> void:
	_demo_player.configure_tackle_duration(duration_seconds)
	_demo_teammate.configure_tackle_duration(duration_seconds)
	_demo_opponent.configure_tackle_duration(duration_seconds)
	_demo_challenger.configure_tackle_duration(duration_seconds)


## Applies the same configured hop height and timing to both visible players.
func configure_knockdown(
	duration_seconds: float,
	jump_height_m: float,
	landing_animation_seconds: float,
) -> void:
	_demo_player.configure_knockdown(duration_seconds, jump_height_m, landing_animation_seconds)
	_demo_teammate.configure_knockdown(duration_seconds, jump_height_m, landing_animation_seconds)
	_demo_opponent.configure_knockdown(duration_seconds, jump_height_m, landing_animation_seconds)
	_demo_challenger.configure_knockdown(duration_seconds, jump_height_m, landing_animation_seconds)


## Synchronizes each visible actor's header frames with the simulation clock.
func configure_header_timing(first_frame_seconds: float, second_frame_seconds: float) -> void:
	_demo_player.configure_header_timing(first_frame_seconds, second_frame_seconds)
	_demo_teammate.configure_header_timing(first_frame_seconds, second_frame_seconds)
	_demo_opponent.configure_header_timing(first_frame_seconds, second_frame_seconds)
	_demo_challenger.configure_header_timing(first_frame_seconds, second_frame_seconds)


## Uses the shooting row for the receiver's jump in the lofted-pass demo only.
func configure_teammate_aerial_shot_pose(enabled: bool) -> void:
	_demo_teammate.configure_aerial_shot_pose(enabled)


## Assigns the actors displayed by the current test scene.
func set_presented_players(
	player_id: String, teammate_id: String = "", is_opponent: bool = false,
	opponent_id: String = "", challenger_id: String = "",
) -> void:
	assert(not player_id.is_empty(), "The controlled player requires an ID")
	assert(player_id != teammate_id, "Demo players require distinct IDs")
	_presented_player_ids = [player_id]
	_demo_teammate.visible = not teammate_id.is_empty()
	_demo_opponent.visible = not opponent_id.is_empty()
	_demo_challenger.visible = not challenger_id.is_empty()
	_demo_teammate.modulate = (
		Color(1.0, 0.55, 0.55) if is_opponent else Color(0.55, 0.9, 1.0)
	)
	if not teammate_id.is_empty():
		_presented_player_ids.append(teammate_id)
	if not opponent_id.is_empty():
		_presented_player_ids.append(opponent_id)
	if not challenger_id.is_empty():
		_presented_player_ids.append(challenger_id)


## Captures only presentation identity; match snapshots remain free of static display strings.
func configure_player_names(definitions: Array[PlayerDefinition]) -> void:
	_player_names.clear()
	for definition in definitions:
		_player_names[definition.player_id] = definition.display_name


## Copies a match snapshot into visible actors without changing simulation state.
func present(snapshot: MatchStateSnapshot) -> void:
	if _projection == null:
		return
	var player_actors: Array[PlayerActor] = [
		_demo_player, _demo_teammate, _demo_opponent, _demo_challenger,
	]
	if not _roster_actors.is_empty():
		player_actors.clear()
		for id in _presented_player_ids:
			player_actors.append(_roster_actors[id])
	var hand_carrier_actor: PlayerActor
	var aerial_carrier_actor: PlayerActor
	for player_index in range(_presented_player_ids.size()):
		var player_snapshot := snapshot.get_player(_presented_player_ids[player_index])
		if player_snapshot != null:
			var holds_in_hands := (snapshot.ball != null
				and snapshot.ball.owner_player_id == player_snapshot.player_id
				and snapshot.ball.control_attachment == BallMatchState.ControlAttachment.KEEPER_HANDS)
			player_actors[player_index].configure_keeper_hands(holds_in_hands, _keeper_save_duration)
			player_actors[player_index].set_display_name(
				_player_names.get(player_snapshot.player_id, player_snapshot.player_id))
			player_actors[player_index].present(player_snapshot, _projection)
			if holds_in_hands:
				hand_carrier_actor = player_actors[player_index]
			if (
				snapshot.ball != null
				and snapshot.ball.owner_player_id == _presented_player_ids[player_index]
				and player_snapshot.jump_phase != PlayerMatchState.JumpPhase.NONE
			):
				aerial_carrier_actor = player_actors[player_index]
	if snapshot.ball != null:
		_ball.present(snapshot.ball, _projection)
		if hand_carrier_actor != null:
			_ball.place_owned_sprite_at_foot(hand_carrier_actor.get_keeper_hand_world_position())
		elif aerial_carrier_actor != null:
			_ball.place_owned_sprite_at_foot(
				aerial_carrier_actor.get_aerial_ball_foot_world_position()
			)


## Shakes only the contacted goal art in response to immutable simulation events.
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


## Uses the configured simulation duration for read-only keeper animation playback.
func configure_keeper_timing(duration_seconds: float) -> void:
	_keeper_save_duration = duration_seconds


## Binds an arbitrary stable-ID roster while retaining the four legacy demo actors for old modes.
func configure_roster(snapshot: MatchStateSnapshot, config: MatchConfigDefinition) -> void:
	for actor in [_demo_player, _demo_teammate, _demo_opponent, _demo_challenger]:
		actor.visible = false
	_presented_player_ids.clear()
	for player in snapshot.players:
		_presented_player_ids.append(player.player_id)
		if not _roster_actors.has(player.player_id):
			var actor := PLAYER_SCENE.instantiate() as PlayerActor
			actor.name = "Roster_" + player.player_id
			_demo_player.get_parent().add_child(actor)
			_roster_actors[player.player_id] = actor
		var actor := _roster_actors[player.player_id]
		actor.modulate = Color(0.55, 0.8, 1.0) if player.team_id == snapshot.home_team_id else Color(1.0, 0.55, 0.55)
		actor.configure_hit_stun(config.tackle_hit_stun_seconds)
		actor.configure_tackle_duration(config.tackle_action_duration_seconds)
		actor.configure_knockdown(config.knockdown_action_duration_seconds, config.knockdown_jump_height_m, config.knockdown_landing_animation_seconds)
		actor.configure_header_timing(config.header_first_frame_seconds, config.header_second_frame_seconds)
	configure_keeper_timing(config.keeper_action_duration_seconds)
	_presented_player_ids.sort()

## Exposes a copied ID list for nonvisual assembly checks without returning mutable actor collections.
func get_presented_player_ids() -> PackedStringArray:
	return PackedStringArray(_presented_player_ids)
