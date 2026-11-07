## Owns mutable match state, boundary settlement, resets, and ordered fixed-step events.
class_name MatchSimulation
extends RefCounted

const SETTLEMENT_TIME_EPSILON := 0.000001
const KNOCKDOWN_WINDOW_EPSILON := 0.000001

enum MeleeOutcome {
	TARGET_KNOCKED_DOWN,
	ATTACKER_RECOILS,
	FORMULA,
	BOTH_KNOCKED_DOWN,
	DODGED,
}

var _event_sequence: int = 0
var _boundary_event_time: float = -1.0
var _formal_step_start_seconds: float = 0.0
var _formal_step_delta: float = 0.0
var _formal_player_starts: Dictionary[String, Vector2] = {}
var _kickoff_players: Dictionary[String, String] = {}
var _pending_sideline_position_m: Vector2 = Vector2.INF
var _pending_sideline_team_id: String = ""

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
var _pending_knockdown_targets: Dictionary[String, String] = {}
var _pending_header_actions: Dictionary[String, MatchAction] = {}
var _melee_outcome: MeleeOutcome
var _melee_dodge_sampler: Callable
var _melee_strength_sampler: Callable
var _melee_sequence: int = 0
var _pending_melee_sequences: Dictionary[String, int] = {}
var _ball_contact_latches: Dictionary[String, bool] = {}
var _contact_shot_source: BallShotSource
var _ball_route_sampler: Callable
var _shot_miss_sampler: Callable
var _shot_miss_side_sampler: Callable
var _shot_miss_margin_sampler: Callable
var _shot_miss_override: int
var _shot_aim_sampler: Callable
var _keeper_sampler: Callable
var _tackle_sampler: Callable
var _keeper_intents: Dictionary[String, float] = {}
var _keeper_resolved: Dictionary[String, bool] = {}
var _ball_dodge_result: Callable


## Injects deterministic randomness and optional validated field and ball rules.
func _init(
	random_seed: int,
	match_config: MatchConfigDefinition = null,
	field_definition: FieldDefinition = null,
	melee_outcome: MeleeOutcome = MeleeOutcome.FORMULA,
	ball_route_sampler: Callable = Callable(),
	ball_dodge_result: Callable = Callable(),
	shot_aim_sampler: Callable = Callable(),
	keeper_sampler: Callable = Callable(),
	tackle_sampler: Callable = Callable(),
	shot_miss_sampler: Callable = Callable(),
	shot_miss_side_sampler: Callable = Callable(),
	shot_miss_margin_sampler: Callable = Callable(),
	shot_miss_override: int = -1,
	melee_dodge_sampler: Callable = Callable(),
	melee_strength_sampler: Callable = Callable(),
) -> void:
	_state = MatchState.new(random_seed)
	_rng.seed = random_seed
	_match_config = match_config
	_field_definition = field_definition
	_melee_outcome = melee_outcome
	_melee_dodge_sampler = melee_dodge_sampler if melee_dodge_sampler.is_valid() else _sample_ball_route
	_melee_strength_sampler = melee_strength_sampler if melee_strength_sampler.is_valid() else _sample_ball_route
	_ball_route_sampler = ball_route_sampler if ball_route_sampler.is_valid() else _sample_ball_route
	assert(shot_miss_override >= -1 and shot_miss_override <= 1)
	_shot_miss_sampler = shot_miss_sampler
	_shot_miss_side_sampler = shot_miss_side_sampler
	_shot_miss_margin_sampler = shot_miss_margin_sampler
	_shot_miss_override = shot_miss_override
	_shot_aim_sampler = shot_aim_sampler
	_keeper_sampler = keeper_sampler if keeper_sampler.is_valid() else _sample_ball_route
	_tackle_sampler = tackle_sampler if tackle_sampler.is_valid() else _sample_ball_route
	_ball_runtime_system.configure_shot_aim(_select_shot_aim)
	_ball_dodge_result = ball_dodge_result
	if match_config != null:
		_ball_runtime_system.configure_match_rules(match_config)
		_boundary_reset_delay_seconds = match_config.boundary_reset_delay_seconds
	if field_definition != null:
		assert(match_config != null, "Field boundaries require a ball radius configuration")
		assert(field_definition.goal_depth_m > match_config.ball_radius_m * 2.0,
			"Ball must fit between the score line and back net")
		_match_rules = MatchRules.new(field_definition, match_config.ball_radius_m)


## Registers a player only before play, with explicit static contest attributes.
func register_player(
	player_id: String,
	initial_position_m: Vector2,
	movement_speed_mps: float = PlayerStateMachine.DEFAULT_MOVEMENT_SPEED_MPS,
	team_id: String = "default_team",
	shooting_attribute: int = 0,
	strength_attribute: int = 50,
	technique_attribute: int = 50,
	is_goalkeeper: bool = false,
	speed_attribute: int = 0,
	tackling_attribute: int = 50,
	goalkeeping_attribute: int = 50,
) -> bool:
	if _state.phase != MatchState.Phase.READY or is_formal() or not initial_position_m.is_finite():
		return false
	var registered := _player_runtime_system.register_player(
		player_id,
		initial_position_m,
		movement_speed_mps,
		team_id,
		shooting_attribute,
		strength_attribute,
		technique_attribute,
		is_goalkeeper,
		speed_attribute,
		tackling_attribute,
		goalkeeping_attribute,
	)
	if registered:
		_orient_goalkeeper(_player_runtime_system.get_player(player_id))
	return registered


## Binds CSV speed through F01 while keeping explicit contest overrides confined to test setups.
func register_player_from_definition(
	definition: PlayerDefinition,
	initial_position_m: Vector2,
	team_id: String,
	is_goalkeeper: bool = false,
	shooting_override: int = -1,
	strength_override: int = -1,
) -> bool:
	if definition == null or _match_config == null or definition.speed < 1 or definition.speed > 100:
		return false
	if shooting_override < -1 or shooting_override > 100 or strength_override < -1 or strength_override > 100:
		return false
	var speed_mps := PlayerRuntime.calculate_movement_speed_mps(
		definition.speed, _match_config.player_speed_at_100_mps)
	return register_player(definition.player_id, initial_position_m, speed_mps, team_id,
		definition.shooting if shooting_override == -1 else shooting_override,
		definition.strength if strength_override == -1 else strength_override,
		definition.technique, is_goalkeeper, definition.speed, definition.tackling, definition.goalkeeping)


## Associates a team with its opponent goal center before the match starts.
func register_team_attacking_goal(team_id: String, goal_center_m: Vector2) -> bool:
	if _state.phase != MatchState.Phase.READY or is_formal():
		return false
	if team_id.is_empty() or not goal_center_m.is_finite():
		return false
	if _attacking_goals_by_team.has(team_id):
		return false
	_attacking_goals_by_team[team_id] = goal_center_m
	for player in _player_runtime_system.get_players():
		_orient_goalkeeper(player)
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
	_queue_lifecycle_event(_create_event(MatchEvent.Type.MATCH_STARTED))
	if _state.kickoff_pending:
		_queue_lifecycle_event(_create_event(MatchEvent.Type.BALL_POSSESSION_GAINED, _state.kickoff_player_id))
	return true


## Suspends simulation without advancing timers or ball motion.
func pause_match() -> bool:
	if _state.phase != MatchState.Phase.RUNNING:
		return false
	_state._set_phase(MatchState.Phase.PAUSED)
	if is_formal():
		_invalidate_formal_intents()
	_queue_lifecycle_event(_create_event(MatchEvent.Type.MATCH_PAUSED))
	return true


## Resumes a paused match at the same simulation time.
func resume_match() -> bool:
	if _state.phase != MatchState.Phase.PAUSED:
		return false
	_state._set_phase(MatchState.Phase.RUNNING)
	_queue_lifecycle_event(_create_event(MatchEvent.Type.MATCH_RESUMED))
	return true


