## Stores one player's mutable match position, possession, action, and fixed-step timers.
class_name PlayerMatchState
extends RefCounted

enum MovementState {
	IDLE,
	MOVING,
	TURNING,
}

enum PossessionState {
	NO_BALL,
	POSSESSING,
	RELEASING,
}

enum ActionState {
	IDLE,
	SHOOTING,
	PASSING,
	TACKLING,
	STAGGERED,
	ATTACKING,
	DODGING,
	KNOCKED_DOWN,
	GETTING_UP,
}

enum ActionPhase {
	NONE,
	WINDUP,
	ACTIVE,
	RECOVERY,
}

var player_id: String:
	get:
		return _player_id

var position_m: Vector2:
	get:
		return _position_m

var facing_direction: Vector2:
	get:
		return _facing_direction

var movement_input: Vector2:
	get:
		return _movement_input

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
var _facing_direction: Vector2 = Vector2.RIGHT
var _movement_input: Vector2 = Vector2.ZERO
var _movement_state: int = MovementState.IDLE
var _possession_state: int = PossessionState.NO_BALL
var _action_state: int = ActionState.IDLE
var _action_phase: int = ActionPhase.NONE
var _movement_state_elapsed_seconds: float = 0.0
var _action_state_elapsed_seconds: float = 0.0


## Initializes a player at their registered field position.
func _init(new_player_id: String, initial_position_m: Vector2) -> void:
	assert(not new_player_id.is_empty(), "Player state requires a player ID")
	_player_id = new_player_id
	_position_m = initial_position_m


## Records the latest movement intent, including during temporary action locks.
func _set_movement_input(new_input: Vector2) -> void:
	_movement_input = new_input


## Starts a fresh movement-state clock when locomotion changes.
func _set_movement_state(new_state: int) -> void:
	_movement_state = new_state
	_movement_state_elapsed_seconds = 0.0


## Updates the player-side view of unique ball ownership.
func _set_possession_state(new_state: int) -> void:
	_possession_state = new_state


## Starts a new action and resets its fixed-step timer.
func _set_action_state(new_state: int, new_phase: int) -> void:
	_action_state = new_state
	_action_phase = new_phase
	_action_state_elapsed_seconds = 0.0


## Advances a timed action phase without resetting elapsed time.
func _set_action_phase(new_phase: int) -> void:
	_action_phase = new_phase


## Applies a validated simulation position to this player.
func _set_position(new_position_m: Vector2) -> void:
	_position_m = new_position_m


## Normalizes the direction used by ball control and presentation.
func _set_facing_direction(new_direction: Vector2) -> void:
	assert(not new_direction.is_zero_approx(), "Facing direction cannot be zero")
	_facing_direction = new_direction.normalized()


## Advances movement and action clocks from the same fixed delta.
func _advance_state_time(fixed_delta_seconds: float) -> void:
	_movement_state_elapsed_seconds += fixed_delta_seconds
	_action_state_elapsed_seconds += fixed_delta_seconds
