class_name PlayerRuntimeSystem
extends RefCounted

var _state_machines: Dictionary[String, PlayerStateMachine] = {}


func register_player(player_state: PlayerMatchState) -> void:
	assert(player_state != null, "Cannot register null player state")
	assert(
		not _state_machines.has(player_state.player_id),
		"Player state is already registered: %s" % player_state.player_id,
	)
	_state_machines[player_state.player_id] = PlayerStateMachine.new(player_state)


func advance(fixed_delta_seconds: float) -> void:
	for state_machine in _state_machines.values():
		state_machine.advance(fixed_delta_seconds)


func get_state_machine(player_id: String) -> PlayerStateMachine:
	return _state_machines.get(player_id) as PlayerStateMachine
