class_name BallActor
extends Node2D

const LOOSE_ANIMATION := &"loose"
const OWNED_ANIMATION := &"owned"
const IN_FLIGHT_ANIMATION := &"in_flight"

@onready var _animation_player: AnimationPlayer = %AnimationPlayer
@onready var _ball_sprite: Sprite2D = %BallSprite

var _ground_sprite_position: Vector2


func _ready() -> void:
	_ground_sprite_position = _ball_sprite.position
	_play_animation(LOOSE_ANIMATION)


func present(
	ball_snapshot: BallStateSnapshot,
	projection: FieldArtProjection,
) -> void:
	assert(ball_snapshot != null, "BallActor requires a ball snapshot")
	assert(projection != null, "BallActor requires a field projection")
	var ground_position := projection.field_to_world(ball_snapshot.position_m)
	position = ground_position
	var pixels_per_meter := ground_position.distance_to(
		projection.field_to_world(ball_snapshot.position_m + Vector2.RIGHT)
	)
	_ball_sprite.position = (
		_ground_sprite_position
		+ Vector2.UP * ball_snapshot.height_m * pixels_per_meter
	)
	_play_animation(_resolve_animation(ball_snapshot))


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
