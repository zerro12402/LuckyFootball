## Advances ball ownership, shots, and deterministic post-goal net motion.
class_name BallRuntimeSystem
extends RefCounted

const DEFAULT_POSSESSION_RADIUS_M := 0.75
const DEFAULT_DRIBBLE_OFFSET_M := 0.55
const DEFAULT_PASS_SPEED_MPS := 14.0
const DEFAULT_MAX_PASS_DISTANCE_M := 20.0
const DEFAULT_LOFTED_PASS_MIN_DISTANCE_M := 8.0
const DEFAULT_LOFTED_PASS_APEX_HEIGHT_M := 1.8
const MAX_RECEIVE_HEIGHT_M := 0.2
const MIN_PASS_DISTANCE_M := 1.0
const DISTANCE_EPSILON := 0.000001
const NET_CONTACT_TIME_EPSILON := 0.0000001

var state: BallMatchState:
	get:
		return _state

var last_kicker_id: String:
	get:
		return _last_kicker_id

var _state: BallMatchState
var _last_kicker_id: String = ""
var _possession_radius_m: float
var _dribble_offset_m: float
var _pass_speed_mps: float
var _max_pass_distance_m: float
var _lofted_pass_min_distance_m: float
var _lofted_pass_apex_height_m: float
var _shot_config: MatchConfigDefinition
var _ball_control_max_speed_mps: float = INF
var _pending_pass_target_id: String = ""
var _pending_pass_elapsed_seconds: float = 0.0
var _pending_shot_player_id: String = ""
var _pending_shot_direction: Vector2 = Vector2.ZERO
var _pending_shot_power: float = 0.0
var _pending_shot_elapsed_seconds: float = 0.0
var _last_shooter_id: String = ""
var _reacquire_delay_remaining_seconds: float = 0.0


## Validates the existing pass parameters before the ball is registered.
func _init(
	possession_radius_m: float = DEFAULT_POSSESSION_RADIUS_M,
	dribble_offset_m: float = DEFAULT_DRIBBLE_OFFSET_M,
	pass_speed_mps: float = DEFAULT_PASS_SPEED_MPS,
	max_pass_distance_m: float = DEFAULT_MAX_PASS_DISTANCE_M,
	lofted_pass_min_distance_m: float = DEFAULT_LOFTED_PASS_MIN_DISTANCE_M,
	lofted_pass_apex_height_m: float = DEFAULT_LOFTED_PASS_APEX_HEIGHT_M,
) -> void:
	assert(possession_radius_m > 0.0, "Possession radius must be positive")
	assert(dribble_offset_m > 0.0, "Dribble offset must be positive")
	assert(pass_speed_mps > 0.0, "Pass speed must be positive")
	assert(max_pass_distance_m > MIN_PASS_DISTANCE_M, "Pass range must be valid")
	assert(lofted_pass_min_distance_m > MIN_PASS_DISTANCE_M, "Loft threshold must be valid")
	assert(lofted_pass_min_distance_m < max_pass_distance_m, "Loft threshold must fit range")
	assert(lofted_pass_apex_height_m > 0.0, "Loft apex height must be positive")
	_possession_radius_m = possession_radius_m
	_dribble_offset_m = dribble_offset_m
	_pass_speed_mps = pass_speed_mps
	_max_pass_distance_m = max_pass_distance_m
	_lofted_pass_min_distance_m = lofted_pass_min_distance_m
	_lofted_pass_apex_height_m = lofted_pass_apex_height_m


## Applies validated shot and possession rules from the selected match preset.
func configure_match_rules(config: MatchConfigDefinition) -> void:
	assert(config != null, "Ball rules require a match configuration")
	_shot_config = config
	_ball_control_max_speed_mps = config.ball_control_max_speed_mps


## Installs the one ball permitted by the current demo match.
func register_ball(initial_position_m: Vector2) -> bool:
	if _state != null:
		return false
	_state = BallMatchState.new(initial_position_m)
	return true


