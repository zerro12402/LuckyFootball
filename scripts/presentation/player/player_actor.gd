## Presents a player snapshot with sprite animations owned by AnimationPlayer.
class_name PlayerActor
extends Node2D

const IDLE_ANIMATION := &"idle"
const MOVE_ANIMATION := &"move"
const PASS_ANIMATION := &"pass"
const SHOOT_ANIMATION := &"shoot"
const TACKLE_ANIMATION := &"tackle"
const HIT_ANIMATION := &"hit"

@onready var _body_sprite: Sprite2D = %BodySprite
@onready var _animation_player: AnimationPlayer = %AnimationPlayer

var _hit_stun_duration_seconds: float = 1.0
var _tackle_duration_seconds: float = 1.0


## Starts the actor in its idle animation.
func _ready() -> void:
	_play_animation(IDLE_ANIMATION)


## Projects the simulated position and action into the actor scene.
func present(
	player_snapshot: PlayerStateSnapshot,
	projection: FieldArtProjection,
) -> void:
	assert(player_snapshot != null, "PlayerActor requires a player snapshot")
	assert(projection != null, "PlayerActor requires a field projection")
	position = projection.field_to_world(player_snapshot.position_m)
	_body_sprite.flip_h = player_snapshot.facing_direction.x < 0.0
	_play_animation(_resolve_animation(player_snapshot))


## Matches the hit animation playback to the validated simulation lock duration.
func configure_hit_stun(duration_seconds: float) -> void:
	assert(duration_seconds > 0.0 and is_finite(duration_seconds))
	_hit_stun_duration_seconds = duration_seconds


## Matches tackle playback to the same duration used by the fixed-step state machine.
func configure_tackle_duration(duration_seconds: float) -> void:
	assert(duration_seconds > 0.0 and is_finite(duration_seconds))
	_tackle_duration_seconds = duration_seconds


## Maps the action state to a sprite-sheet row animation.
func _resolve_animation(player_snapshot: PlayerStateSnapshot) -> StringName:
	if player_snapshot.action_state == PlayerMatchState.ActionState.PASSING:
		return PASS_ANIMATION
	if player_snapshot.action_state == PlayerMatchState.ActionState.SHOOTING:
		return SHOOT_ANIMATION
	if player_snapshot.action_state == PlayerMatchState.ActionState.TACKLING:
		return TACKLE_ANIMATION
	if player_snapshot.action_state == PlayerMatchState.ActionState.STAGGERED:
		return HIT_ANIMATION
	if player_snapshot.action_state != PlayerMatchState.ActionState.IDLE:
		# Other action rows will be mapped when those actions are implemented.
		return IDLE_ANIMATION
	if player_snapshot.movement_state == PlayerMatchState.MovementState.MOVING:
		return MOVE_ANIMATION
	return IDLE_ANIMATION


## Avoids restarting an action animation on every presentation frame.
func _play_animation(animation_name: StringName) -> void:
	if _animation_player.current_animation == animation_name:
		if _animation_player.is_playing() or animation_name == HIT_ANIMATION:
			return
	var playback_speed := 1.0
	if animation_name == HIT_ANIMATION:
		playback_speed = 1.0 / _hit_stun_duration_seconds
	elif animation_name == TACKLE_ANIMATION:
		playback_speed = 1.0 / _tackle_duration_seconds
	_animation_player.play(animation_name, -1.0, playback_speed)
