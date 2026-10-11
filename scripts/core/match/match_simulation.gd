## Owns mutable match state, boundary settlement, resets, and ordered fixed-step events.
class_name MatchSimulation
extends RefCounted

const SETTLEMENT_TIME_EPSILON := 0.000001

var _state: MatchState
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lifecycle_events: Array[MatchEvent] = []
var _event_history: Array[MatchEvent] = []
var _player_runtime_system: PlayerRuntimeSystem = PlayerRuntimeSystem.new()
var _ball_runtime_system: BallRuntimeSystem = BallRuntimeSystem.new()
var _match_rules: MatchRules
var _initial_ball_position_m: Vector2 = Vector2.ZERO
var _boundary_reset_delay_seconds: float = 0.0
var _match_config: MatchConfigDefinition
var _field_definition: FieldDefinition
var _goal_motion_elapsed_seconds: float = 0.0
var _settlement_remaining_seconds: float = 0.0
var _pending_reset_reason: int = MatchEvent.ResetReason.NONE
var _pending_reset_side: int = MatchBoundaryResult.Side.NONE
var _is_carried_settlement: bool = false
var _out_of_play_velocity_mps: Vector2 = Vector2.ZERO
var _attacking_goals_by_team: Dictionary[String, Vector2] = {}
var _pending_tackle_targets: Dictionary[String, String] = {}


## Injects deterministic randomness and optional validated field and shooting rules.
func _init(
	random_seed: int,
	match_config: MatchConfigDefinition = null,
	field_definition: FieldDefinition = null,
) -> void:
	_state = MatchState.new(random_seed)
	_rng.seed = random_seed
	_match_config = match_config
	_field_definition = field_definition
	if match_config != null:
		_ball_runtime_system.configure_shots(match_config)
		_boundary_reset_delay_seconds = match_config.boundary_reset_delay_seconds
	if field_definition != null:
		assert(match_config != null, "Field boundaries require a ball radius configuration")
		assert(field_definition.goal_depth_m > match_config.ball_radius_m * 2.0,
			"Ball must fit between the score line and back net")
		_match_rules = MatchRules.new(field_definition, match_config.ball_radius_m)


## Registers a player only before play, with shooting from its static definition.
func register_player(
	player_id: String,
	initial_position_m: Vector2,
	movement_speed_mps: float = PlayerStateMachine.DEFAULT_MOVEMENT_SPEED_MPS,
	team_id: String = "default_team",
	shooting_attribute: int = 0,
) -> bool:
	if _state.phase != MatchState.Phase.READY or not initial_position_m.is_finite():
		return false
	return _player_runtime_system.register_player(
		player_id,
		initial_position_m,
		movement_speed_mps,
		team_id,
		shooting_attribute,
	)


## Associates a team with its opponent goal center before the match starts.
func register_team_attacking_goal(team_id: String, goal_center_m: Vector2) -> bool:
	if _state.phase != MatchState.Phase.READY:
		return false
	if team_id.is_empty() or not goal_center_m.is_finite():
		return false
	if _attacking_goals_by_team.has(team_id):
		return false
	_attacking_goals_by_team[team_id] = goal_center_m
	return true


## Registers the sole ball and its manual-test reset position before play.
func register_ball(initial_position_m: Vector2) -> bool:
	if _state.phase != MatchState.Phase.READY or not initial_position_m.is_finite():
		return false
	if not _ball_runtime_system.register_ball(initial_position_m):
		return false
	_initial_ball_position_m = initial_position_m
	return true


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