## Accepts a pass only from the owner to an eligible teammate in range.
func try_start_pass(passer: PlayerRuntime, receiver: PlayerRuntime) -> bool:
	if _state == null or passer == null or receiver == null:
		return false
	if _state.motion_state != BallMatchState.MotionState.OWNED:
		return false
	if _state.owner_player_id != passer.player_id or not _pending_pass_target_id.is_empty():
		return false
	if not _pending_shot_player_id.is_empty():
		return false
	if passer.player_id == receiver.player_id or passer.team_id != receiver.team_id:
		return false
	if not _can_gain_ball(receiver):
		return false
	var pass_distance_m := _state.position_m.distance_to(receiver.state.position_m)
	if pass_distance_m < MIN_PASS_DISTANCE_M or pass_distance_m > _max_pass_distance_m:
		return false
	if not passer.state_machine.try_start_action(PlayerMatchState.ActionState.PASSING):
		return false
	_pending_pass_target_id = receiver.player_id
	_pending_pass_elapsed_seconds = 0.0
	return true


## Captures normalized direction and clamped power until the shot's kick frame.
func try_start_shot(shooter: PlayerRuntime, direction: Vector2, power: float) -> bool:
	if _shot_config == null or _state == null or shooter == null:
		return false
	if _state.motion_state != BallMatchState.MotionState.OWNED:
		return false
	if _state.owner_player_id != shooter.player_id:
		return false
	if not _pending_pass_target_id.is_empty() or not _pending_shot_player_id.is_empty():
		return false
	if shooter.shooting_attribute < 1 or not direction.is_finite() or direction.is_zero_approx():
		return false
	if not is_finite(power):
		return false
	var clamped_power := clampf(power, 0.0, 1.0)
	if not shooter.state_machine.try_start_shot(_shot_config, direction):
		return false
	_pending_shot_player_id = shooter.player_id
	_pending_shot_direction = direction.normalized()
	_pending_shot_power = clamped_power
	_pending_shot_elapsed_seconds = 0.0
	return true


## Advances exactly one ownership or trajectory state per fixed step.
func advance(
	fixed_delta_seconds: float,
	player_runtime_system: PlayerRuntimeSystem,
	should_acquire_loose_ball: bool = true,
) -> BallAdvanceResult:
	assert(fixed_delta_seconds > 0.0, "Fixed delta must be positive")
	assert(player_runtime_system != null, "Ball system requires player runtimes")
	var result := BallAdvanceResult.new()
	if _state == null:
		return result
	_reacquire_delay_remaining_seconds = maxf(
		_reacquire_delay_remaining_seconds - fixed_delta_seconds,
		0.0,
	)
	if _state.motion_state == BallMatchState.MotionState.OWNED:
		_advance_owned(fixed_delta_seconds, player_runtime_system, result)
	if _state.motion_state == BallMatchState.MotionState.IN_FLIGHT:
		_advance_flight(fixed_delta_seconds, player_runtime_system, result)
	elif _state.motion_state == BallMatchState.MotionState.LOOSE and should_acquire_loose_ball:
		_try_acquire_loose_ball(player_runtime_system, result)
	return result


## Defers free-ball acquisition until boundary rules have had the first chance to settle.
func acquire_loose_ball(players: PlayerRuntimeSystem) -> BallAdvanceResult:
	var result := BallAdvanceResult.new()
	if _state != null and _state.motion_state == BallMatchState.MotionState.LOOSE:
		_try_acquire_loose_ball(players, result)
	return result


## Transfers an owned ball after the simulation has accepted a legal tackle.
func transfer_tackled_ball(carrier: PlayerRuntime, tackler: PlayerRuntime) -> bool:
	if _state == null or carrier == null or tackler == null:
		return false
	if tackler.state.action_state != PlayerMatchState.ActionState.TACKLING:
		return false
	if tackler.state.action_phase != PlayerMatchState.ActionPhase.ACTIVE:
		return false
	if _state.motion_state != BallMatchState.MotionState.OWNED:
		return false
	if _state.owner_player_id != carrier.player_id:
		return false
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.NO_BALL)
	if carrier.state.action_state == PlayerMatchState.ActionState.PASSING:
		carrier.state_machine.finish_action()
	if carrier.state.action_state == PlayerMatchState.ActionState.SHOOTING:
		carrier.state_machine.finish_action()
	_pending_pass_target_id = ""
	_pending_pass_elapsed_seconds = 0.0
	_clear_pending_shot()
	_state._set_owner(tackler.player_id)
	tackler.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	_set_ball_at_control_point(tackler)
	return true


## Releases a knocked-down carrier's ball at contact without awarding it to the attacker.
func release_knocked_down_ball(carrier: PlayerRuntime) -> bool:
	if _state == null or carrier == null or _state.owner_player_id != carrier.player_id:
		return false
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.NO_BALL)
	_pending_pass_target_id = ""
	_pending_pass_elapsed_seconds = 0.0
	_clear_pending_shot()
	_state._release(carrier.state.position_m)
	return true