## Stops all future simulation steps after a match ends.
func finish_match() -> bool:
	if is_formal():
		return false
	if _state.phase != MatchState.Phase.RUNNING and _state.phase != MatchState.Phase.PAUSED:
		return false
	_state._set_phase(MatchState.Phase.FINISHED)
	_queue_lifecycle_event(_create_event(MatchEvent.Type.MATCH_FINISHED))
	return true


func is_running() -> bool:
	return _state.phase == MatchState.Phase.RUNNING


## Initializes a validated twelve-player formal match while keeping isolated demos backwards compatible.
func configure_formal_match(id: String, home: String, away: String) -> bool:
	if _state.phase != MatchState.Phase.READY or is_formal() or id.is_empty() or home.is_empty() or home == away:
		return false
	if _match_config == null or _field_definition == null or _ball_runtime_system.state == null:
		return false
	var players := _player_runtime_system.get_players()
	if players.size() != 12 or not _attacking_goals_by_team.has(home) or not _attacking_goals_by_team.has(away):
		return false
	if not _attacking_goals_by_team[home].is_equal_approx(-_attacking_goals_by_team[away]):
		return false
	for team in [home, away]:
		var count := 0
		var keepers := 0
		for player in players:
			if player.team_id == team:
				count += 1
				keepers += int(player.is_goalkeeper)
		if count != 6 or keepers != 1:
			return false
	_state._configure_formal(id, home, away, _match_config.match_duration_seconds)
	return true

func is_formal() -> bool:
	return not _state.match_id.is_empty()

## Enables production kickoff only after both complete formal rosters are validated.
func configure_kickoff(kickers: Dictionary[String, String]) -> bool:
	if not is_formal() or _state.phase != MatchState.Phase.READY or not _kickoff_players.is_empty():
		return false
	if _field_definition.center_circle_radius_m + _match_config.ball_radius_m >= _field_definition.length_m * 0.5:
		return false
	for team in [_state.home_team_id, _state.away_team_id]:
		var player := _player_runtime_system.get_player(kickers.get(team, ""))
		if player == null or player.team_id != team or player.is_goalkeeper:
			return false
	_kickoff_players = kickers.duplicate()
	_prepare_kickoff(MatchKickoffRules.select_team(_state.random_seed, _state.home_team_id, _state.away_team_id))
	return true

## Commits layout and sole possession through existing state machines and ordinary pickup rules.
func _prepare_kickoff(team: String) -> void:
	var kicker_id: String = _kickoff_players[team]
	_ball_runtime_system.reset_ball(Vector2.ZERO)
	for player in _player_runtime_system.get_players():
		var direction := signf(_attacking_goals_by_team[player.team_id].x)
		var point := MatchKickoffRules.position(player.spawn_position_m, direction,
			player.player_id == kicker_id, player.team_id != team, _field_definition, _match_config)
		player.state_machine.reset_to_spawn(point)
		player.state._set_facing_direction(Vector2(direction, 0))
	var acquired := _ball_runtime_system.acquire_loose_ball(_player_runtime_system)
	assert(acquired.new_owner_player_id == kicker_id, "Validated kickoff must assign the sole center-ball owner")
	_state._set_kickoff(team, kicker_id, true)

## Closes only the kickoff restriction; ordinary phase and per-action eligibility remain unchanged.
func _complete_kickoff() -> void:
	if _state.kickoff_pending:
		_state._set_kickoff(_state.kickoff_team_id, _state.kickoff_player_id, false)

func can_decide_player_actions() -> bool:
	return MatchControlPolicy.can_decide(_state.phase, _state.round_phase)

## Validates stamped batches immediately before mutation; stale payloads cannot regain authority.
func advance_action_batch(delta: float, batch: MatchActionBatch) -> Array[MatchEvent]:
	var actions: Array[MatchAction] = []
	if batch != null and batch.matches(create_snapshot()) and can_decide_player_actions():
		actions = batch.actions
	return advance_fixed_step(delta, actions)

## Clips formal time exactly at the deadline and commits one result after all earlier eligible facts.
func advance_fixed_step(delta: float, actions: Array[MatchAction]) -> Array[MatchEvent]:
	assert(is_finite(delta) and delta > 0.0)
	if not is_formal():
		return _advance_play_step(delta, actions)
	if not is_running():
		return []
	var effective := minf(delta, maxf(_state.duration_seconds - _state.elapsed_seconds, 0.0))
	_formal_step_start_seconds = _state.elapsed_seconds
	_formal_step_delta = effective
	_formal_player_starts.clear()
	for player in _player_runtime_system.get_players():
		_formal_player_starts[player.player_id] = player.state.position_m
	var eligible: Array[MatchAction] = []
	if can_decide_player_actions():
		for action in actions:
			if action != null and action.action_type not in [MatchAction.Type.RESET_ROUND, MatchAction.Type.RESTART_TEST]:
				eligible.append(action)
	var events: Array[MatchEvent] = []
	if effective > 0.0:
		events = _advance_play_step(effective, eligible)
	if _state.elapsed_seconds >= _state.duration_seconds - MatchRules.TIME_EPSILON:
		_state._clamp_elapsed(_state.duration_seconds)
		_finish_formal(events)
	return events

## Cancels observation without manufacturing a normal win/draw/loss result.
func cancel_match(reason: String = "cancelled") -> bool:
	if _state.phase not in [MatchState.Phase.READY, MatchState.Phase.RUNNING, MatchState.Phase.PAUSED]:
		return false
	_state._set_cancellation_reason(reason)
	_state._set_phase(MatchState.Phase.CANCELLED)
	_invalidate_formal_intents()
	_ball_runtime_system.freeze_for_terminal()
	_pending_reset_reason = MatchEvent.ResetReason.NONE
	_queue_lifecycle_event(_create_event(MatchEvent.Type.MATCH_CANCELLED))
	return true

## Drops cached intentions while retaining current actor action progress and random-source position.
func _invalidate_formal_intents() -> void:
	_player_runtime_system.stop_all_players_for_settlement(false)
	_pending_tackle_targets.clear()
	_pending_knockdown_targets.clear()
	_pending_melee_sequences.clear()
	_pending_header_actions.clear()
	_keeper_intents.clear()
	_ball_runtime_system.cancel_pending_actions()

## Freezes official scores and publishes exactly one terminal result, preempting any pending reset.
func _finish_formal(events: Array[MatchEvent]) -> void:
	if _state.phase != MatchState.Phase.RUNNING:
		return
	_state._set_result(FormalMatchResult.new(_state.match_id, _state.home_team_id, _state.away_team_id,
		_state.home_score, _state.away_score, _state.random_seed, _state.elapsed_seconds))
	_state._set_phase(MatchState.Phase.FINISHED)
	_invalidate_formal_intents()
	_ball_runtime_system.freeze_for_terminal()
	_pending_reset_reason = MatchEvent.ResetReason.NONE
	_settlement_remaining_seconds = 0.0
	var event := _create_event(MatchEvent.Type.MATCH_FINISHED)
	_publish_event(event)
	_event_history.append(event)
	events.append(event)

## Publishes lifecycle events immediately, including controls performed outside a fixed step.
func _queue_lifecycle_event(event: MatchEvent) -> void:
	_publish_event(event)
	_lifecycle_events.append(event)
	if is_formal():
		_event_history.append(event)

## Assigns monotonically increasing stream order only at the single publication boundary.
func _publish_event(event: MatchEvent) -> void:
	if event.event_sequence != 0:
		return
	if event.match_id.is_empty():
		event._capture_context(_state)
	_event_sequence += 1
	event._set_sequence(_event_sequence)

## Records instantaneous round transitions without requiring a separate rendered frame.
func _transition_round(phase: int, events: Array[MatchEvent]) -> void:
	if _state.round_phase == phase:
		return
	if is_formal():
		for event in events:
			if event.match_id.is_empty():
				event._capture_context(_state)
	_state._set_round_phase(phase)
	if is_formal():
		events.append(_create_event(MatchEvent.Type.ROUND_PHASE_CHANGED))