## Gives manual resets priority, then advances settlement or active play.
func advance_fixed_step(
	fixed_delta_seconds: float,
	actions: Array[MatchAction],
) -> Array[MatchEvent]:
	assert(fixed_delta_seconds > 0.0, "Fixed delta must be positive")
	var step_events: Array[MatchEvent] = []
	if not is_running():
		return step_events
	_state._advance(fixed_delta_seconds)
	var reset_reason := _find_reset_reason(actions)
	if reset_reason != MatchEvent.ResetReason.NONE:
		_reset_round(reset_reason, _initial_ball_position_m, step_events)
		step_events.append(_create_event(MatchEvent.Type.SIMULATION_ADVANCED))
		_record_step_events(step_events)
		return step_events
	if _pending_reset_reason != MatchEvent.ResetReason.NONE:
		return _advance_settlement_step(fixed_delta_seconds, step_events)

	for action in actions:
		if action == null:
			continue
		var was_accepted := false
		if action.action_type == MatchAction.Type.PASS:
			was_accepted = _try_start_pass(action)
		elif action.action_type == MatchAction.Type.SHOOT:
			was_accepted = _try_start_shot(action)
		elif action.action_type == MatchAction.Type.TACKLE:
			was_accepted = _try_start_tackle(action)
		else:
			was_accepted = _player_runtime_system.apply_action(action)
		if was_accepted:
			step_events.append(_create_event(MatchEvent.Type.ACTION_ACCEPTED, action.player_id))
	_player_runtime_system.advance(fixed_delta_seconds)
	var can_acquire_after_motion := (
		_ball_runtime_system.state != null
		and _ball_runtime_system.state.motion_state != BallMatchState.MotionState.IN_FLIGHT
	)
	var ball_result := _ball_runtime_system.advance(
		fixed_delta_seconds,
		_player_runtime_system,
		false,
	)
	var boundary_result: MatchBoundaryResult
	var is_carried_boundary := false
	if ball_result.has_owned_motion_segment and _match_rules != null:
		boundary_result = _match_rules.resolve_ball_boundary(
			ball_result.owned_motion_start_position_m,
			ball_result.owned_motion_end_position_m,
			false,
		)
		is_carried_boundary = boundary_result != null
	if boundary_result == null:
		_append_kick_events(ball_result, step_events)
		if ball_result.has_motion_segment and _match_rules != null:
			boundary_result = _match_rules.resolve_ball_boundary(
				ball_result.motion_start_position_m,
				ball_result.motion_end_position_m,
			)
	if boundary_result != null:
		var exit_velocity_mps := Vector2.ZERO
		if not is_carried_boundary:
			exit_velocity_mps = _ball_runtime_system.state.velocity_mps
			if exit_velocity_mps.is_zero_approx():
				exit_velocity_mps = (
					ball_result.motion_end_position_m - ball_result.motion_start_position_m
				) / fixed_delta_seconds
		return _complete_boundary_step(
			boundary_result,
			step_events,
			is_carried_boundary,
			exit_velocity_mps,
			ball_result.motion_start_position_m,
			ball_result.motion_end_position_m,
			fixed_delta_seconds,
		)
	_resolve_pending_tackles(step_events)
	_append_post_motion_events(ball_result, step_events)
	if can_acquire_after_motion:
		var loose_position_m := _ball_runtime_system.state.position_m
		var possession_result := _ball_runtime_system.acquire_loose_ball(_player_runtime_system)
		if not possession_result.new_owner_player_id.is_empty():
			# Acquisition can place the controlled ball beyond a boundary.
			if _match_rules != null:
				boundary_result = _match_rules.resolve_ball_boundary(
					loose_position_m,
					_ball_runtime_system.state.position_m,
					false,
				)
				if boundary_result != null:
					return _complete_boundary_step(
						boundary_result, step_events, true, Vector2.ZERO
					)
			step_events.append(_create_event(
				MatchEvent.Type.BALL_POSSESSION_GAINED,
				possession_result.new_owner_player_id,
			))
	step_events.append(_create_event(MatchEvent.Type.SIMULATION_ADVANCED))
	_record_step_events(step_events)
	return step_events


## Returns a read-only snapshot with goal counts and the current round phase.
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
		_state.round_phase,
		_state.left_goal_count,
		_state.right_goal_count,
	)


## Transfers lifecycle events exactly once into the next displayed frame.
func drain_lifecycle_events() -> Array[MatchEvent]:
	var drained_events: Array[MatchEvent] = _lifecycle_events.duplicate()
	_lifecycle_events.clear()
	return drained_events


## Returns a copy of the current test's meaningful fixed-step events.
func get_event_history() -> Array[MatchEvent]:
	return _event_history.duplicate()


## Records the result now while leaving the match in a timed settlement phase.
func _complete_boundary_step(
	boundary: MatchBoundaryResult,
	events: Array[MatchEvent],
	is_carried_boundary: bool,
	exit_velocity_mps: Vector2,
	motion_start_m: Vector2 = Vector2.ZERO,
	motion_end_m: Vector2 = Vector2.ZERO,
	fixed_delta_seconds: float = 0.0,
) -> Array[MatchEvent]:
	_settle_boundary(boundary, events, is_carried_boundary, exit_velocity_mps, motion_start_m, motion_end_m, fixed_delta_seconds)
	events.append(_create_event(MatchEvent.Type.SIMULATION_ADVANCED))
	_record_step_events(events)
	return events