## Drops a carrier's ball at its control point when a melee attack begins.
func release_attacking_ball(attacker: PlayerRuntime) -> bool:
	if _state == null or attacker == null or _state.owner_player_id != attacker.player_id:
		return false
	attacker.state_machine.set_possession_state(PlayerMatchState.PossessionState.NO_BALL)
	_pending_pass_target_id = ""
	_pending_pass_elapsed_seconds = 0.0
	_clear_pending_shot()
	_state._release(_state.position_m)
	return true


## Clears possession, trajectories, windups, and reacquisition protection atomically.
func reset_ball(reset_position_m: Vector2) -> void:
	assert(_state != null, "Cannot reset an unregistered ball")
	assert(reset_position_m.is_finite(), "Reset position must be finite")
	_state._release(reset_position_m)
	_pending_pass_target_id = ""
	_pending_pass_elapsed_seconds = 0.0
	_clear_pending_shot()
	_last_shooter_id = ""
	_last_kicker_id = ""
	_reacquire_delay_remaining_seconds = 0.0



## Freezes a carried exit at its last position or detaches a received ball.
func prepare_for_settlement(
	players: PlayerRuntimeSystem,
	is_carried_boundary: bool,
	boundary_position_m: Vector2,
) -> void:
	assert(_state != null, "Settlement requires a registered ball")
	assert(boundary_position_m.is_finite(), "Boundary position must be finite")
	if _state.motion_state == BallMatchState.MotionState.OWNED:
		var owner := players.get_player(_state.owner_player_id)
		if owner != null:
			owner.state_machine.set_possession_state(PlayerMatchState.PossessionState.NO_BALL)
	if is_carried_boundary:
		_state._release(boundary_position_m)
	elif _state.motion_state == BallMatchState.MotionState.OWNED:
		_state._release(_state.position_m)
	_pending_pass_target_id = ""
	_pending_pass_elapsed_seconds = 0.0
	_clear_pending_shot()


## Continues out-of-play travel at the captured exit velocity without new contests.
func advance_out_of_play(
	fixed_delta_seconds: float,
	continuation_velocity_mps: Vector2,
) -> void:
	assert(fixed_delta_seconds > 0.0, "Out-of-play delta must be positive")
	assert(continuation_velocity_mps.is_finite(), "Out-of-play velocity must be finite")
	if _state == null or continuation_velocity_mps.is_zero_approx():
		return
	var displacement_m := continuation_velocity_mps * fixed_delta_seconds
	var next_position_m := _state.position_m + displacement_m
	if _state.motion_state == BallMatchState.MotionState.IN_FLIGHT:
		if _state.flight_kind == BallMatchState.FlightKind.SHOT:
			_state._advance_shot(
				next_position_m,
				continuation_velocity_mps,
				displacement_m.length(),
			)
		else:
			_state._advance_flight(next_position_m, displacement_m.length())
	else:
		_state._set_position(next_position_m)


## Starts post-goal travel at the whole-ball crossing, independent of the shot arc.
func begin_post_goal_motion(crossing_position_m: Vector2, velocity_mps: Vector2) -> void:
	assert(_state != null and crossing_position_m.is_finite() and velocity_mps.is_finite())
	_state._set_post_goal_motion(crossing_position_m, velocity_mps)


