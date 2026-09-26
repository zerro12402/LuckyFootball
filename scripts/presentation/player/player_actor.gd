class_name PlayerActor
extends Node2D

const IDLE_ROW := 0
const IDLE_FRAME_COUNT := 4
const IDLE_FRAMES_PER_SECOND := 6.0

@onready var _body_sprite: Sprite2D = %BodySprite


func present(
	player_snapshot: PlayerStateSnapshot,
	projection: FieldArtProjection,
) -> void:
	assert(player_snapshot != null, "PlayerActor requires a player snapshot")
	assert(projection != null, "PlayerActor requires a field projection")
	position = projection.field_to_world(player_snapshot.position_m)
	_body_sprite.frame_coords = _resolve_frame_coords(player_snapshot)
	_body_sprite.flip_h = player_snapshot.facing_direction.x < 0.0


func _resolve_frame_coords(player_snapshot: PlayerStateSnapshot) -> Vector2i:
	if player_snapshot.action_state == PlayerMatchState.ActionState.IDLE:
		var idle_frame := int(
			floor(
				player_snapshot.action_state_elapsed_seconds
				* IDLE_FRAMES_PER_SECOND
			)
		) % IDLE_FRAME_COUNT
		return Vector2i(idle_frame, IDLE_ROW)
	# Action rows will be added after the sprite sheet row meanings are confirmed.
	return Vector2i(0, IDLE_ROW)
