class_name MatchController
extends RefCounted

var _simulation: MatchSimulation


func _init(random_seed: int) -> void:
	_simulation = MatchSimulation.new(random_seed)


func register_player(player_id: String, initial_position_m: Vector2) -> bool:
	return _simulation.register_player(player_id, initial_position_m)


func start_match() -> bool:
	return _simulation.start_match()


func pause_match() -> bool:
	return _simulation.pause_match()


func resume_match() -> bool:
	return _simulation.resume_match()


func finish_match() -> bool:
	return _simulation.finish_match()


func is_running() -> bool:
	return create_snapshot().phase == MatchState.Phase.RUNNING


func advance_simulation(
	fixed_delta_seconds: float,
	actions: Array[MatchAction],
) -> Array[MatchEvent]:
	return _simulation.advance_fixed_step(fixed_delta_seconds, actions)


func create_snapshot() -> MatchStateSnapshot:
	return _simulation.create_snapshot()


func drain_lifecycle_events() -> Array[MatchEvent]:
	return _simulation.drain_lifecycle_events()
