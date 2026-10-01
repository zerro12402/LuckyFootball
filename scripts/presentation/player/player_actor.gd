class_name PlayerActor
extends Node2D

const IDLE_ANIMATION := &"idle"
const MOVE_ANIMATION := &"move"
const PASS_ANIMATION := &"pass"

@onready var _body_sprite: Sprite2D = %BodySprite
@onready var _animation_player: AnimationPlayer = %AnimationPlayer


func _ready() -> void:
	_play_animation(IDLE_ANIMATION)


func present(
	player_snapshot: PlayerStateSnapshot,
	projection: FieldArtProjection,
) -> void:
	assert(player_snapshot != null, "PlayerActor requires a player snapshot")
	assert(projection != null, "PlayerActor requires a field projection")
	position = projection.field_to_world(player_snapshot.position_m)
	_body_sprite.flip_h = player_snapshot.facing_direction.x < 0.0
	_play_animation(_resolve_animation(player_snapshot))


func _resolve_animation(player_snapshot: PlayerStateSnapshot) -> StringName:
	if player_snapshot.action_state == PlayerMatchState.ActionState.PASSING:
		return PASS_ANIMATION
	if player_snapshot.action_state != PlayerMatchState.ActionState.IDLE:
		# Other action rows will be mapped when those actions are implemented.
		return IDLE_ANIMATION
	if player_snapshot.movement_state == PlayerMatchState.MovementState.MOVING:
		return MOVE_ANIMATION
	return IDLE_ANIMATION


func _play_animation(animation_name: StringName) -> void:
	if (
		_animation_player.current_animation == animation_name
		and _animation_player.is_playing()
	):
		return
	_animation_player.play(animation_name)