## Gives manual resets priority, then advances settlement or active play.
func _advance_play_step(
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
	if is_formal() and not can_decide_player_actions():
		step_events.append(_create_event(MatchEvent.Type.SIMULATION_ADVANCED))
		_record_step_events(step_events)
		return step_events

	var kickoff_player := _state.kickoff_player_id if _state.kickoff_pending else ""
	for action in actions:
		if action == null:
			continue
		if not kickoff_player.is_empty() and (action.player_id != kickoff_player
			or action.action_type not in [MatchAction.Type.MOVE, MatchAction.Type.PASS, MatchAction.Type.SHOOT]):
			continue
		var was_accepted := false
		if action.action_type == MatchAction.Type.PASS:
			was_accepted = _try_start_pass(action)
		elif action.action_type == MatchAction.Type.SHOOT:
			was_accepted = _try_start_shot(action)
		elif action.action_type == MatchAction.Type.TACKLE:
			was_accepted = _try_start_tackle(action)
		elif action.action_type == MatchAction.Type.ATTACK:
			was_accepted = _try_start_knockdown(action)
		elif action.action_type == MatchAction.Type.SAVE:
			was_accepted = _try_start_save(action, fixed_delta_seconds)
			if was_accepted:
				step_events.append(_create_event(MatchEvent.Type.GOALKEEPER_SAVE_STARTED, action.player_id))
		elif action.action_type == MatchAction.Type.JUMP:
			was_accepted = _try_start_jump(action)
		elif action.action_type in [MatchAction.Type.HEADER_SHOT, MatchAction.Type.HEADER_CLEAR]:
			was_accepted = _try_prepare_header(action)
		else:
			was_accepted = _player_runtime_system.apply_action(action)
		if was_accepted:
			if action.action_type == MatchAction.Type.MOVE and not action.direction.is_zero_approx():
				_complete_kickoff()
			step_events.append(_create_event(MatchEvent.Type.ACTION_ACCEPTED, action.player_id))
	# Check frame-start contact before movement can carry the attacker past a nearby target.
	var was_ball_released_by_knockdown := _resolve_pending_knockdowns(step_events)
	var recovering_player_ids: Array[String] = []
	var player_start_positions: Dictionary[String, Vector2] = {}
	var player_start_heights: Dictionary[String, float] = {}
	for player in _player_runtime_system.get_players():
		player_start_positions[player.player_id] = player.state.position_m
		player_start_heights[player.player_id] = player.state.height_m
		if player.state.action_state == PlayerMatchState.ActionState.GETTING_UP:
			recovering_player_ids.append(player.player_id)
	_player_runtime_system.advance(fixed_delta_seconds)
	for player_id in recovering_player_ids:
		if _player_runtime_system.get_player(player_id).state.action_state == (
			PlayerMatchState.ActionState.IDLE
		):
			step_events.append(_create_event(MatchEvent.Type.PLAYER_RECOVERED, player_id))
	var header_contact := _find_header_contact(
		fixed_delta_seconds, player_start_positions, player_start_heights)
	var header_action: MatchAction
	var header_direction := Vector2.ZERO
	if header_contact != null and _pending_header_actions.has(header_contact.player_id):
		header_action = _pending_header_actions[header_contact.player_id]
		header_direction = _header_direction(header_contact, header_action)
		var heading_player := _player_runtime_system.get_player(header_contact.player_id)
		if header_direction.is_zero_approx() or (
			not heading_player.state_machine.try_start_header(_match_config, header_direction)
		):
			header_contact = null
			header_action = null
	if header_contact != null and header_action == null:
		header_contact = null
	var ball_result := _ball_runtime_system.advance(
		fixed_delta_seconds,
		_player_runtime_system,
		false,
		header_contact,
		header_action,
		header_direction,
		true,
		player_start_positions,
		player_start_heights,
	)
	if _ball_runtime_system.state == null or (
		_ball_runtime_system.state.motion_state != BallMatchState.MotionState.IN_FLIGHT
	) or (
		_ball_runtime_system.state.flight_kind != BallMatchState.FlightKind.PASS
	):
		_pending_header_actions.clear()
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
			if ball_result.has_pre_header_segment:
				boundary_result = _match_rules.resolve_ball_boundary(
					ball_result.pre_header_start_position_m,
					ball_result.pre_header_end_position_m,
				)
			if boundary_result == null:
				boundary_result = _match_rules.resolve_ball_boundary(
					ball_result.motion_start_position_m,
					ball_result.motion_end_position_m,
				)
	if boundary_result == null and _match_rules != null and not ball_result.new_owner_player_id.is_empty():
		# The flight segment stops at contact, before the controlled ball moves to the receiver's foot.
		boundary_result = _match_rules.resolve_ball_boundary(
			ball_result.motion_end_position_m, _ball_runtime_system.state.position_m, false)
		is_carried_boundary = boundary_result != null
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
	if ball_result.deferred_shot_seconds > 0.0 and _advance_shot_contacts(
		ball_result.deferred_shot_seconds, fixed_delta_seconds,
		player_start_positions, player_start_heights, step_events
	):
		step_events.append(_create_event(MatchEvent.Type.SIMULATION_ADVANCED))
		_record_step_events(step_events)
		return step_events
	_resolve_pending_tackles(step_events)
	var released_after_motion := _resolve_pending_knockdowns(step_events)
	was_ball_released_by_knockdown = (
		was_ball_released_by_knockdown or released_after_motion
	)
	_append_post_motion_events(ball_result, step_events)
	if _ball_runtime_system.state != null and not was_ball_released_by_knockdown:
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


## Advances only to the first contact, commits it, and rebuilds the unused interval.
func _advance_shot_contacts(seconds: float, fixed_seconds: float,
		start_positions: Dictionary[String, Vector2], start_heights: Dictionary[String, float],
		events: Array[MatchEvent]) -> bool:
	var source := _ball_runtime_system.shot_source
	var context := _ball_runtime_system.shot_context
	if source != _contact_shot_source:
		_ball_contact_latches.clear()
		_contact_shot_source = source
		_keeper_resolved.clear()
	var remaining := seconds
	var elapsed := fixed_seconds - seconds
	while remaining > 0.00000001:
		var ball := _ball_runtime_system.state
		if ball.motion_state != BallMatchState.MotionState.IN_FLIGHT:
			break
		var trajectory := BallShotTrajectory.new(ball, remaining, _match_config)
		var bodies := _shot_contact_bodies(source, elapsed, trajectory.duration_seconds,
			fixed_seconds, start_positions, start_heights)
		var candidates := BallContactResolver.find_candidates(
			trajectory, bodies, _match_config, _match_rules, _ball_contact_latches)
		var control := _ball_runtime_system.find_control_contact(trajectory,
			_player_runtime_system, start_positions, start_heights, fixed_seconds, elapsed)
		if control != null and (candidates.is_empty()
			or control.time_seconds < candidates[0].time_seconds - BallContactResolver.EPSILON):
			_ball_runtime_system.advance_shot_motion(control.time_seconds)
			var reception := _ball_runtime_system.acquire_contact_ball(control, _player_runtime_system)
			# Body/whole-ball boundary contacts win exact ties; control cancels the old shot.
			if _match_rules != null:
				var boundary := _match_rules.resolve_ball_boundary(
					control.position_m, _ball_runtime_system.state.position_m, false)
				if boundary != null:
					_settle_boundary(boundary, events, true, Vector2.ZERO,
						Vector2.ZERO, Vector2.ZERO, 0.0)
					return true
			_append_post_motion_events(reception, events)
			break
		if candidates.is_empty():
			# Landing splits height prediction; continue through the unused ground interval.
			_ball_runtime_system.advance_shot_motion(trajectory.duration_seconds)
			remaining = maxf(remaining - trajectory.duration_seconds, 0.0)
			elapsed += trajectory.duration_seconds
			if trajectory.duration_seconds <= BallContactResolver.EPSILON:
				break
			continue
		var contact := candidates[0]
		_ball_runtime_system.advance_shot_motion(contact.time_seconds)
		remaining = maxf(remaining - contact.time_seconds, 0.0)
		elapsed += contact.time_seconds
		if contact.kind == BallContactCandidate.Kind.BOUNDARY:
			_settle_shot_contact_boundary(contact, remaining, events)
			return true
		# A latched body cannot consume zero time twice without full geometric separation.
		_ball_contact_latches[contact.player_id] = true
		if contact.kind == BallContactCandidate.Kind.GOALKEEPER:
			_commit_keeper_save(contact, source, events,
				_state.elapsed_seconds - fixed_seconds + elapsed, context, trajectory.direction)
			continue
		_commit_ball_impact(contact, source, events,
			_state.elapsed_seconds - fixed_seconds + elapsed, context)
	return false


## Interpolates each remaining body path while excluding teammates and unavailable targets.
func _shot_contact_bodies(source: BallShotSource, elapsed: float, duration: float,
		fixed_seconds: float, starts: Dictionary[String, Vector2],
		heights: Dictionary[String, float]) -> Array[BallContactPlayer]:
	var bodies: Array[BallContactPlayer] = []
	if source == null:
		return bodies
	for player in _player_runtime_system.get_players():
		if player.team_id == source.team_id or player.state.action_state in [
			PlayerMatchState.ActionState.KNOCKED_DOWN, PlayerMatchState.ActionState.GETTING_UP,
		]:
			continue
		var start := starts[player.player_id]
		var end := player.state.position_m
		var start_height := heights[player.player_id]
		var body := BallContactPlayer.new(player.player_id,
			start.lerp(end, elapsed / fixed_seconds),
			start.lerp(end, (elapsed + duration) / fixed_seconds),
			lerpf(start_height, player.state.height_m, elapsed / fixed_seconds),
			lerpf(start_height, player.state.height_m, (elapsed + duration) / fixed_seconds),
			player.is_goalkeeper)
		if player.is_goalkeeper:
			if _keeper_resolved.has(player.player_id) or not _keeper_intents.has(player.player_id):
				continue
			if player.state.action_state not in [PlayerMatchState.ActionState.SAVING, PlayerMatchState.ActionState.IDLE]:
				continue
			var save_elapsed := _state.elapsed_seconds - fixed_seconds + elapsed - _keeper_intents[player.player_id]
			body.earliest_seconds = maxf(_match_config.keeper_window_start_seconds - save_elapsed, 0.0)
			body.latest_seconds = minf(_match_config.keeper_window_end_seconds - save_elapsed, duration)
			if body.earliest_seconds > body.latest_seconds:
				continue
			var side := float(player.state.save_lane - ShotAim.Lane.CENTER)
			var forward := player.state.facing_direction * _match_config.keeper_hand_forward_m
			var hand_offset := forward + Vector2(0.0, side * _match_config.keeper_hand_lateral_m)
			body.start_position_m += hand_offset
			body.end_position_m += hand_offset
			body.radius_m = _match_config.keeper_contact_radius_m
			body.body_height_m = _match_config.keeper_contact_height_m
		bodies.append(body)
	return bodies


## Commits separate contact, F07 outcome, F08 knockdown, and trajectory facts in order.
func _commit_ball_impact(contact: BallContactCandidate, source: BallShotSource,
		events: Array[MatchEvent], contact_time: float, context: ShotFlightContext) -> void:
	var target := _player_runtime_system.get_player(contact.player_id)
	# F07 is injected independently here; full attribute/probability binding is a later feature.
	var dodged := (_ball_dodge_result.is_valid()
		and bool(_ball_dodge_result.call(contact.player_id)))
	var result := BallImpactResolver.resolve(contact, source, target.strength_attribute,
		_ball_runtime_system.state.velocity_mps, _match_config, _ball_route_sampler, dodged)
	_append_impact_event(MatchEvent.Type.BALL_CONTACT, result, contact_time, events)
	if result.did_dodge:
		_append_impact_event(MatchEvent.Type.BALL_DODGED, result, contact_time, events)
		return
	_append_impact_event(MatchEvent.Type.BALL_HIT, result, contact_time, events)
	if target.team_id != source.team_id:
		_ball_runtime_system.record_defensive_touch(target.player_id)
	if result.was_knocked_down and target.state_machine.start_knockdown(_match_config):
		target.state._set_position(contact.player_position_m)
		var did_start_knockback := target.state_machine.start_knockback(
			result.velocity_before_mps, _match_config.ball_impact_knockback_distance_m,
			_match_config.ball_impact_knockback_duration_seconds,
			_match_config.ball_impact_knockback_apex_height_m)
		assert(did_start_knockback, "A legal football knockdown requires a forced response")
		context._record_knockdown(target.player_id)
		_append_impact_event(MatchEvent.Type.PLAYER_KNOCKED_DOWN, result, contact_time, events)
	_ball_runtime_system.apply_impact(result)
	_append_impact_event(MatchEvent.Type.BALL_REBOUNDED
		if result.route == BallImpactResult.Route.REBOUND else MatchEvent.Type.BALL_CONTINUED,
		result, contact_time, events)


## Publishes immutable impact data and preserves the exact contact timestamp.
func _append_impact_event(type: int, result: BallImpactResult, time: float,
		events: Array[MatchEvent]) -> void:
	var subject := result.target_player_id if type == MatchEvent.Type.PLAYER_KNOCKED_DOWN \
		else result.source.player_id
	events.append(MatchEvent.new(type, time, _state.simulation_step, subject,
		MatchEvent.ResetReason.NONE, MatchBoundaryResult.Side.NONE, result.position_m,
		result.source.player_id, 0, false, null, result.target_player_id, "", "", result))


## Settles the first whole-ball crossing and spends only the unused post-contact time.
func _settle_shot_contact_boundary(contact: BallContactCandidate, remaining: float,
		events: Array[MatchEvent]) -> void:
	if is_formal():
		_boundary_event_time = _state.elapsed_seconds - remaining
		if _boundary_event_time >= _state.duration_seconds - MatchRules.TIME_EPSILON:
			_boundary_event_time = -1.0
			return
	var velocity := _ball_runtime_system.state.velocity_mps
	_settle_boundary(contact.boundary, events, false, velocity, Vector2.ZERO, Vector2.ZERO, 0.0)
	_boundary_event_time = -1.0
	if contact.boundary.outcome == MatchBoundaryResult.Outcome.GOAL:
		_ball_runtime_system.begin_post_goal_motion(contact.position_m, velocity)
		_advance_goal_motion(remaining, events)
	else:
		_ball_runtime_system.advance_out_of_play(remaining, velocity)


## Supplies one seeded sample; each contest calls it only after confirming its own eligibility.
func _sample_ball_route() -> float:
	return float(_rng.randi()) / 4294967296.0


## Returns a read-only snapshot with goal counts and the current round phase.
func create_snapshot() -> MatchStateSnapshot:
	var player_snapshots: Array[PlayerStateSnapshot] = []
	for player_runtime in _player_runtime_system.get_players():
		player_snapshots.append(PlayerStateSnapshot.new(player_runtime.state, player_runtime.team_id, player_runtime.is_goalkeeper, player_runtime))
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
		_state,
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
	if is_formal():
		_boundary_event_time = _formal_step_start_seconds + _formal_step_delta * boundary.crossing_fraction
		if _boundary_event_time >= _state.duration_seconds - MatchRules.TIME_EPSILON:
			_boundary_event_time = -1.0
			_record_step_events(events)
			return events
	_settle_boundary(boundary, events, is_carried_boundary, exit_velocity_mps, motion_start_m, motion_end_m, fixed_delta_seconds)
	_boundary_event_time = -1.0
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
			_advance_goal_motion(active_delta_seconds, events, _state.elapsed_seconds - fixed_delta_seconds)
		elif not _is_carried_settlement:
			_ball_runtime_system.advance_out_of_play(
				active_delta_seconds, _out_of_play_velocity_mps
			)
		if is_formal():
			_player_runtime_system.advance_settlement(active_delta_seconds)
		else:
			_player_runtime_system.advance(active_delta_seconds)
	_settlement_remaining_seconds = maxf(
		_settlement_remaining_seconds - fixed_delta_seconds, 0.0
	)
	var is_save_playing := false
	for player in _player_runtime_system.get_players():
		if player.state.action_state == PlayerMatchState.ActionState.SAVING:
			if active_delta_seconds < fixed_delta_seconds:
				player.advance(fixed_delta_seconds - active_delta_seconds)
			is_save_playing = is_save_playing or player.state.action_state == PlayerMatchState.ActionState.SAVING
	if is_save_playing:
		events.append(_create_event(MatchEvent.Type.SIMULATION_ADVANCED))
		_record_step_events(events)
		return events
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
func _advance_goal_motion(delta_seconds: float, events: Array[MatchEvent], start_time: float = -1.0) -> void:
	if delta_seconds <= 0.0 or _ball_runtime_system.state.velocity_mps.is_zero_approx():
		return
	var contacts := _ball_runtime_system.advance_post_goal_motion(
		delta_seconds, _field_definition, _match_config, _pending_reset_side
	)
	_goal_motion_elapsed_seconds += delta_seconds
	for contact in contacts:
		var previous_time := _boundary_event_time
		if is_formal():
			_boundary_event_time = (_state.elapsed_seconds - delta_seconds if start_time < 0.0 else start_time) + contact.time_seconds
			if _boundary_event_time >= _state.duration_seconds - MatchRules.TIME_EPSILON:
				_boundary_event_time = previous_time
				continue
		events.append(_create_event(
			MatchEvent.Type.GOAL_NET_CONTACT, "", MatchEvent.ResetReason.GOAL,
			_pending_reset_side, contact.contact_position_m, "", 0, false, contact
		))
		_boundary_event_time = previous_time


## Records observable events while omitting the per-step clock tick.
func _record_step_events(events: Array[MatchEvent]) -> void:
	for event in events:
		_publish_event(event)
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
	if not result.passed_by_player_id.is_empty() or not result.shot_by_player_id.is_empty():
		_complete_kickoff()
	if not result.passed_by_player_id.is_empty():
		events.append(_create_event(MatchEvent.Type.BALL_PASSED, result.passed_by_player_id))
	if not result.shot_by_player_id.is_empty():
		events.append(_create_event(MatchEvent.Type.BALL_SHOT, result.shot_by_player_id))
	if not result.header_by_player_id.is_empty():
		events.append(_create_event(MatchEvent.Type.HEADER_CONTEST_WON,
			result.header_by_player_id, MatchEvent.ResetReason.NONE,
			MatchBoundaryResult.Side.NONE, result.header_contact_position_m))
		events.append(_create_event(MatchEvent.Type.BALL_HEADED,
			result.header_by_player_id, MatchEvent.ResetReason.NONE,
			MatchBoundaryResult.Side.NONE, result.header_contact_position_m))


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
	if is_formal():
		var fraction := clampf((_boundary_event_time - _formal_step_start_seconds) / maxf(_formal_step_delta, MatchRules.TIME_EPSILON), 0.0, 1.0)
		for player in _player_runtime_system.get_players():
			if _formal_player_starts.has(player.player_id):
				player.state._set_position(_formal_player_starts[player.player_id].lerp(player.state.position_m, fraction))
		_invalidate_formal_intents()
	var last_kicker_id := _ball_runtime_system.last_kicker_id
	_pending_sideline_position_m = Vector2.INF
	_pending_sideline_team_id = ""
	if is_formal() and not _kickoff_players.is_empty() \
			and boundary.outcome == MatchBoundaryResult.Outcome.OUT \
			and boundary.side in [MatchBoundaryResult.Side.TOP, MatchBoundaryResult.Side.BOTTOM]:
		var touch_id := _ball_runtime_system.state.owner_player_id
		if touch_id.is_empty():
			touch_id = _ball_runtime_system.last_touch_player_id
		var toucher := _player_runtime_system.get_player(touch_id)
		_pending_sideline_team_id = SidelineRestartRules.restart_team(
			toucher.team_id if toucher != null else "", _state.home_team_id, _state.away_team_id,
			_state.kickoff_team_id)
		_pending_sideline_position_m = SidelineRestartRules.ball_position(
			boundary.ball_position_m, boundary.side, _field_definition, _match_config.ball_radius_m)
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
	_pending_knockdown_targets.clear()
	_pending_melee_sequences.clear()
	_pending_header_actions.clear()
	if boundary.outcome == MatchBoundaryResult.Outcome.GOAL:
		_pending_reset_reason = MatchEvent.ResetReason.GOAL
		_settlement_remaining_seconds = _match_config.goal_net_max_motion_seconds
		_transition_round(MatchState.RoundPhase.GOAL_RESOLVED, events)
		_state._record_goal(boundary.side)
		if is_formal():
			for team_id in _attacking_goals_by_team:
				var goal: Vector2 = _attacking_goals_by_team[team_id]
				if (goal.x < 0.0) == (boundary.side == MatchBoundaryResult.Side.LEFT):
					_state._record_team_goal(team_id)
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
		_transition_round(MatchState.RoundPhase.POST_GOAL_MOTION, events)
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
		_transition_round(MatchState.RoundPhase.OUT_RESOLVED, events)
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
	if is_formal() and _state.elapsed_seconds >= _state.duration_seconds - MatchRules.TIME_EPSILON:
		return
	_transition_round(MatchState.RoundPhase.RESETTING, events)
	var is_sideline := reason == MatchEvent.ResetReason.OUT and _pending_sideline_position_m.is_finite()
	var restart_team := _pending_sideline_team_id
	var restart_player := ""
	if is_sideline:
		ball_reset_position_m = _pending_sideline_position_m
		restart_player = SidelineRestartRules.select_taker(create_snapshot().players, restart_team, ball_reset_position_m)
	_ball_runtime_system.reset_ball(ball_reset_position_m)
	if is_sideline:
		for player in _player_runtime_system.get_players():
			var facing := player.state.facing_direction
			player.state_machine.reset_to_spawn(player.state.position_m)
			player.state._set_facing_direction(facing)
	else:
		_player_runtime_system.reset_all_players()
	for player in _player_runtime_system.get_players():
		_orient_goalkeeper(player)
	_pending_tackle_targets.clear()
	_pending_knockdown_targets.clear()
	_pending_melee_sequences.clear()
	_pending_header_actions.clear()
	_ball_contact_latches.clear()
	_contact_shot_source = null
	_keeper_intents.clear()
	_keeper_resolved.clear()
	_pending_reset_reason = MatchEvent.ResetReason.NONE
	_pending_reset_side = MatchBoundaryResult.Side.NONE
	_settlement_remaining_seconds = 0.0
	_is_carried_settlement = false
	_out_of_play_velocity_mps = Vector2.ZERO
	_goal_motion_elapsed_seconds = 0.0
	_pending_sideline_position_m = Vector2.INF
	_pending_sideline_team_id = ""
	if reason == MatchEvent.ResetReason.RESTART_TEST:
		_rng.seed = _state.random_seed
		_state._restart_test()
		_lifecycle_events.clear()
		_event_history.clear()
	if is_formal():
		_state._next_round()
		if is_sideline:
			_prepare_sideline_restart(restart_team, restart_player, ball_reset_position_m, side)
			events.append(_create_event(MatchEvent.Type.BALL_POSSESSION_GAINED, restart_player,
				reason, side, ball_reset_position_m))
		elif not _kickoff_players.is_empty():
			var next_team := _state.away_team_id if _state.kickoff_team_id == _state.home_team_id else _state.home_team_id
			if reason == MatchEvent.ResetReason.GOAL:
				var goal_x := -1.0 if side == MatchBoundaryResult.Side.LEFT else 1.0
				for team in _kickoff_players:
					if signf(_attacking_goals_by_team[team].x) == -goal_x:
						next_team = team
			_prepare_kickoff(next_team)
	events.append(_create_event(
		MatchEvent.Type.RESET_COMPLETED,
		"",
		reason,
		side,
		ball_reset_position_m,
	))
	_transition_round(MatchState.RoundPhase.PLAYING, events)


## Places only the nominated taker inside the line, using the existing atomic ownership path.
func _prepare_sideline_restart(team: String, player_id: String, point: Vector2, side: int) -> void:
	var player := _player_runtime_system.get_player(player_id)
	assert(player != null and not player.is_goalkeeper, "A validated formal roster needs a sideline taker")
	var inward := Vector2.DOWN if side == MatchBoundaryResult.Side.TOP else Vector2.UP
	player.state._set_position(point + inward * BallRuntimeSystem.DEFAULT_DRIBBLE_OFFSET_M)
	player.state._set_facing_direction(-inward)
	var contact := BallContactCandidate.new()
	contact.player_id = player_id
	var result := _ball_runtime_system.acquire_contact_ball(contact, _player_runtime_system)
	assert(result.new_owner_player_id == player_id, "Sideline restart must assign its sole nominated owner")
	_state._set_kickoff(team, player_id, true)


## Allows an early windup against a nearby carrier; actual contact keeps its smaller radius.
func _try_start_tackle(action: MatchAction) -> bool:
	if _match_config == null or action.target_player_id.is_empty():
		return false
	var tackler := _player_runtime_system.get_player(action.player_id)
	var carrier := _player_runtime_system.get_player(action.target_player_id)
	if not _is_legal_tackle_contact(tackler, carrier, _match_config.tackle_start_range_m):
		return false
	if carrier.technique_attribute < 1:
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
		if tackler.state.action_phase != PlayerMatchState.ActionPhase.ACTIVE:
			_pending_tackle_targets.erase(tackler.player_id)
			continue
		var carrier_id := _pending_tackle_targets[tackler.player_id]
		var carrier := _player_runtime_system.get_player(carrier_id)
		if not _is_legal_tackle_contact(tackler, carrier):
			continue
		_pending_tackle_targets.erase(tackler.player_id)
		var contest := TackleContestResolver.resolve(tackler.tackling_attribute,
			carrier.technique_attribute, _match_config, _tackle_sampler)
		if not contest.succeeded:
			# A failed contact keeps possession; the existing jump drives animation and ball height.
			carrier.state_machine.try_start_jump(_match_config)
			_append_tackle_contest_event(events, tackler.player_id, carrier.player_id, contest)
			continue
		if not _ball_runtime_system.transfer_tackled_ball(carrier, tackler):
			continue
		# Ball ownership changes at contact; the tackle keeps lunging until its configured end.
		carrier.state_machine.start_hit_stun(_match_config.tackle_hit_stun_seconds)
		_append_tackle_contest_event(events, tackler.player_id, carrier.player_id, contest)
		events.append(_create_event(
			MatchEvent.Type.BALL_POSSESSION_GAINED, tackler.player_id
		))


## Records both probability outcomes with immutable samples and before/after ownership.
func _append_tackle_contest_event(events: Array[MatchEvent], tackler_id: String,
		carrier_id: String, contest: TackleContestResult) -> void:
	events.append(MatchEvent.new(MatchEvent.Type.TACKLE_SUCCEEDED if contest.succeeded
		else MatchEvent.Type.TACKLE_FAILED, _state.elapsed_seconds, _state.simulation_step,
		tackler_id, MatchEvent.ResetReason.NONE, MatchBoundaryResult.Side.NONE,
		_ball_runtime_system.state.position_m, "", 0, false, null,
		carrier_id, carrier_id, tackler_id if contest.succeeded else carrier_id,
		null, null, null, contest))


## Applies geometry and ownership rules without sampling player attributes.
func _is_legal_tackle_contact(tackler: PlayerRuntime, carrier: PlayerRuntime,
		start_range_m: float = -1.0) -> bool:
	if tackler == null or carrier == null or tackler.player_id == carrier.player_id:
		return false
	if tackler.team_id == carrier.team_id:
		return false
	if _ball_runtime_system.state == null:
		return false
	if _ball_runtime_system.state.owner_player_id != carrier.player_id:
		return false
	if (
		carrier.state.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE
		and carrier.state.height_m >= _match_config.ground_tackle_clearance_height_m
	):
		return false
	if tackler.state.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN:
		return false
	var toward_carrier := carrier.state.position_m - tackler.state.position_m
	var allowed_range := _match_config.tackle_range_m if start_range_m < 0.0 else start_range_m
	if toward_carrier.length() > allowed_range:
		return false
	if toward_carrier.is_zero_approx():
		return true
	return tackler.state.facing_direction.dot(toward_carrier.normalized()) >= (
		_match_config.tackle_min_facing_dot
	)


## Starts a melee lunge toward a valid opponent; contact geometry is checked later.
func _try_start_knockdown(action: MatchAction) -> bool:
	if _match_config == null or action.target_player_id.is_empty():
		return false
	var attacker := _player_runtime_system.get_player(action.player_id)
	var target := _player_runtime_system.get_player(action.target_player_id)
	if not _is_valid_knockdown_target(attacker, target):
		return false
	if attacker.strength_attribute < 1 or target.strength_attribute < 1 or target.technique_attribute < 1:
		return false
	if not attacker.state_machine.try_start_knockdown(_match_config):
		return false
	_ball_runtime_system.release_attacking_ball(attacker)
	_melee_sequence += 1
	_pending_melee_sequences[attacker.player_id] = _melee_sequence
	_pending_knockdown_targets[attacker.player_id] = target.player_id
	return true


## Checks contact throughout the configured window, emitting only one hit or miss per lunge.
func _resolve_pending_knockdowns(events: Array[MatchEvent]) -> bool:
	var was_ball_released := false
	for attacker in _player_runtime_system.get_players():
		if not _pending_knockdown_targets.has(attacker.player_id):
			continue
		var is_attacking := attacker.state.action_state == PlayerMatchState.ActionState.ATTACKING
		var is_just_landed := (
			attacker.state.action_state == PlayerMatchState.ActionState.LANDING
			and attacker.state.action_state_elapsed_seconds <= KNOCKDOWN_WINDOW_EPSILON
		)
		if not is_attacking and not is_just_landed:
			_pending_knockdown_targets.erase(attacker.player_id)
			_pending_melee_sequences.erase(attacker.player_id)
			continue
		var elapsed_seconds := attacker.state.action_state_elapsed_seconds
		if is_just_landed:
			elapsed_seconds = _match_config.knockdown_action_duration_seconds
		if elapsed_seconds + KNOCKDOWN_WINDOW_EPSILON < (
			_match_config.knockdown_hit_window_start_seconds
		):
			continue
		var target_id := _pending_knockdown_targets[attacker.player_id]
		if elapsed_seconds <= _match_config.knockdown_hit_window_end_seconds + (
			KNOCKDOWN_WINDOW_EPSILON
		):
			var target := _player_runtime_system.get_player(target_id)
			if _is_legal_knockdown_contact(attacker, target):
				var direction := target.state.position_m - attacker.state.position_m
				if direction.is_zero_approx():
					direction = attacker.state_machine.knockdown_direction
				var forced := _forced_melee_result()
				var result := MeleeContestResolver.resolve(_pending_melee_sequences[attacker.player_id],
					attacker.player_id, target.player_id, attacker.strength_attribute,
					target.strength_attribute, target.technique_attribute, target.state.position_m,
					direction.normalized(), _match_config, _melee_dodge_sampler, _melee_strength_sampler, forced)
				_pending_knockdown_targets.erase(attacker.player_id)
				_pending_melee_sequences.erase(attacker.player_id)
				was_ball_released = _commit_melee_result(result, attacker, target, events) or was_ball_released
				continue
		if elapsed_seconds + KNOCKDOWN_WINDOW_EPSILON >= (
			_match_config.knockdown_hit_window_end_seconds
		):
			_pending_knockdown_targets.erase(attacker.player_id)
			_pending_melee_sequences.erase(attacker.player_id)
			_append_knockdown_miss(events, attacker.player_id, target_id)
	return was_ball_released


## Keeps old outcomes available only when callers explicitly select a development override.
func _forced_melee_result() -> int:
	match _melee_outcome:
		MeleeOutcome.TARGET_KNOCKED_DOWN: return MeleeContestResult.Outcome.ATTACKER_WIN
		MeleeOutcome.ATTACKER_RECOILS: return MeleeContestResult.Outcome.TARGET_WIN
		MeleeOutcome.BOTH_KNOCKED_DOWN: return MeleeContestResult.Outcome.DRAW
		MeleeOutcome.DODGED: return MeleeContestResult.Outcome.DODGED
	return -1

## Commits both prevalidated actors without rechecking eligibility after mutating the first actor.
func _commit_melee_result(result: MeleeContestResult, attacker: PlayerRuntime,
		target: PlayerRuntime, events: Array[MatchEvent]) -> bool:
	var target_falls := result.outcome in [MeleeContestResult.Outcome.ATTACKER_WIN, MeleeContestResult.Outcome.DRAW]
	var attacker_falls := result.outcome in [MeleeContestResult.Outcome.TARGET_WIN, MeleeContestResult.Outcome.DRAW]
	var previous_owner := _ball_runtime_system.state.owner_player_id
	if result.outcome == MeleeContestResult.Outcome.DODGED:
		# Reuse tackle-avoidance flips, also authorizing unowned targets without bypassing action locks.
		target.state_machine.try_start_jump(_match_config, true)
	# Drop at the captured contact point before either state machine can advance displacement.
	var released := target_falls and _ball_runtime_system.release_knocked_down_ball(target)
	if target_falls:
		_commit_melee_knockback(target, result.direction)
	if attacker_falls:
		_commit_melee_knockback(attacker, -result.direction)
	_append_melee_event(MatchEvent.Type.MELEE_CONTEST_RESOLVED, result, previous_owner, events)
	if target_falls:
		_append_melee_event(MatchEvent.Type.PLAYER_KNOCKED_DOWN, result, previous_owner, events)
	if attacker_falls:
		_append_melee_event(MatchEvent.Type.ATTACK_RECOILED, result, previous_owner, events)
	return released

## Cancels unfinished actor intents and applies one existing knockdown/knockback response.
func _commit_melee_knockback(player: PlayerRuntime, direction: Vector2) -> void:
	_pending_knockdown_targets.erase(player.player_id)
	_pending_melee_sequences.erase(player.player_id)
	_pending_tackle_targets.erase(player.player_id)
	_pending_header_actions.erase(player.player_id)
	_keeper_intents.erase(player.player_id)
	var started := player.state_machine.start_knockdown(_match_config)
	assert(started, "Both melee actors were validated before atomic commit")
	var pushed := player.state_machine.start_knockback(direction)
	assert(pushed, "A normalized melee direction must produce a single knockback")

## Publishes copied contest and ownership facts; response events never re-run the contest.
func _append_melee_event(kind: int, result: MeleeContestResult, previous_owner: String,
		events: Array[MatchEvent]) -> void:
	events.append(MatchEvent.new(kind, _state.elapsed_seconds, _state.simulation_step,
		result.attacker_id, MatchEvent.ResetReason.NONE, MatchBoundaryResult.Side.NONE,
		_ball_runtime_system.state.position_m, "", 0, false, null, result.target_id,
		previous_owner, _ball_runtime_system.state.owner_player_id, null, null, null, null, result))


## Emits one missed-contact fact after a lunge's hit window expires.
func _append_knockdown_miss(
	events: Array[MatchEvent], attacker_id: String, target_id: String,
) -> void:
	events.append(MatchEvent.new(
		MatchEvent.Type.KNOCKDOWN_MISSED,
		_state.elapsed_seconds,
		_state.simulation_step,
		attacker_id,
		MatchEvent.ResetReason.NONE,
		MatchBoundaryResult.Side.NONE,
		_ball_runtime_system.state.position_m,
		"", 0, false, null, target_id,
	))


## Rejects only invalid actors at command time so a lunge can start outside contact range.
func _is_valid_knockdown_target(attacker: PlayerRuntime, target: PlayerRuntime) -> bool:
	if attacker == null or target == null or attacker.player_id == target.player_id:
		return false
	if attacker.team_id == target.team_id or _ball_runtime_system.state == null:
		return false
	if attacker.state.action_state in [
		PlayerMatchState.ActionState.KNOCKED_DOWN,
		PlayerMatchState.ActionState.GETTING_UP,
	]:
		return false
	return target.state.action_state not in [
		PlayerMatchState.ActionState.KNOCKED_DOWN,
		PlayerMatchState.ActionState.GETTING_UP,
	]


## Checks metre-space distance and facing at each eligible fixed step.
func _is_legal_knockdown_contact(attacker: PlayerRuntime, target: PlayerRuntime) -> bool:
	if not _is_valid_knockdown_target(attacker, target):
		return false
	var toward_target := target.state.position_m - attacker.state.position_m
	if toward_target.length() > _match_config.knockdown_range_m:
		return false
	if toward_target.is_zero_approx():
		return true
	return attacker.state.facing_direction.dot(toward_target.normalized()) >= (
		_match_config.knockdown_min_facing_dot
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


## Allows only the carrier or the target of an incoming high pass to jump.
func _try_start_jump(action: MatchAction) -> bool:
	if _match_config == null or _ball_runtime_system.state == null:
		return false
	var player := _player_runtime_system.get_player(action.player_id)
	if player == null:
		return false
	var ball := _ball_runtime_system.state
	var is_carrier := ball.owner_player_id == action.player_id
	var is_incoming_high_pass := (
		ball.motion_state == BallMatchState.MotionState.IN_FLIGHT
		and ball.flight_kind == BallMatchState.FlightKind.PASS
		and ball.target_player_id == action.player_id
		and ball.calculate_height_at_distance(ball.flight_range_m * 0.5)
			> BallRuntimeSystem.MAX_RECEIVE_HEIGHT_M
	)
	if not is_carrier and not is_incoming_high_pass:
		return false
	return player.state_machine.try_start_jump(_match_config, is_incoming_high_pass)


## Holds a requested head action while the current high pass approaches the player.
func _try_prepare_header(action: MatchAction) -> bool:
	var ball := _ball_runtime_system.state
	var player := _player_runtime_system.get_player(action.player_id)
	if _match_config == null or ball == null or player == null:
		return false
	if ball.motion_state != BallMatchState.MotionState.IN_FLIGHT or (
		ball.flight_kind != BallMatchState.FlightKind.PASS
	):
		return false
	if action.action_type == MatchAction.Type.HEADER_SHOT and (
		not _attacking_goals_by_team.has(player.team_id)
	):
		return false
	if action.action_type == MatchAction.Type.HEADER_CLEAR and (
		 not action.direction.is_finite() or action.direction.is_zero_approx()
	):
		return false
	_pending_header_actions[action.player_id] = action
	return true


## Sweeps the current pass against every eligible player path in the fixed step.
func _find_header_contact(
	fixed_delta_seconds: float,
	start_positions: Dictionary[String, Vector2],
	start_heights: Dictionary[String, float],
) -> HeaderContactCandidate:
	var ball := _ball_runtime_system.state
	if _match_config == null or ball == null or (
		ball.motion_state != BallMatchState.MotionState.IN_FLIGHT
	) or ball.flight_kind != BallMatchState.FlightKind.PASS:
		return null
	var travel_distance_m := minf(ball.velocity_mps.length() * fixed_delta_seconds,
		ball.flight_range_m - ball.flight_distance_m)
	if travel_distance_m <= 0.0:
		return null
	var end_position_m := ball.position_m + ball.velocity_mps.normalized() * travel_distance_m
	var trajectories: Array[HeaderPlayerTrajectory] = []
	for player in _player_runtime_system.get_players():
		var is_eligible := (
			player.state.action_state == PlayerMatchState.ActionState.IDLE
			and player.state.possession_state == PlayerMatchState.PossessionState.NO_BALL
		)
		trajectories.append(HeaderPlayerTrajectory.new(
			player.player_id, player.team_id,
			start_positions[player.player_id], player.state.position_m,
			start_heights[player.player_id], player.state.height_m,
			player.strength_attribute, player.technique_attribute, is_eligible,
		))
	var candidates := HeaderContactResolver.find_candidates(ball, end_position_m,
		trajectories, _match_config.header_contact_radius_m,
		_match_config.header_min_contact_height_m, _match_config.header_reach_height_m)
	if candidates.is_empty():
		return null
	var winner := candidates[0]
	for index in range(1, candidates.size()):
		var contender := candidates[index]
		if contender.team_id == winner.team_id:
			continue
		if (contender.contact_fraction - candidates[0].contact_fraction) * (
			travel_distance_m / ball.velocity_mps.length()
		) > _match_config.header_simultaneous_window_seconds:
			break
		var winner_score := _header_score(winner)
		var contender_score := _header_score(contender)
		if contender_score > winner_score or (
			is_equal_approx(contender_score, winner_score)
			and contender.player_id < winner.player_id
		):
			winner = contender
	if _match_rules != null:
		var before_contact := _match_rules.resolve_ball_boundary(
			ball.position_m, winner.contact_position_m)
		if before_contact != null:
			return null
	return winner


## Weighs explicit player attributes only for opponents arriving almost together.
func _header_score(candidate: HeaderContactCandidate) -> float:
	return (candidate.strength * _match_config.header_strength_weight
		+ candidate.technique * _match_config.header_technique_weight)


## Uses the opponent goal for shots and the supplied vector for clearances.
func _header_direction(candidate: HeaderContactCandidate, action: MatchAction) -> Vector2:
	if action.action_type == MatchAction.Type.HEADER_CLEAR:
		return action.direction.normalized()
	if not _attacking_goals_by_team.has(candidate.team_id):
		return Vector2.ZERO
	var goal_center: Vector2 = _attacking_goals_by_team[candidate.team_id]
	return (goal_center - candidate.contact_position_m).normalized()


## Copies committed facts, including the locked aim for foot and headed shot releases.
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
	var event := MatchEvent.new(
		event_type,
		_boundary_event_time if _boundary_event_time >= 0.0 else _state.elapsed_seconds,
		_state.simulation_step,
		subject_id,
		reason,
		side,
		ball_position_m,
		last_kicker_id,
		goal_count,
		is_corner,
		net_contact, "", "", "", null,
		_ball_runtime_system.current_shot_aim if (event_type == MatchEvent.Type.BALL_SHOT
			or (event_type == MatchEvent.Type.BALL_HEADED
				and _ball_runtime_system.state.flight_kind == BallMatchState.FlightKind.SHOT)) else null,
	)

	event._capture_context(_state)
	return event


## Samples F11 only at legal release, then independently selects the applicable target branch.
func _select_shot_aim(player: PlayerRuntime, origin: Vector2) -> ShotAim:
	var probability := ShotAccuracyResolver.calculate_miss_probability(player.shooting_attribute, _match_config)
	var sample := -1.0
	var missed := _shot_miss_override == 1
	if _shot_miss_override < 0:
		sample = float(_shot_miss_sampler.call()) if _shot_miss_sampler.is_valid() else _sample_accuracy_unit()
		assert(sample >= 0.0 and sample < 1.0)
		missed = sample < probability
	var lane := ShotAim.Lane.CENTER
	var side := 0
	var margin := 0.0
	if missed:
		side = int(_shot_miss_side_sampler.call()) if _shot_miss_side_sampler.is_valid() else (-1 if _sample_accuracy_unit() < 0.5 else 1)
		margin = (float(_shot_miss_margin_sampler.call()) if _shot_miss_margin_sampler.is_valid()
			else lerpf(_match_config.shot_miss_margin_min_m, _match_config.shot_miss_margin_max_m, _sample_accuracy_unit()))
	else:
		lane = int(_shot_aim_sampler.call()) if _shot_aim_sampler.is_valid() else _rng.randi_range(0, 2)
	var goal: Vector2 = _attacking_goals_by_team[player.team_id]
	var width := _field_definition.goal_width_m if _field_definition != null else _match_config.shot_aim_goal_width_m
	var aim := ShotAccuracyResolver.create_aim(player.shooting_attribute, _match_config,
		goal, width, missed, sample, lane, side, margin)
	assert(not aim.point_m.is_equal_approx(origin))
	return aim


## Validates the keeper command before recording its fixed-time save window.
func _try_start_save(action: MatchAction, fixed_seconds: float) -> bool:
	var keeper := _player_runtime_system.get_player(action.player_id)
	if keeper == null or not keeper.is_goalkeeper or not action.direction.is_finite():
		return false
	var lane := ShotAim.Lane.CENTER
	if action.direction.y < 0.0:
		lane = ShotAim.Lane.UPPER
	elif action.direction.y > 0.0:
		lane = ShotAim.Lane.LOWER
	if not keeper.state_machine.try_start_save(_match_config, lane, action.direction):
		return false
	_keeper_intents[keeper.player_id] = _state.elapsed_seconds - fixed_seconds
	return true


## Samples F04 once and commits either hand possession or an unchanged miss trajectory.
func _commit_keeper_save(contact: BallContactCandidate, source: BallShotSource,
		events: Array[MatchEvent], contact_time: float, context: ShotFlightContext,
		incoming_direction: Vector2) -> void:
	var keeper := _player_runtime_system.get_player(contact.player_id)
	_keeper_resolved[keeper.player_id] = true
	if keeper.team_id != source.team_id:
		_ball_runtime_system.record_defensive_touch(keeper.player_id)
	var result := GoalkeeperSaveResolver.resolve(keeper.player_id, source, keeper.state.save_lane,
		contact.position_m, contact.height_m, keeper.goalkeeping_attribute, context, _match_config, _keeper_sampler,
		contact.player_position_m, incoming_direction)
	events.append(MatchEvent.new(MatchEvent.Type.GOALKEEPER_CONTACT, contact_time,
		_state.simulation_step, source.player_id, MatchEvent.ResetReason.NONE,
		MatchBoundaryResult.Side.NONE, contact.position_m, source.player_id, 0, false, null,
		keeper.player_id, "", "", null, null, result))
	if result.did_catch:
		_ball_runtime_system.catch_by_keeper(keeper)
	elif keeper.state.save_lane == ShotAim.Lane.CENTER:
		if keeper.state_machine.start_knockdown(_match_config):
			keeper.state_machine.start_knockback(_ball_runtime_system.state.velocity_mps,
				_match_config.ball_impact_knockback_distance_m,
				_match_config.ball_impact_knockback_duration_seconds,
				_match_config.ball_impact_knockback_apex_height_m)
	events.append(MatchEvent.new(MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED, contact_time,
		_state.simulation_step, keeper.player_id, MatchEvent.ResetReason.NONE,
		MatchBoundaryResult.Side.NONE, contact.position_m, source.player_id, 0, false, null,
		keeper.player_id, "", keeper.player_id if result.did_catch else "", null, null, result))
	if result.did_catch:
		events.append(MatchEvent.new(MatchEvent.Type.BALL_POSSESSION_GAINED, contact_time,
			_state.simulation_step, keeper.player_id, MatchEvent.ResetReason.NONE,
			MatchBoundaryResult.Side.NONE, contact.position_m, source.player_id, 0, false,
			null, keeper.player_id, "", keeper.player_id))
	elif keeper.state.save_lane == ShotAim.Lane.CENTER:
		events.append(MatchEvent.new(MatchEvent.Type.PLAYER_KNOCKED_DOWN, contact_time,
			_state.simulation_step, keeper.player_id))


## Restores a keeper's field-facing direction after registration or round reset.
func _orient_goalkeeper(player: PlayerRuntime) -> void:
	if not player.is_goalkeeper or not _attacking_goals_by_team.has(player.team_id):
		return
	var goal: Vector2 = _attacking_goals_by_team[player.team_id]
	var horizontal := goal.x - player.state.position_m.x
	if not is_zero_approx(horizontal):
		player.state._set_facing_direction(Vector2.LEFT if horizontal < 0.0 else Vector2.RIGHT)


## Maps one seeded integer draw to [0, 1), excluding the upper endpoint even at maximum RNG output.
func _sample_accuracy_unit() -> float:
	return float(_rng.randi()) / 4294967296.0
