class_name BallActor
extends Node2D

const LOOSE_ANIMATION := &"loose"
const OWNED_ANIMATION := &"owned"
const IN_FLIGHT_ANIMATION := &"in_flight"

@export_range(0.0, 32.0, 0.5)
var owned_control_distance_px: float = 8.0

@onready var _animation_player: AnimationPlayer = %AnimationPlayer


func _ready() -> void:
	_play_animation(LOOSE_ANIMATION)


func present(
	ball_snapshot: BallStateSnapshot,
	projection: FieldArtProjection,
	owner_snapshot: PlayerStateSnapshot = null,
) -> void:
	assert(ball_snapshot != null, "BallActor requires a ball snapshot")
	assert(projection != null, "BallActor requires a field projection")
	position = _resolve_world_position(
		ball_snapshot,
		projection,
		owner_snapshot,
	)
	_play_animation(_resolve_animation(ball_snapshot))


func _resolve_world_position(
	ball_snapshot: BallStateSnapshot,
	projection: FieldArtProjection,
	owner_snapshot: PlayerStateSnapshot,
) -> Vector2:
	if (
		ball_snapshot.motion_state != BallMatchState.MotionState.OWNED
		or owner_snapshot == null
	):
		return projection.field_to_world(ball_snapshot.position_m)

	var owner_world_position := projection.field_to_world(
		owner_snapshot.position_m
	)
	var facing_world_position := projection.field_to_world(
		owner_snapshot.position_m + owner_snapshot.facing_direction
	)
	var world_facing_direction := (
		facing_world_position - owner_world_position
	).normalized()
	if world_facing_direction.is_zero_approx():
		return projection.field_to_world(ball_snapshot.position_m)
	return (
		owner_world_position
		+ world_facing_direction * owned_control_distance_px
	)


func _resolve_animation(ball_snapshot: BallStateSnapshot) -> StringName:
	match ball_snapshot.motion_state:
		BallMatchState.MotionState.LOOSE:
			return LOOSE_ANIMATION
		BallMatchState.MotionState.OWNED:
			return OWNED_ANIMATION
		BallMatchState.MotionState.IN_FLIGHT:
			return IN_FLIGHT_ANIMATION
		_:
			assert(false, "Unsupported ball motion state")
			return LOOSE_ANIMATION


func _play_animation(animation_name: StringName) -> void:
	if (
		_animation_player.current_animation == animation_name
		and _animation_player.is_playing()
	):
		return
	_animation_player.play(animation_name)