## Sweeps the scored ball against the back and side nets, retaining unused step time.
func advance_post_goal_motion(
	fixed_delta_seconds: float,
	field: FieldDefinition,
	config: MatchConfigDefinition,
	side: int,
) -> Array[GoalNetContact]:
	assert(fixed_delta_seconds >= 0.0 and field != null and config != null)
	var contacts: Array[GoalNetContact] = []
	var remaining_seconds := fixed_delta_seconds
	var position_m := _state.position_m
	var velocity_mps := _state.velocity_mps
	var goal_sign := -1.0 if side == MatchBoundaryResult.Side.LEFT else 1.0
	var goal_line_x := goal_sign * field.length_m * 0.5
	var back_x := goal_sign * (field.length_m * 0.5 + field.goal_depth_m - config.ball_radius_m)
	var side_y := field.goal_width_m * 0.5 - config.ball_radius_m
	for contact_index in range(4):
		if remaining_seconds <= DISTANCE_EPSILON or velocity_mps.is_zero_approx():
			break
		var next_m := position_m + velocity_mps * remaining_seconds
		var best_fraction := INF
		var best_surface := -1
		if velocity_mps.x * goal_sign > 0.0:
			var fraction := (back_x - position_m.x) / (next_m.x - position_m.x)
			if fraction >= 0.0 and fraction <= 1.0:
				var hit_y := lerpf(position_m.y, next_m.y, fraction)
				if absf(hit_y) <= field.goal_width_m * 0.5:
					best_fraction = fraction
					best_surface = GoalNetContact.Surface.BACK
		if velocity_mps.y < 0.0:
			var fraction := (-side_y - position_m.y) / (next_m.y - position_m.y)
			if fraction >= 0.0 and fraction < best_fraction - NET_CONTACT_TIME_EPSILON:
				var hit_x := lerpf(position_m.x, next_m.x, fraction)
				if (hit_x - goal_line_x) * goal_sign >= 0.0 and (hit_x - goal_line_x) * goal_sign <= field.goal_depth_m:
					best_fraction = fraction
					best_surface = GoalNetContact.Surface.TOP
		if velocity_mps.y > 0.0:
			var fraction := (side_y - position_m.y) / (next_m.y - position_m.y)
			if fraction >= 0.0 and fraction < best_fraction - NET_CONTACT_TIME_EPSILON:
				var hit_x := lerpf(position_m.x, next_m.x, fraction)
				if (hit_x - goal_line_x) * goal_sign >= 0.0 and (hit_x - goal_line_x) * goal_sign <= field.goal_depth_m:
					best_fraction = fraction
					best_surface = GoalNetContact.Surface.BOTTOM
		if best_surface < 0:
			position_m = next_m
			break
		position_m = position_m.lerp(next_m, best_fraction)
		var velocity_before := velocity_mps
		var net_position_m := position_m
		if best_surface == GoalNetContact.Surface.BACK:
			net_position_m.x = goal_sign * (field.length_m * 0.5 + field.goal_depth_m)
			velocity_mps = Vector2(
				-velocity_mps.x * config.goal_net_back_restitution,
				velocity_mps.y * config.goal_net_tangent_retention
			)
		else:
			net_position_m.y = -field.goal_width_m * 0.5 if best_surface == GoalNetContact.Surface.TOP else field.goal_width_m * 0.5
			velocity_mps = Vector2(
				velocity_mps.x * config.goal_net_tangent_retention,
				-velocity_mps.y * config.goal_net_side_restitution
			)
		contacts.append(GoalNetContact.new(best_surface, net_position_m, velocity_before, velocity_mps))
		remaining_seconds *= 1.0 - best_fraction
		if velocity_mps.length() < config.goal_net_stop_speed_mps:
			velocity_mps = Vector2.ZERO
			break
	_state._set_post_goal_motion(position_m, velocity_mps)
	return contacts


func create_snapshot() -> BallStateSnapshot:
	if _state == null:
		return null
	return BallStateSnapshot.new(_state)


## Follows the owner through windup, then releases the queued kick once.
func _advance_owned(
	fixed_delta_seconds: float,
	players: PlayerRuntimeSystem,
	result: BallAdvanceResult,
) -> void:
	var previous_position_m := _state.position_m
	_follow_owner(players)
	if _state.motion_state != BallMatchState.MotionState.OWNED:
		_pending_pass_target_id = ""
		_clear_pending_shot()
		return
	# Preserve the carried segment even if a queued kick releases the ball this step.
	result.has_owned_motion_segment = true
	result.owned_motion_start_position_m = previous_position_m
	result.owned_motion_end_position_m = _state.position_m
	if not _pending_pass_target_id.is_empty():
		_pending_pass_elapsed_seconds += fixed_delta_seconds
		if _pending_pass_elapsed_seconds >= PlayerStateMachine.PASS_WINDUP_SECONDS:
			_launch_pending_pass(players, result)
	elif not _pending_shot_player_id.is_empty():
		_pending_shot_elapsed_seconds += fixed_delta_seconds
		if _pending_shot_elapsed_seconds >= _shot_config.shot_windup_seconds:
			_launch_pending_shot(players, result)


