class_name PlayerRuntime
extends RefCounted

var player_id: String:
	get:
		return _state_machine.state.player_id

var state: PlayerMatchState:
	get:
		return _state_machine.state

var state_machine: PlayerStateMachine:
	get:
		return _state_machine

var _state_machine: PlayerStateMachine


func _init(player_id: String, initial_position_m: Vector2) -> void:
	var initial_state := PlayerMatchState.new(player_id, initial_position_m)
	_state_machine = PlayerStateMachine.new(initial_state)


func advance(fixed_delta_seconds: float) -> void:
	_state_machine.advance(fixed_delta_seconds)
