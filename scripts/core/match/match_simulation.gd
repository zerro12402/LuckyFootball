class_name MatchSimulation
extends RefCounted

var _state: MatchState
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lifecycle_events: Array[MatchEvent] = []
var _player_runtime_system: PlayerRuntimeSystem = PlayerRuntimeSystem.new()


func _init(random_seed: int) -> void:
	_state = MatchState.new(random_seed)
	_rng.seed = random_seed


func register_player(player_id: String, initial_position_m: Vector2) -> bool:
	if _state.phase != MatchState.Phase.READY:
		return false
	return _player_runtime_system.register_player(
		player_id,
		initial_position_m,
	)


func start_match() -> bool:
	if _state.phase != MatchState.Phase.READY:
		return false
	_state._set_phase(MatchState.Phase.RUNNING)
	_lifecycle_events.append(_create_event(MatchEvent.Type.MATCH_STARTED))
	return true


func pause_match() -> bool:
	if _state.phase != MatchState.Phase.RUNNING:
		return false
	_state._set_phase(MatchState.Phase.PAUSED)
	_lifecycle_events.append(_create_event(MatchEvent.Type.MATCH_PAUSED))
	return true


func resume_match() -> bool:
	if _state.phase != MatchState.Phase.PAUSED:
		return false
	_state._set_phase(MatchState.Phase.RUNNING)
	_lifecycle_events.append(_create_event(MatchEvent.Type.MATCH_RESUMED))
	return true


func finish_match() -> bool:
	if (
		_state.phase != MatchState.Phase.RUNNING
		and _state.phase != MatchState.Phase.PAUSED
	):
		return false
	_state._set_phase(MatchState.Phase.FINISHED)
	_lifecycle_events.append(_create_event(MatchEvent.Type.MATCH_FINISHED))
	return true


func advance_fixed_step(
	fixed_delta_seconds: float,
	actions: Array[MatchAction],
) -> Array[MatchEvent]:
	assert(fixed_delta_seconds > 0.0, "Fixed delta must be positive")
	var step_events: Array[MatchEvent] = []
	if _state.phase != MatchState.Phase.RUNNING:
		return step_events

	_state._advance(fixed_delta_seconds)
	_player_runtime_system.advance(fixed_delta_seconds)
	for action in actions:
		step_events.append(
			_create_event(MatchEvent.Type.ACTION_ACCEPTED, action.player_id)
		)
	step_events.append(_create_event(MatchEvent.Type.SIMULATION_ADVANCED))
	return step_events


func create_snapshot() -> MatchStateSnapshot:
	var player_snapshots: Array[PlayerStateSnapshot] = []
	for player_runtime in _player_runtime_system.get_players():
		player_snapshots.append(PlayerStateSnapshot.new(player_runtime.state))
	return MatchStateSnapshot.new(
		_state.phase,
		_state.elapsed_seconds,
		_state.simulation_step,
		_state.random_seed,
		player_snapshots,
	)


func drain_lifecycle_events() -> Array[MatchEvent]:
	var drained_events: Array[MatchEvent] = _lifecycle_events.duplicate()
	_lifecycle_events.clear()
	return drained_events


func _create_event(event_type: int, subject_id: String = "") -> MatchEvent:
	return MatchEvent.new(
		event_type,
		_state.elapsed_seconds,
		_state.simulation_step,
		subject_id,
	)