## Holds controls during settlement and gives scored balls a bounded net response.
func _advance_settlement_step(
	fixed_delta_seconds: float,
	events: Array[MatchEvent],
) -> Array[MatchEvent]:
	var active_delta_seconds := minf(fixed_delta_seconds, _settlement_remaining_seconds)
	if active_delta_seconds > 0.0:
		if _pending_reset_reason == MatchEvent.ResetReason.GOAL:
			_advance_goal_motion(active_delta_seconds, events)
		elif not _is_carried_settlement:
			_ball_runtime_system.advance_out_of_play(
				active_delta_seconds, _out_of_play_velocity_mps
			)
		_player_runtime_system.advance(active_delta_seconds)
	_settlement_remaining_seconds = maxf(
		_settlement_remaining_seconds - fixed_delta_seconds, 0.0
	)
	if _pending_reset_reason == MatchEvent.ResetReason.GOAL:
		if _goal_motion_elapsed_seconds >= _match_config.goal_net_max_motion_seconds - SETTLEMENT_TIME_EPSILON:
			_reset_round(MatchEvent.ResetReason.GOAL, Vector2.ZERO, events, _pending_reset_side)
		elif _ball_runtime_system.state.velocity_mps.is_zero_approx():
			_reset_round(MatchEvent.ResetReason.GOAL, Vector2.ZERO, events, _pending_reset_side)
	elif _settlement_remaining_seconds <= SETTLEMENT_TIME_EPSILON:
		_reset_round(_pending_reset_reason, Vector2.ZERO, events, _pending_reset_side)
	events.append(_create_event(MatchEvent.Type.SIMULATION_ADVANCED))
	_record_step_events(events)
	return events


## Emits net contacts in sweep order without reopening scoring or player input.
func _advance_goal_motion(delta_seconds: float, events: Array[MatchEvent]) -> void:
	if delta_seconds <= 0.0 or _ball_runtime_system.state.velocity_mps.is_zero_approx():
		return
	var contacts := _ball_runtime_system.advance_post_goal_motion(
		delta_seconds, _field_definition, _match_config, _pending_reset_side
	)
	_goal_motion_elapsed_seconds += delta_seconds
	for contact in contacts:
		events.append(_create_event(
			MatchEvent.Type.GOAL_NET_CONTACT, "", MatchEvent.ResetReason.GOAL,
			_pending_reset_side, contact.contact_position_m, "", 0, false, contact
		))


## Records observable events while omitting the per-step clock tick.
func _record_step_events(events: Array[MatchEvent]) -> void:
	for event in events:
		if event.event_type != MatchEvent.Type.SIMULATION_ADVANCED:
			_event_history.append(event)


## Gives test restart priority and discards all other commands in the same step.
func _find_reset_reason(actions: Array[MatchAction]) -> int:
	var reason := MatchEvent.ResetReason.NONE
	for action in actions:
		if action == null:
			continue
		if action.action_type == MatchAction.Type.RESTART_TEST:
			return MatchEvent.ResetReason.RESTART_TEST
		if action.action_type == MatchAction.Type.RESET_ROUND:
			reason = MatchEvent.ResetReason.MANUAL_ROUND
	return reason


## Emits the kick itself before its trajectory can reach a boundary.
func _append_kick_events(result: BallAdvanceResult, events: Array[MatchEvent]) -> void:
	if not result.passed_by_player_id.is_empty():
		events.append(_create_event(MatchEvent.Type.BALL_PASSED, result.passed_by_player_id))
	if not result.shot_by_player_id.is_empty():
		events.append(_create_event(MatchEvent.Type.BALL_SHOT, result.shot_by_player_id))


## Suppresses pass reception or miss events when the boundary settled first.
func _append_post_motion_events(result: BallAdvanceResult, events: Array[MatchEvent]) -> void:
	if not result.new_owner_player_id.is_empty():
		events.append(_create_event(
			MatchEvent.Type.BALL_POSSESSION_GAINED,
			result.new_owner_player_id,
		))
	if not result.received_by_player_id.is_empty():
		events.append(_create_event(
			MatchEvent.Type.BALL_PASS_RECEIVED,
			result.received_by_player_id,
		))
	if result.was_pass_missed:
		events.append(_create_event(MatchEvent.Type.BALL_PASS_MISSED))


