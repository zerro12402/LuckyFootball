class_name PlayerStateMachine
extends RefCounted

const DEFAULT_MOVEMENT_SPEED_MPS := 5.0
const POSSESSION_MOVEMENT_SPEED_MULTIPLIER := 0.9
const INPUT_EPSILON := 0.0001

var state: PlayerMatchState:
	get:
		return _state

var movement_speed_mps: float:
	get:
		return _movement_speed_mps

var _state: PlayerMatchState
var _movement_speed_mps: float


func _init(
	player_state: PlayerMatchState,
	new_movement_speed_mps: float = DEFAULT_MOVEMENT_SPEED_MPS,
) -> void:
	assert(player_state != null, "PlayerStateMachine requires player state")
	assert(new_movement_speed_mps > 0.0, "Movement speed must be positive")
	_state = player_state
	_movement_speed_mps = new_movement_speed_mps


func advance(fixed_delta_seconds: float) -> void:
	assert(fixed_delta_seconds > 0.0, "Fixed delta must be positive")
	if _state.movement_state == PlayerMatchState.MovementState.MOVING:
		_state._set_position(
			_state.position_m
			+ _state.movement_input * _get_current_movement_speed_mps() * fixed_delta_seconds
		)
	_state._advance_state_time(fixed_delta_seconds)


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
	_state._set_facing_direction(clamped_input)
	_set_movement_state_if_changed(PlayerMatchState.MovementState.MOVING)
	return true


func set_movement_state(new_state: int) -> bool:
	if new_state < 0 or new_state >= PlayerMatchState.MovementState.size():
		return false
	if _state.movement_state == new_state:
		return false
	if _state.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN:
		return false
	_state._set_movement_state(new_state)
	return true


func set_possession_state(new_state: int) -> bool:
	if new_state < 0 or new_state >= PlayerMatchState.PossessionState.size():
		return false
	if _state.possession_state == new_state:
		return false
	_state._set_possession_state(new_state)
	return true


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


func finish_action() -> bool:
	if _state.action_state == PlayerMatchState.ActionState.IDLE:
		return false
	_state._set_action_state(
		PlayerMatchState.ActionState.IDLE,
		PlayerMatchState.ActionPhase.NONE,
	)
	return true


func _get_current_movement_speed_mps() -> float:
	if (
		_state.possession_state
		== PlayerMatchState.PossessionState.POSSESSING
	):
		return _movement_speed_mps * POSSESSION_MOVEMENT_SPEED_MULTIPLIER
	return _movement_speed_mps


func _set_movement_state_if_changed(new_state: int) -> void:
	if _state.movement_state != new_state:
		_state._set_movement_state(new_state)
