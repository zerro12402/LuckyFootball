## Owns player movement and timed action transitions without scene-tree state.
class_name PlayerStateMachine
extends RefCounted

const DEFAULT_MOVEMENT_SPEED_MPS := 5.0
const POSSESSION_MOVEMENT_SPEED_MULTIPLIER := 0.9
const INPUT_EPSILON := 0.0001
const PASS_WINDUP_SECONDS := 0.2
const PASS_RECOVERY_SECONDS := 0.3
const PASS_ACTION_DURATION_SECONDS := 0.4

var state: PlayerMatchState:
	get:
		return _state

var movement_speed_mps: float:
	get:
		return _movement_speed_mps

var _state: PlayerMatchState
var _movement_speed_mps: float
var _shot_config: MatchConfigDefinition


## Checks the runtime invariants shared by movement and timed actions.
func _init(
	player_state: PlayerMatchState,
	new_movement_speed_mps: float = DEFAULT_MOVEMENT_SPEED_MPS,
) -> void:
	assert(player_state != null, "PlayerStateMachine requires player state")
	assert(new_movement_speed_mps > 0.0, "Movement speed must be positive")
	_state = player_state
	_movement_speed_mps = new_movement_speed_mps


## Advances movement and action phases from the fixed simulation clock.
func advance(fixed_delta_seconds: float) -> void:
	assert(fixed_delta_seconds > 0.0, "Fixed delta must be positive")
	if (
		_state.movement_state == PlayerMatchState.MovementState.MOVING
		and _state.action_state != PlayerMatchState.ActionState.SHOOTING
	):
		_state._set_position(
			_state.position_m
			+ _state.movement_input * _get_current_movement_speed_mps() * fixed_delta_seconds
		)
	_state._advance_state_time(fixed_delta_seconds)
	if _state.action_state == PlayerMatchState.ActionState.PASSING:
		_advance_pass_action()
	elif _state.action_state == PlayerMatchState.ActionState.SHOOTING:
		_advance_shot_action()


## Normalizes movement intent while preserving the previous left-right facing on vertical input.
func set_movement_input(new_input: Vector2) -> bool:
	if not new_input.is_finite():
		return false
	if _state.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN:
		return false
	var clamped_input := new_input.limit_length(1.0)
	if clamped_input.length() <= INPUT_EPSILON:
		_state._set_movement_input(Vector2.ZERO)
		_set_movement_state_if_changed(PlayerMatchState.MovementState.IDLE)
		return true
	_state._set_movement_input(clamped_input)
	if _state.action_state != PlayerMatchState.ActionState.SHOOTING:
		_update_horizontal_facing(clamped_input)
	_set_movement_state_if_changed(PlayerMatchState.MovementState.MOVING)
	return true


## Allows only valid movement states outside knockdown.
func set_movement_state(new_state: int) -> bool:
	if new_state < 0 or new_state >= PlayerMatchState.MovementState.size():
		return false
	if _state.movement_state == new_state:
		return false
	if _state.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN:
		return false
	_state._set_movement_state(new_state)
	return true


## Keeps possession transitions inside the player's state machine.
func set_possession_state(new_state: int) -> bool:
	if new_state < 0 or new_state >= PlayerMatchState.PossessionState.size():
		return false
	if _state.possession_state == new_state:
		return false
	_state._set_possession_state(new_state)
	return true


## Starts a generic action only when no other action is active.
func try_start_action(new_action_state: int) -> bool:
	if new_action_state <= PlayerMatchState.ActionState.IDLE:
		return false
	if new_action_state >= PlayerMatchState.ActionState.size():
		return false
	if _state.action_state != PlayerMatchState.ActionState.IDLE:
		return false
	_state._set_action_state(new_action_state, PlayerMatchState.ActionPhase.WINDUP)
	if new_action_state == PlayerMatchState.ActionState.KNOCKED_DOWN:
		_state._set_movement_input(Vector2.ZERO)
		_set_movement_state_if_changed(PlayerMatchState.MovementState.IDLE)
	return true


## Captures shot timing and facing at command acceptance, before the kick frame.
func try_start_shot(config: MatchConfigDefinition, direction: Vector2) -> bool:
	if config == null or not direction.is_finite() or direction.is_zero_approx():
		return false
	if not try_start_action(PlayerMatchState.ActionState.SHOOTING):
		return false
	_shot_config = config
	_update_horizontal_facing(direction)
	return true


## Prevents action phases from moving backward.
func set_action_phase(new_phase: int) -> bool:
	if _state.action_state == PlayerMatchState.ActionState.IDLE:
		return false
	if new_phase <= PlayerMatchState.ActionPhase.NONE:
		return false
	if new_phase >= PlayerMatchState.ActionPhase.size():
		return false
	if new_phase <= _state.action_phase:
		return false
	_state._set_action_phase(new_phase)
	return true


## Releases the action lock after its timed recovery.
func finish_action() -> bool:
	if _state.action_state == PlayerMatchState.ActionState.IDLE:
		return false
	var was_shooting := _state.action_state == PlayerMatchState.ActionState.SHOOTING
	_state._set_action_state(
		PlayerMatchState.ActionState.IDLE,
		PlayerMatchState.ActionPhase.NONE,
	)
	if was_shooting:
		_shot_config = null
		_update_horizontal_facing(_state.movement_input)
	return true


## Applies the existing dribble speed reduction without changing the base speed.
func _get_current_movement_speed_mps() -> float:
	if _state.possession_state == PlayerMatchState.PossessionState.POSSESSING:
		return _movement_speed_mps * POSSESSION_MOVEMENT_SPEED_MULTIPLIER
	return _movement_speed_mps


## Avoids resetting elapsed movement time when a state is unchanged.
func _set_movement_state_if_changed(new_state: int) -> void:
	if _state.movement_state != new_state:
		_state._set_movement_state(new_state)


## Maintains horizontal sprite facing while allowing vertical movement and kicks.
func _update_horizontal_facing(direction: Vector2) -> void:
	if direction.x < -INPUT_EPSILON:
		_state._set_facing_direction(Vector2.LEFT)
	elif direction.x > INPUT_EPSILON:
		_state._set_facing_direction(Vector2.RIGHT)


## Drives the existing pass animation phases from elapsed simulation time.
func _advance_pass_action() -> void:
	var elapsed_seconds := _state.action_state_elapsed_seconds
	if elapsed_seconds >= PASS_ACTION_DURATION_SECONDS:
		finish_action()
	elif elapsed_seconds >= PASS_RECOVERY_SECONDS:
		set_action_phase(PlayerMatchState.ActionPhase.RECOVERY)
	elif elapsed_seconds >= PASS_WINDUP_SECONDS:
		set_action_phase(PlayerMatchState.ActionPhase.ACTIVE)


## Holds the shooting state through its configured kick frame and recovery.
func _advance_shot_action() -> void:
	assert(_shot_config != null, "Shooting requires a match configuration")
	var elapsed_seconds := _state.action_state_elapsed_seconds
	if elapsed_seconds >= _shot_config.shot_action_duration_seconds:
		finish_action()
	elif elapsed_seconds >= _shot_config.shot_recovery_seconds:
		set_action_phase(PlayerMatchState.ActionPhase.RECOVERY)
	elif elapsed_seconds >= _shot_config.shot_windup_seconds:
		set_action_phase(PlayerMatchState.ActionPhase.ACTIVE)
