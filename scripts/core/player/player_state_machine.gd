class_name PlayerStateMachine
extends RefCounted

var state: PlayerMatchState:
	get:
		return _state

var _state: PlayerMatchState


func _init(player_state: PlayerMatchState) -> void:
	assert(player_state != null, "PlayerStateMachine requires player state")
	_state = player_state


func advance(fixed_delta_seconds: float) -> void:
	assert(fixed_delta_seconds > 0.0, "Fixed delta must be positive")
	_state._advance_state_time(fixed_delta_seconds)


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