## Launches the existing teammate pass without changing its trajectory rules.
func _launch_pending_pass(players: PlayerRuntimeSystem, result: BallAdvanceResult) -> void:
	var passer := players.get_player(_state.owner_player_id)
	var receiver := players.get_player(_pending_pass_target_id)
	_pending_pass_target_id = ""
	_pending_pass_elapsed_seconds = 0.0
	if passer == null or receiver == null:
		return
	var pass_direction := receiver.state.position_m - _state.position_m
	if pass_direction.is_zero_approx():
		pass_direction = passer.state.facing_direction
	passer.state_machine.set_possession_state(PlayerMatchState.PossessionState.NO_BALL)
	var flight_range_m := _max_pass_distance_m
	var apex_height_m := 0.0
	var pass_distance_m := pass_direction.length()
	if pass_distance_m > _lofted_pass_min_distance_m:
		flight_range_m = minf(pass_distance_m, _max_pass_distance_m)
		apex_height_m = _lofted_pass_apex_height_m
	_state._launch_pass(
		receiver.player_id,
		pass_direction.normalized() * _pass_speed_mps,
		flight_range_m,
		apex_height_m,
	)
	_last_kicker_id = passer.player_id
	result.passed_by_player_id = passer.player_id


## Computes shot speed from attributes, then applies the CSV apex independently.
func _launch_pending_shot(players: PlayerRuntimeSystem, result: BallAdvanceResult) -> void:
	var shooter := players.get_player(_pending_shot_player_id)
	var direction := _pending_shot_direction
	var power := _pending_shot_power
	_clear_pending_shot()
	if shooter == null or _state.owner_player_id != shooter.player_id:
		return
	var attribute_fraction := float(shooter.shooting_attribute - 1) / 99.0
	var attribute_multiplier := lerpf(
		_shot_config.shot_min_attribute_multiplier,
		_shot_config.shot_max_attribute_multiplier,
		attribute_fraction,
	)
	var initial_speed_mps := _shot_config.shot_base_speed_mps * power * attribute_multiplier
	var release_position_m := shooter.state.position_m + direction * _dribble_offset_m
	shooter.state_machine.set_possession_state(PlayerMatchState.PossessionState.NO_BALL)
	if initial_speed_mps > _shot_config.shot_stop_speed_mps:
		var stop_speed_mps := _shot_config.shot_stop_speed_mps
		var flight_range_m := (
			initial_speed_mps * initial_speed_mps - stop_speed_mps * stop_speed_mps
		) / (2.0 * _shot_config.shot_ground_deceleration_mps2)
		_state._launch_shot(
			release_position_m,
			direction * initial_speed_mps,
			flight_range_m,
			_shot_config.shot_apex_height_m,
		)
	else:
		_state._release(release_position_m)
	_last_shooter_id = shooter.player_id
	_last_kicker_id = shooter.player_id
	_reacquire_delay_remaining_seconds = _shot_config.shot_reacquire_delay_seconds
	result.shot_by_player_id = shooter.player_id


## Routes passes and shots to their own deterministic movement rules.
func _advance_flight(
	fixed_delta_seconds: float,
	players: PlayerRuntimeSystem,
	result: BallAdvanceResult,
) -> void:
	result.has_motion_segment = true
	result.motion_start_position_m = _state.position_m
	if _state.flight_kind == BallMatchState.FlightKind.SHOT:
		_advance_shot(fixed_delta_seconds)
		result.motion_end_position_m = _state.position_m
		return
	var remaining_distance_m := _state.flight_range_m - _state.flight_distance_m
	var travel_distance_m := minf(
		_state.velocity_mps.length() * fixed_delta_seconds,
		remaining_distance_m,
	)
	var next_position_m := _state.position_m + _state.velocity_mps.normalized() * travel_distance_m
	result.motion_end_position_m = next_position_m
	var receiver := players.get_player(_state.target_player_id)
	if _can_receive_flight(receiver, next_position_m):
		_receive_pass(receiver, result)
		return
	_state._advance_flight(next_position_m, travel_distance_m)
	if _state.flight_distance_m + DISTANCE_EPSILON >= _state.flight_range_m:
		_state._release(next_position_m)
		result.was_pass_missed = true


## Decelerates the shot horizontally while height follows its fixed-distance arc.
func _advance_shot(fixed_delta_seconds: float) -> void:
	var speed_mps := _state.velocity_mps.length()
	if speed_mps <= _shot_config.shot_stop_speed_mps:
		_state._release(_state.position_m)
		return
	var deceleration := _shot_config.shot_ground_deceleration_mps2
	var seconds_until_stop := (speed_mps - _shot_config.shot_stop_speed_mps) / deceleration
	var moving_seconds := minf(fixed_delta_seconds, seconds_until_stop)
	var travel_distance_m := (
		speed_mps * moving_seconds
		- 0.5 * deceleration * moving_seconds * moving_seconds
	)
	var direction := _state.velocity_mps / speed_mps
	var next_position_m := _state.position_m + direction * travel_distance_m
	if moving_seconds + DISTANCE_EPSILON >= seconds_until_stop:
		_state._release(next_position_m)
	else:
		var next_speed_mps := speed_mps - deceleration * fixed_delta_seconds
		_state._advance_shot(next_position_m, direction * next_speed_mps, travel_distance_m)


