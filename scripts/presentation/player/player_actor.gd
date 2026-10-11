## Presents a player snapshot with sprite animations owned by AnimationPlayer.
class_name PlayerActor
extends Node2D

const IDLE_ANIMATION := &"idle"
const MOVE_ANIMATION := &"move"
const PASS_ANIMATION := &"pass"
const SHOOT_ANIMATION := &"shoot"
const TACKLE_ANIMATION := &"tackle"
const KNOCKDOWN_ANIMATION := &"knockdown"
const LANDING_ANIMATION := &"landing"
const HIT_ANIMATION := &"hit"

@onready var _body_sprite: Sprite2D = %BodySprite
@onready var _animation_player: AnimationPlayer = %AnimationPlayer

var _hit_stun_duration_seconds: float = 1.0
var _tackle_duration_seconds: float = 1.0
var _knockdown_duration_seconds: float = 1.0
var _knockdown_jump_height_m: float = 0.5
var _landing_animation_seconds: float = 0.3
var _ground_sprite_position: Vector2
var _active_animation: StringName = &""


## Starts the actor in its idle animation.
func _ready() -> void:
	_ground_sprite_position = _body_sprite.position
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
	_body_sprite.position = _ground_sprite_position
	if player_snapshot.action_state == PlayerMatchState.ActionState.ATTACKING:
		var progress := clampf(
			player_snapshot.action_state_elapsed_seconds / _knockdown_duration_seconds,
			0.0, 1.0,
		)
		var pixels_per_meter := position.distance_to(
			projection.field_to_world(player_snapshot.position_m + Vector2.RIGHT)
		)
		_body_sprite.position.y -= (
			sin(PI * progress) * _knockdown_jump_height_m * pixels_per_meter
		)
	_play_animation(_resolve_animation(player_snapshot))


## Matches the hit animation playback to the validated simulation lock duration.
func configure_hit_stun(duration_seconds: float) -> void:
	assert(duration_seconds > 0.0 and is_finite(duration_seconds))
	_hit_stun_duration_seconds = duration_seconds


## Matches tackle playback to the same duration used by the fixed-step state machine.
func configure_tackle_duration(duration_seconds: float) -> void:
	assert(duration_seconds > 0.0 and is_finite(duration_seconds))
	_tackle_duration_seconds = duration_seconds


## Keeps the visual hop and action playback aligned with validated match rules.
func configure_knockdown(
	duration_seconds: float,
	jump_height_m: float,
	landing_animation_seconds: float,
) -> void:
	assert(duration_seconds > 0.0 and is_finite(duration_seconds))
	assert(jump_height_m >= 0.0 and is_finite(jump_height_m))
	assert(landing_animation_seconds > 0.0 and is_finite(landing_animation_seconds))
	_knockdown_duration_seconds = duration_seconds
	_knockdown_jump_height_m = jump_height_m
	_landing_animation_seconds = landing_animation_seconds


## Maps the action state to a sprite-sheet row animation.
func _resolve_animation(player_snapshot: PlayerStateSnapshot) -> StringName:
	if player_snapshot.action_state == PlayerMatchState.ActionState.PASSING:
		return PASS_ANIMATION
	if player_snapshot.action_state == PlayerMatchState.ActionState.SHOOTING:
		return SHOOT_ANIMATION
	if player_snapshot.action_state == PlayerMatchState.ActionState.TACKLING:
		return TACKLE_ANIMATION
	if player_snapshot.action_state == PlayerMatchState.ActionState.ATTACKING:
		return KNOCKDOWN_ANIMATION
	if player_snapshot.action_state == PlayerMatchState.ActionState.LANDING:
		return LANDING_ANIMATION
	if player_snapshot.action_state in [
		PlayerMatchState.ActionState.KNOCKED_DOWN,
		PlayerMatchState.ActionState.GETTING_UP,
	]:
		return HIT_ANIMATION
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
	if _active_animation == animation_name:
		if _animation_player.is_playing() or animation_name in [HIT_ANIMATION, LANDING_ANIMATION]:
			return
	var playback_speed := 1.0
	if animation_name == HIT_ANIMATION:
		playback_speed = 1.0 / _hit_stun_duration_seconds
	elif animation_name == TACKLE_ANIMATION:
		playback_speed = 1.0 / _tackle_duration_seconds
	elif animation_name == KNOCKDOWN_ANIMATION:
		playback_speed = 1.0 / _knockdown_duration_seconds
	elif animation_name == LANDING_ANIMATION:
		playback_speed = 0.3 / _landing_animation_seconds
	_animation_player.play(animation_name, -1.0, playback_speed)
	_active_animation = animation_name
