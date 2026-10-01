## Owns every mutable match runtime and emits ordered fixed-step events.
class_name MatchSimulation
extends RefCounted

var _state: MatchState
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lifecycle_events: Array[MatchEvent] = []
var _player_runtime_system: PlayerRuntimeSystem = PlayerRuntimeSystem.new()
var _ball_runtime_system: BallRuntimeSystem = BallRuntimeSystem.new()


## Injects deterministic randomness and optional validated shooting rules.
func _init(random_seed: int, match_config: MatchConfigDefinition = null) -> void:
	_state = MatchState.new(random_seed)
	_rng.seed = random_seed
	if match_config != null:
		_ball_runtime_system.configure_shots(match_config)


## Registers a player only before play, with shooting from its static definition.
func register_player(
	player_id: String,
	initial_position_m: Vector2,
	movement_speed_mps: float = PlayerStateMachine.DEFAULT_MOVEMENT_SPEED_MPS,
	team_id: String = "default_team",
	shooting_attribute: int = 0,
) -> bool:
	if _state.phase != MatchState.Phase.READY:
		return false
	return _player_runtime_system.register_player(
		player_id,
		initial_position_m,
		movement_speed_mps,
		team_id,
		shooting_attribute,
	)


## Registers the sole ball before the match starts.
func register_ball(initial_position_m: Vector2) -> bool:
	if _state.phase != MatchState.Phase.READY:
		return false
	return _ball_runtime_system.register_ball(initial_position_m)


## Enters the running phase and records its lifecycle event once.
func start_match() -> bool:
	if _state.phase != MatchState.Phase.READY:
		return false
	_state._set_phase(MatchState.Phase.RUNNING)
	_lifecycle_events.append(_create_event(MatchEvent.Type.MATCH_STARTED))
	return true


## Suspends simulation without advancing timers or ball motion.
func pause_match() -> bool:
	if _state.phase != MatchState.Phase.RUNNING:
		return false
	_state._set_phase(MatchState.Phase.PAUSED)
	_lifecycle_events.append(_create_event(MatchEvent.Type.MATCH_PAUSED))
	return true


## Resumes a paused match at the same simulation time.
func resume_match() -> bool:
	if _state.phase != MatchState.Phase.PAUSED:
		return false
	_state._set_phase(MatchState.Phase.RUNNING)
	_lifecycle_events.append(_create_event(MatchEvent.Type.MATCH_RESUMED))
	return true


## Stops all future simulation steps after a match ends.
func finish_match() -> bool:
	if _state.phase != MatchState.Phase.RUNNING and _state.phase != MatchState.Phase.PAUSED:
		return false
	_state._set_phase(MatchState.Phase.FINISHED)
	_lifecycle_events.append(_create_event(MatchEvent.Type.MATCH_FINISHED))
	return true


func is_running() -> bool:
	return _state.phase == MatchState.Phase.RUNNING


## Validates commands before advancing players, ball trajectories, and events in order.
func advance_fixed_step(
	fixed_delta_seconds: float,
	actions: Array[MatchAction],
) -> Array[MatchEvent]:
	assert(fixed_delta_seconds > 0.0, "Fixed delta must be positive")
	var step_events: Array[MatchEvent] = []
	if not is_running():
		return step_events
	_state._advance(fixed_delta_seconds)
	for action in actions:
		if action == null:
			continue
		var was_accepted := false
		if action.action_type == MatchAction.Type.PASS:
			was_accepted = _try_start_pass(action)
		elif action.action_type == MatchAction.Type.SHOOT:
			was_accepted = _try_start_shot(action)
		else:
			was_accepted = _player_runtime_system.apply_action(action)
		if was_accepted:
			step_events.append(_create_event(MatchEvent.Type.ACTION_ACCEPTED, action.player_id))
	_player_runtime_system.advance(fixed_delta_seconds)
	var ball_result := _ball_runtime_system.advance(
		fixed_delta_seconds,
		_player_runtime_system,
	)
	if not ball_result.passed_by_player_id.is_empty():
		step_events.append(_create_event(MatchEvent.Type.BALL_PASSED, ball_result.passed_by_player_id))
	if not ball_result.shot_by_player_id.is_empty():
		step_events.append(_create_event(MatchEvent.Type.BALL_SHOT, ball_result.shot_by_player_id))
	if not ball_result.new_owner_player_id.is_empty():
		step_events.append(
			_create_event(MatchEvent.Type.BALL_POSSESSION_GAINED, ball_result.new_owner_player_id)
		)
	if not ball_result.received_by_player_id.is_empty():
		step_events.append(
			_create_event(MatchEvent.Type.BALL_PASS_RECEIVED, ball_result.received_by_player_id)
		)
	if ball_result.was_pass_missed:
		step_events.append(_create_event(MatchEvent.Type.BALL_PASS_MISSED))
	step_events.append(_create_event(MatchEvent.Type.SIMULATION_ADVANCED))
	return step_events


## Returns an immutable snapshot for presentation and test assertions.
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
		_ball_runtime_system.create_snapshot(),
	)


## Transfers lifecycle events exactly once into the next displayed frame.
func drain_lifecycle_events() -> Array[MatchEvent]:
	var drained_events: Array[MatchEvent] = _lifecycle_events.duplicate()
	_lifecycle_events.clear()
	return drained_events


## Resolves pass participants before asking the ball system to start windup.
func _try_start_pass(action: MatchAction) -> bool:
	var passer := _player_runtime_system.get_player(action.player_id)
	var receiver := _player_runtime_system.get_player(action.target_player_id)
	return _ball_runtime_system.try_start_pass(passer, receiver)


## Validates a shoot command through the same ball ownership authority as passes.
func _try_start_shot(action: MatchAction) -> bool:
	var shooter := _player_runtime_system.get_player(action.player_id)
	return _ball_runtime_system.try_start_shot(shooter, action.direction, action.power)


func _create_event(event_type: int, subject_id: String = "") -> MatchEvent:
	return MatchEvent.new(
		event_type,
		_state.elapsed_seconds,
		_state.simulation_step,
		subject_id,
	)