## Rechecks action state, ball speed, and height where the directed pass crosses its target.
func _can_receive_flight(receiver: PlayerRuntime, next_position_m: Vector2) -> bool:
	if not _can_gain_ball(receiver):
		return false
	if not _is_controllable_ball_speed(_state.velocity_mps.length()):
		return false
	var segment := next_position_m - _state.position_m
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= DISTANCE_EPSILON:
		return false
	var segment_fraction := clampf(
		(receiver.state.position_m - _state.position_m).dot(segment)
		/ segment_length_squared,
		0.0,
		1.0,
	)
	var closest_position_m := _state.position_m + segment * segment_fraction
	var closest_flight_distance_m := _state.flight_distance_m + segment.length() * segment_fraction
	if _state.calculate_height_at_distance(closest_flight_distance_m) > MAX_RECEIVE_HEIGHT_M:
		return false
	return closest_position_m.distance_squared_to(receiver.state.position_m) <= (
		_possession_radius_m * _possession_radius_m
	)


## Transfers an intercepted pass into owned-ball state at the receiver's control point.
func _receive_pass(receiver: PlayerRuntime, result: BallAdvanceResult) -> void:
	_state._set_owner(receiver.player_id)
	receiver.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	_set_ball_at_control_point(receiver)
	result.new_owner_player_id = receiver.player_id
	result.received_by_player_id = receiver.player_id


## Gives a stopped or free ball to the nearest eligible player.
func _try_acquire_loose_ball(players: PlayerRuntimeSystem, result: BallAdvanceResult) -> void:
	var new_owner := _find_possession_candidate(players)
	if new_owner == null:
		return
	_state._set_owner(new_owner.player_id)
	new_owner.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	_set_ball_at_control_point(new_owner)
	result.new_owner_player_id = new_owner.player_id


## Finds the nearest available player after excluding recently released shooters.
func _find_possession_candidate(players: PlayerRuntimeSystem) -> PlayerRuntime:
	var nearest_player: PlayerRuntime
	var nearest_distance_squared := _possession_radius_m * _possession_radius_m + DISTANCE_EPSILON
	if not _is_controllable_ball_speed(_state.velocity_mps.length()):
		return null
	for player_runtime in players.get_players():
		if not _can_gain_ball(player_runtime):
			continue
		if (
			player_runtime.player_id == _last_shooter_id
			and _reacquire_delay_remaining_seconds > 0.0
		):
			continue
		var distance_squared := player_runtime.state.position_m.distance_squared_to(
			_state.position_m
		)
		if distance_squared < nearest_distance_squared:
			nearest_player = player_runtime
			nearest_distance_squared = distance_squared
	return nearest_player


## Requires the same available action state for free-ball pickup and directed reception.
func _can_gain_ball(player: PlayerRuntime) -> bool:
	return (
		player != null
		and player.state.action_state == PlayerMatchState.ActionState.IDLE
		and player.state.possession_state == PlayerMatchState.PossessionState.NO_BALL
	)


## Includes the configured boundary speed in ordinary ball acquisition.
func _is_controllable_ball_speed(speed_mps: float) -> bool:
	return is_finite(speed_mps) and speed_mps <= _ball_control_max_speed_mps


## Follows the current owner or releases a ball whose owner disappeared.
func _follow_owner(players: PlayerRuntimeSystem) -> void:
	var owner := players.get_player(_state.owner_player_id)
	if owner == null:
		_state._release(_state.position_m)
		return
	_set_ball_at_control_point(owner)


## Holds the ball in front of the owner's current horizontal facing.
func _set_ball_at_control_point(owner: PlayerRuntime) -> void:
	_state._set_position(
		owner.state.position_m + owner.state.facing_direction * _dribble_offset_m
	)


## Clears a queued shot after it is launched or ownership is cancelled.
func _clear_pending_shot() -> void:
	_pending_shot_player_id = ""
	_pending_shot_direction = Vector2.ZERO
	_pending_shot_power = 0.0
	_pending_shot_elapsed_seconds = 0.0