## Records one boundary result and starts its out or post-goal motion window.
func _settle_boundary(
	boundary: MatchBoundaryResult,
	events: Array[MatchEvent],
	is_carried_boundary: bool,
	exit_velocity_mps: Vector2,
	motion_start_m: Vector2,
	motion_end_m: Vector2,
	fixed_delta_seconds: float,
) -> void:
	assert(_pending_reset_reason == MatchEvent.ResetReason.NONE)
	assert(_boundary_reset_delay_seconds > 0.0)
	var last_kicker_id := _ball_runtime_system.last_kicker_id
	_pending_reset_side = boundary.side
	_settlement_remaining_seconds = _boundary_reset_delay_seconds
	_is_carried_settlement = is_carried_boundary
	_out_of_play_velocity_mps = exit_velocity_mps
	var settled_ball_position_m := _ball_runtime_system.state.position_m
	if is_carried_boundary and (
		_ball_runtime_system.state.motion_state != BallMatchState.MotionState.OWNED
	):
		settled_ball_position_m = boundary.ball_position_m
	_ball_runtime_system.prepare_for_settlement(
		_player_runtime_system, is_carried_boundary, settled_ball_position_m
	)
	_player_runtime_system.stop_all_players_for_settlement(is_carried_boundary)
	_pending_tackle_targets.clear()
	if boundary.outcome == MatchBoundaryResult.Outcome.GOAL:
		_pending_reset_reason = MatchEvent.ResetReason.GOAL
		_settlement_remaining_seconds = _match_config.goal_net_max_motion_seconds
		_state._set_round_phase(MatchState.RoundPhase.POST_GOAL_MOTION)
		_state._record_goal(boundary.side)
		var goal_count := _state.left_goal_count
		if boundary.side == MatchBoundaryResult.Side.RIGHT:
			goal_count = _state.right_goal_count
		events.append(_create_event(
			MatchEvent.Type.GOAL_SCORED,
			last_kicker_id,
			MatchEvent.ResetReason.GOAL,
			boundary.side,
			boundary.ball_position_m,
			last_kicker_id,
			goal_count,
		))
		if fixed_delta_seconds > 0.0:
			var crossing_x := _field_definition.length_m * 0.5 + _match_config.ball_radius_m
			if boundary.side == MatchBoundaryResult.Side.LEFT:
				crossing_x = -crossing_x
			var denominator := motion_end_m.x - motion_start_m.x
			var crossing_fraction := clampf(
				(crossing_x - motion_start_m.x) / denominator, 0.0, 1.0
			)
			var crossing_m := motion_start_m.lerp(motion_end_m, crossing_fraction)
			_ball_runtime_system.begin_post_goal_motion(crossing_m, exit_velocity_mps)
			_advance_goal_motion(fixed_delta_seconds * (1.0 - crossing_fraction), events)
	else:
		_pending_reset_reason = MatchEvent.ResetReason.OUT
		_state._set_round_phase(MatchState.RoundPhase.OUT_RESOLVED)
		events.append(_create_event(
			MatchEvent.Type.BALL_OUT_OF_BOUNDS,
			last_kicker_id,
			MatchEvent.ResetReason.OUT,
			boundary.side,
			boundary.ball_position_m,
			last_kicker_id,
			0,
			boundary.is_corner,
		))


## Cancels old actions and ball motion, retaining scores except on full restart.
func _reset_round(
	reason: int,
	ball_reset_position_m: Vector2,
	events: Array[MatchEvent],
	side: int = MatchBoundaryResult.Side.NONE,
) -> void:
	_state._set_round_phase(MatchState.RoundPhase.RESETTING)
	_ball_runtime_system.reset_ball(ball_reset_position_m)
	_player_runtime_system.reset_all_players()
	_pending_tackle_targets.clear()
	_pending_reset_reason = MatchEvent.ResetReason.NONE
	_pending_reset_side = MatchBoundaryResult.Side.NONE
	_settlement_remaining_seconds = 0.0
	_is_carried_settlement = false
	_out_of_play_velocity_mps = Vector2.ZERO
	_goal_motion_elapsed_seconds = 0.0
	if reason == MatchEvent.ResetReason.RESTART_TEST:
		_state._restart_test()
		_lifecycle_events.clear()
		_event_history.clear()
	_state._set_round_phase(MatchState.RoundPhase.PLAYING)
	events.append(_create_event(
		MatchEvent.Type.RESET_COMPLETED,
		"",
		reason,
		side,
		ball_reset_position_m,
	))


