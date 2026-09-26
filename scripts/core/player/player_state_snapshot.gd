class_name PlayerStateSnapshot
extends RefCounted

var player_id: String:
	get:
		return _player_id

var position_m: Vector2:
	get:
		return _position_m

var facing_direction: Vector2:
	get:
		return _facing_direction

var movement_state: int:
	get:
		return _movement_state

var possession_state: int:
	get:
		return _possession_state

var action_state: int:
	get:
		return _action_state

var action_phase: int:
	get:
		return _action_phase

var movement_state_elapsed_seconds: float:
	get:
		return _movement_state_elapsed_seconds

var action_state_elapsed_seconds: float:
	get:
		return _action_state_elapsed_seconds

var _player_id: String
var _position_m: Vector2
var _facing_direction: Vector2
var _movement_state: int
var _possession_state: int
var _action_state: int
var _action_phase: int
var _movement_state_elapsed_seconds: float
var _action_state_elapsed_seconds: float


func _init(player_state: PlayerMatchState) -> void:
	_player_id = player_state.player_id
	_position_m = player_state.position_m
	_facing_direction = player_state.facing_direction
	_movement_state = player_state.movement_state
	_possession_state = player_state.possession_state
	_action_state = player_state.action_state
	_action_phase = player_state.action_phase
	_movement_state_elapsed_seconds = player_state.movement_state_elapsed_seconds
	_action_state_elapsed_seconds = player_state.action_state_elapsed_seconds