## Accepts a tackle command only for a nearby opponent carrying the ball.
func _try_start_tackle(action: MatchAction) -> bool:
	if _match_config == null or action.target_player_id.is_empty():
		return false
	var tackler := _player_runtime_system.get_player(action.player_id)
	var carrier := _player_runtime_system.get_player(action.target_player_id)
	if not _is_legal_tackle_contact(tackler, carrier):
		return false
	if not tackler.state_machine.try_start_tackle(_match_config):
		return false
	_pending_tackle_targets[tackler.player_id] = carrier.player_id
	return true


## Resolves one legal active tackle at a time in stable player-ID order.
func _resolve_pending_tackles(events: Array[MatchEvent]) -> void:
	for tackler in _player_runtime_system.get_players():
		if not _pending_tackle_targets.has(tackler.player_id):
			continue
		if tackler.state.action_state != PlayerMatchState.ActionState.TACKLING:
			_pending_tackle_targets.erase(tackler.player_id)
			continue
		if tackler.state.action_phase == PlayerMatchState.ActionPhase.WINDUP:
			continue
		var carrier_id := _pending_tackle_targets[tackler.player_id]
		_pending_tackle_targets.erase(tackler.player_id)
		var carrier := _player_runtime_system.get_player(carrier_id)
		if not _is_legal_tackle_contact(tackler, carrier):
			continue
		if not _ball_runtime_system.transfer_tackled_ball(carrier, tackler):
			continue
		# Ball ownership changes at contact; the tackle keeps lunging until its configured end.
		carrier.state_machine.start_hit_stun(_match_config.tackle_hit_stun_seconds)
		events.append(MatchEvent.new(
			MatchEvent.Type.TACKLE_SUCCEEDED,
			_state.elapsed_seconds,
			_state.simulation_step,
			tackler.player_id,
			MatchEvent.ResetReason.NONE,
			MatchBoundaryResult.Side.NONE,
			_ball_runtime_system.state.position_m,
			"", 0, false, null,
			carrier.player_id,
			carrier.player_id,
			tackler.player_id,
		))
		events.append(_create_event(
			MatchEvent.Type.BALL_POSSESSION_GAINED, tackler.player_id
		))


## Applies geometry and ownership rules without sampling player attributes.
func _is_legal_tackle_contact(tackler: PlayerRuntime, carrier: PlayerRuntime) -> bool:
	if tackler == null or carrier == null or tackler.player_id == carrier.player_id:
		return false
	if tackler.team_id == carrier.team_id:
		return false
	if _ball_runtime_system.state == null:
		return false
	if _ball_runtime_system.state.owner_player_id != carrier.player_id:
		return false
	if tackler.state.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN:
		return false
	var toward_carrier := carrier.state.position_m - tackler.state.position_m
	if toward_carrier.length() > _match_config.tackle_range_m:
		return false
	if toward_carrier.is_zero_approx():
		return true
	return tackler.state.facing_direction.dot(toward_carrier.normalized()) >= (
		_match_config.tackle_min_facing_dot
	)


## Resolves pass participants before asking the ball system to start windup.
func _try_start_pass(action: MatchAction) -> bool:
	var passer := _player_runtime_system.get_player(action.player_id)
	var receiver := _player_runtime_system.get_player(action.target_player_id)
	return _ball_runtime_system.try_start_pass(passer, receiver)


## Resolves every shot from the shooter's position toward its team's opponent goal.
func _try_start_shot(action: MatchAction) -> bool:
	var shooter := _player_runtime_system.get_player(action.player_id)
	if shooter == null or not _attacking_goals_by_team.has(shooter.team_id):
		return false
	var goal_center_m: Vector2 = _attacking_goals_by_team[shooter.team_id]
	var shot_direction := goal_center_m - shooter.state.position_m
	return _ball_runtime_system.try_start_shot(shooter, shot_direction, action.power)


func _create_event(
	event_type: int,
	subject_id: String = "",
	reason: int = MatchEvent.ResetReason.NONE,
	side: int = MatchBoundaryResult.Side.NONE,
	ball_position_m: Vector2 = Vector2.ZERO,
	last_kicker_id: String = "",
	goal_count: int = 0,
	is_corner: bool = false,
	net_contact: GoalNetContact = null,
) -> MatchEvent:
	return MatchEvent.new(
		event_type,
		_state.elapsed_seconds,
		_state.simulation_step,
		subject_id,
		reason,
		side,
		ball_position_m,
		last_kicker_id,
		goal_count,
		is_corner,
		net_contact,
	)
