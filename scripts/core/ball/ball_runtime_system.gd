## Advances ball ownership, real-touch history, shots, and deterministic post-goal net motion.
class_name BallRuntimeSystem
extends RefCounted

const DEFAULT_POSSESSION_RADIUS_M := 0.75
const DEFAULT_DRIBBLE_OFFSET_M := 0.55
const DEFAULT_PASS_SPEED_MPS := 14.0
const DEFAULT_MAX_PASS_DISTANCE_M := 20.0
const DEFAULT_LOFTED_PASS_MIN_DISTANCE_M := 8.0
const DEFAULT_LOFTED_PASS_APEX_HEIGHT_M := 1.8
const MAX_RECEIVE_HEIGHT_M := 0.2
const AERIAL_RECEIVE_HEIGHT_TOLERANCE_M := 0.5
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
var last_touch_player_id: String:
	get: return _last_touch_player_id
var _last_touch_player_id: String = ""
var _ai_flight_sequence: int = 0
var _defensive_touched: bool = false
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
var _pending_shot_started_airborne: bool = false
var _last_releaser_id: String = ""
var _reacquire_delay_remaining_seconds: float = 0.0
var _reacquire_delay_at_step_start_seconds: float = 0.0
var shot_source: BallShotSource:
	get: return _shot_source
var _shot_source: BallShotSource
var shot_context: ShotFlightContext:
	get: return _shot_context
var _shot_context: ShotFlightContext
var _shot_sequence: int = 0
var _shot_aim_selector: Callable
var _current_shot_aim: ShotAim

var current_shot_aim: ShotAim:
	get: return _current_shot_aim


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
	if passer.state.jump_phase != PlayerMatchState.JumpPhase.NONE:
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
	_pending_shot_started_airborne = (
		shooter.state.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE
	)
	return true


## Advances ball motion and allows control immediately after a trajectory stops.
func advance(
	fixed_delta_seconds: float,
	player_runtime_system: PlayerRuntimeSystem,
	should_acquire_loose_ball: bool = true,
	header_contact: HeaderContactCandidate = null,
	header_action: MatchAction = null,
	header_direction: Vector2 = Vector2.ZERO,
	defer_shot_motion: bool = false,
	player_start_positions: Dictionary[String, Vector2] = {},
	player_start_heights: Dictionary[String, float] = {},
) -> BallAdvanceResult:
	assert(fixed_delta_seconds > 0.0, "Fixed delta must be positive")
	assert(player_runtime_system != null, "Ball system requires player runtimes")
	var result := BallAdvanceResult.new()
	if _state == null:
		return result
	_reacquire_delay_at_step_start_seconds = _reacquire_delay_remaining_seconds
	_reacquire_delay_remaining_seconds = maxf(
		_reacquire_delay_remaining_seconds - fixed_delta_seconds,
		0.0,
	)
	if _state.motion_state == BallMatchState.MotionState.OWNED:
		_advance_owned(fixed_delta_seconds, player_runtime_system, result)
	if _state.motion_state == BallMatchState.MotionState.IN_FLIGHT:
		if defer_shot_motion and _state.flight_kind == BallMatchState.FlightKind.SHOT:
			result.deferred_shot_seconds = fixed_delta_seconds
		else:
			_advance_flight(fixed_delta_seconds, player_runtime_system, result,
				header_contact, header_action, header_direction, defer_shot_motion,
				player_start_positions, player_start_heights)
	if _state.motion_state == BallMatchState.MotionState.LOOSE and should_acquire_loose_ball:
		_try_acquire_loose_ball(player_runtime_system, result)
	return result


## Advances only the interval already accepted by the simulation contact scheduler.
func advance_shot_motion(seconds: float) -> void:
	if seconds > 0.0:
		_advance_shot(seconds)


## Applies a rebound at contact height without assigning ownership or a new shooter.
func apply_impact(result: BallImpactResult) -> void:
	if result.route != BallImpactResult.Route.REBOUND:
		return
	var speed := result.velocity_after_mps.length()
	if speed <= _shot_config.shot_stop_speed_mps:
		_state._release(_state.position_m)
		_clear_shot_context()
		return
	var range_m := (speed * speed - pow(_shot_config.shot_stop_speed_mps, 2.0)) / (
		2.0 * _shot_config.shot_ground_deceleration_mps2)
	_state._launch_shot(result.position_m, result.velocity_after_mps, range_m,
		_shot_config.ball_impact_rebound_apex_height_m, result.height_m)


## Locks immutable source data only when a new legal kick actually releases the ball.
func _record_shot_source(player: PlayerRuntime) -> void:
	assert(player != null)
	_ai_flight_sequence += 1
	_defensive_touched = false
	_shot_sequence += 1
	_shot_source = BallShotSource.new(player.player_id, player.team_id,
		player.shooting_attribute, _shot_sequence)
	_shot_context = ShotFlightContext.new(_shot_source)


## Defers free-ball acquisition until boundary rules have had the first chance to settle.
func acquire_loose_ball(players: PlayerRuntimeSystem) -> BallAdvanceResult:
	var result := BallAdvanceResult.new()
	if _state != null and _state.motion_state == BallMatchState.MotionState.LOOSE:
		_try_acquire_loose_ball(players, result)
	return result


## Finds the earliest controllable contact, independently of flight kind or intended target.
func find_control_contact(
	trajectory: BallShotTrajectory,
	players: PlayerRuntimeSystem,
	starts: Dictionary[String, Vector2] = {},
	heights: Dictionary[String, float] = {},
	step_seconds: float = 0.0,
	elapsed_seconds: float = 0.0,
) -> BallContactCandidate:
	if trajectory.duration_seconds <= ContactPolynomial.EPSILON:
		return null
	var best: BallContactCandidate
	for player in players.get_players():
		if not _can_control_ball(player):
			continue
		var earliest := 0.0
		if player.player_id == _last_releaser_id:
			earliest = maxf(_reacquire_delay_at_step_start_seconds - elapsed_seconds, 0.0)
		if earliest > trajectory.duration_seconds:
			continue
		var start := player.state.position_m
		var end := start
		var start_height := player.state.height_m
		var end_height := start_height
		if step_seconds > 0.0 and starts.has(player.player_id):
			start = starts[player.player_id].lerp(end, elapsed_seconds / step_seconds)
			end = starts[player.player_id].lerp(end,
				(elapsed_seconds + trajectory.duration_seconds) / step_seconds)
			start_height = lerpf(heights[player.player_id], player.state.height_m,
				elapsed_seconds / step_seconds)
			end_height = lerpf(heights[player.player_id], player.state.height_m,
				(elapsed_seconds + trajectory.duration_seconds) / step_seconds)
		var time := _first_control_time(trajectory, player, start, end,
			start_height, end_height, earliest)
		if time < 0.0 or (best != null
			and time >= best.time_seconds - ContactPolynomial.EPSILON):
			continue # Sorted player IDs break simultaneous contacts deterministically.
		best = BallContactCandidate.new()
		best.player_id = player.player_id
		best.time_seconds = time
		best.position_m = trajectory.position_at(time)
		best.height_m = maxf(ContactPolynomial.evaluate(trajectory.height_coefficients, time), 0.0)
		best.player_position_m = start.lerp(end, time / trajectory.duration_seconds)
	return best


## Commits a scheduler-validated reception using the same atomic ownership path as pickup.
func acquire_contact_ball(contact: BallContactCandidate, players: PlayerRuntimeSystem) -> BallAdvanceResult:
	var result := BallAdvanceResult.new()
	var player := players.get_player(contact.player_id)
	if _state == null or not _state.owner_player_id.is_empty() or not _can_control_ball(player):
		return result
	var was_pass := _state.flight_kind == BallMatchState.FlightKind.PASS
	_claim_ball(player, result)
	if was_pass:
		result.received_by_player_id = player.player_id
	return result


## Intersects distance, height, speed and release-protection intervals without sampling gaps.
func _first_control_time(trajectory: BallShotTrajectory, player: PlayerRuntime,
		start: Vector2, end: Vector2, start_height: float, end_height: float,
		earliest: float) -> float:
	var duration := trajectory.duration_seconds
	var offset := trajectory.start_position_m - start
	var relative_velocity := trajectory.direction * trajectory.speed_mps - (end - start) / duration
	var acceleration := -trajectory.direction * trajectory.deceleration_mps2 * 0.5
	var x: Array[float] = [offset.x, relative_velocity.x, acceleration.x]
	var y: Array[float] = [offset.y, relative_velocity.y, acceleration.y]
	var planar := ContactPolynomial.multiply(x, x)
	var yy := ContactPolynomial.multiply(y, y)
	for index in range(planar.size()):
		planar[index] += yy[index]
	planar[0] -= _possession_radius_m * _possession_radius_m
	var upper: Array[float] = trajectory.height_coefficients.duplicate()
	var lower: Array[float] = [-1.0]
	var minimum_height: Array[float] = [-1.0]
	if player.state.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE:
		upper[0] -= start_height + AERIAL_RECEIVE_HEIGHT_TOLERANCE_M
		upper[1] -= (end_height - start_height) / duration
		lower = upper.duplicate()
		for index in range(lower.size()):
			lower[index] = -lower[index]
		lower[0] -= 2.0 * AERIAL_RECEIVE_HEIGHT_TOLERANCE_M
		minimum_height = trajectory.height_coefficients.duplicate()
		for index in range(minimum_height.size()):
			minimum_height[index] = -minimum_height[index]
		minimum_height[0] += MAX_RECEIVE_HEIGHT_M + ContactPolynomial.EPSILON
	else:
		upper[0] -= MAX_RECEIVE_HEIGHT_M + (
			_shot_config.ball_radius_m if _shot_config != null else 0.0)
	var speed: Array[float] = [-1.0]
	if is_finite(_ball_control_max_speed_mps):
		speed = [trajectory.speed_mps - _ball_control_max_speed_mps, -trajectory.deceleration_mps2]
	var constraints: Array[Array] = [planar, lower, upper, minimum_height, speed]
	var points: Array[float] = [earliest, duration]
	for polynomial in constraints:
		points.append_array(ContactPolynomial.roots(polynomial, earliest, duration))
	points.sort()
	for index in range(points.size()):
		var time := points[index]
		if _control_constraints_hold(constraints, time):
			return time
		if index + 1 < points.size() and _control_constraints_hold(
			constraints, (time + points[index + 1]) * 0.5):
			return time
	return -1.0


## Applies inclusive speed, planar and vertical bounds at a candidate physical time.
func _control_constraints_hold(constraints: Array[Array], time: float) -> bool:
	for polynomial in constraints:
		if ContactPolynomial.evaluate(polynomial, time) > ContactPolynomial.EPSILON:
			return false
	return true


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
	_last_touch_player_id = tackler.player_id
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
	_last_releaser_id = ""
	_last_kicker_id = ""
	_last_touch_player_id = ""
	_reacquire_delay_remaining_seconds = 0.0
	_reacquire_delay_at_step_start_seconds = 0.0
	_clear_shot_context()
	_shot_sequence = 0
	_current_shot_aim = null



## Freezes a carried exit at its last position or detaches a received ball.
func prepare_for_settlement(
	players: PlayerRuntimeSystem,
	is_carried_boundary: bool,
	boundary_position_m: Vector2,
) -> void:
	assert(_state != null, "Settlement requires a registered ball")
	assert(boundary_position_m.is_finite(), "Boundary position must be finite")
	_clear_shot_context()
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
		contacts.append(GoalNetContact.new(best_surface, net_position_m, velocity_before, velocity_mps,
			fixed_delta_seconds - remaining_seconds + remaining_seconds * best_fraction))
		remaining_seconds *= 1.0 - best_fraction
		if velocity_mps.length() < config.goal_net_stop_speed_mps:
			velocity_mps = Vector2.ZERO
			break
	_state._set_post_goal_motion(position_m, velocity_mps)
	return contacts


## Returns the registered ball's read-only state, or null before registration.
func create_snapshot() -> BallStateSnapshot:
	if _state == null:
		return null
	return BallStateSnapshot.new(_state, _current_shot_aim
		if _state.flight_kind == BallMatchState.FlightKind.SHOT else null,
		_shot_context.distance_m if _shot_context != null else 0.0,
		_shot_context.knockdown_count if _shot_context != null else 0,
		_last_kicker_id, _ai_flight_sequence, _defensive_touched)

## Records a real defender's touch independently of shot origin and rebound; omitted IDs preserve old isolated fixtures.
func record_defensive_touch(player_id: String = "") -> void:
	_defensive_touched = true
	if not player_id.is_empty():
		_last_touch_player_id = player_id


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
	_clear_shot_context()
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
	_protect_releaser(passer.player_id)
	_last_kicker_id = passer.player_id
	_ai_flight_sequence += 1
	_defensive_touched = false
	result.passed_by_player_id = passer.player_id


## Releases the owned ball once at its current height using configured shot speed and arc.
func _launch_pending_shot(players: PlayerRuntimeSystem, result: BallAdvanceResult) -> void:
	var shooter := players.get_player(_pending_shot_player_id)
	var direction := _pending_shot_direction
	var power := _pending_shot_power
	var started_airborne := _pending_shot_started_airborne
	_clear_pending_shot()
	if shooter == null or _state.owner_player_id != shooter.player_id:
		return
	if shooter.state.action_state != PlayerMatchState.ActionState.SHOOTING:
		return
	if started_airborne and shooter.state.jump_phase != PlayerMatchState.JumpPhase.AIRBORNE:
		shooter.state_machine.finish_action()
		return
	var release_height_m := _state.height_m
	var from_hands := _state.control_attachment == BallMatchState.ControlAttachment.KEEPER_HANDS
	var aim_origin := _state.position_m if from_hands else shooter.state.position_m
	if _shot_aim_selector.is_valid():
		_current_shot_aim = _shot_aim_selector.call(shooter, aim_origin)
		direction = (_current_shot_aim.point_m - aim_origin).normalized()
	_record_shot_source(shooter)
	var attribute_fraction := float(shooter.shooting_attribute - 1) / 99.0
	var attribute_multiplier := lerpf(
		_shot_config.shot_min_attribute_multiplier,
		_shot_config.shot_max_attribute_multiplier,
		attribute_fraction,
	)
	var initial_speed_mps := _shot_config.shot_base_speed_mps * power * attribute_multiplier
	var release_position_m := (_state.position_m if from_hands
		else shooter.state.position_m + direction * _dribble_offset_m)
	shooter.state_machine.set_possession_state(PlayerMatchState.PossessionState.NO_BALL)
	if initial_speed_mps > _shot_config.shot_stop_speed_mps:
		var stop_speed_mps := _shot_config.shot_stop_speed_mps
		var flight_range_m := (
			initial_speed_mps * initial_speed_mps - stop_speed_mps * stop_speed_mps
		) / (2.0 * _shot_config.shot_ground_deceleration_mps2)
		if _current_shot_aim != null:
			flight_range_m = minf(flight_range_m,
				release_position_m.distance_to(_current_shot_aim.point_m))
		_state._launch_shot(
			release_position_m,
			direction * initial_speed_mps,
			flight_range_m,
			_shot_config.shot_apex_height_m,
			release_height_m,
		)
	else:
		_state._release(release_position_m)
	_protect_releaser(shooter.player_id)
	_last_kicker_id = shooter.player_id
	result.shot_by_player_id = shooter.player_id


## Advances to the earliest reception or header before completing unowned ball motion.
func _advance_flight(
	fixed_delta_seconds: float,
	players: PlayerRuntimeSystem,
	result: BallAdvanceResult,
	header_contact: HeaderContactCandidate = null,
	header_action: MatchAction = null,
	header_direction: Vector2 = Vector2.ZERO,
	defer_shot_motion: bool = false,
	starts: Dictionary[String, Vector2] = {},
	heights: Dictionary[String, float] = {},
) -> void:
	result.has_motion_segment = true
	result.motion_start_position_m = _state.position_m
	var trajectory := BallShotTrajectory.new(_state, fixed_delta_seconds, _shot_config)
	var contact := find_control_contact(trajectory, players, starts, heights, fixed_delta_seconds)
	var has_header := (header_contact != null and header_action != null
		and _state.flight_kind == BallMatchState.FlightKind.PASS
		and header_contact.contact_fraction >= 0.0 and header_contact.contact_fraction <= 1.0)
	var travel_distance_m := trajectory.distance_at(trajectory.duration_seconds)
	var header_seconds := INF
	if has_header:
		header_seconds = trajectory.time_at_distance(travel_distance_m * header_contact.contact_fraction)
	if contact != null and contact.time_seconds < header_seconds - ContactPolynomial.EPSILON:
		result.motion_end_position_m = contact.position_m
		var reception := acquire_contact_ball(contact, players)
		result.new_owner_player_id = reception.new_owner_player_id
		result.received_by_player_id = reception.received_by_player_id
		return
	if has_header:
		_advance_header_contact(fixed_delta_seconds, travel_distance_m,
			header_contact, header_action, header_direction, result,
			players.get_player(header_contact.player_id), defer_shot_motion)
		return
	if _state.flight_kind == BallMatchState.FlightKind.SHOT:
		_advance_shot(fixed_delta_seconds)
		result.motion_end_position_m = _state.position_m
		return
	var next_position_m := trajectory.position_at(trajectory.duration_seconds)
	result.motion_end_position_m = next_position_m
	_state._advance_flight(next_position_m, travel_distance_m)
	if _state.flight_distance_m + DISTANCE_EPSILON >= _state.flight_range_m:
		var was_pass := _state.flight_kind == BallMatchState.FlightKind.PASS
		_state._release(next_position_m)
		result.was_pass_missed = was_pass


## Advances to the precise high contact, redirects once, then spends unused step time.
func _advance_header_contact(
	fixed_delta_seconds: float,
	travel_distance_m: float,
	contact: HeaderContactCandidate,
	action: MatchAction,
	direction: Vector2,
	result: BallAdvanceResult,
	player: PlayerRuntime,
	defer_shot_motion: bool = false,
) -> void:
	assert(_shot_config != null and not direction.is_zero_approx())
	var pass_start_m := _state.position_m
	var contact_distance_m := travel_distance_m * contact.contact_fraction
	_state._advance_flight(contact.contact_position_m, contact_distance_m)
	var contact_height_m := _state.height_m
	result.has_pre_header_segment = true
	result.pre_header_start_position_m = pass_start_m
	result.pre_header_end_position_m = contact.contact_position_m
	result.motion_start_position_m = contact.contact_position_m
	result.header_contact_position_m = contact.contact_position_m
	result.header_by_player_id = contact.player_id
	result.header_action_type = action.action_type
	_last_kicker_id = contact.player_id
	_protect_releaser(contact.player_id)
	var remaining_seconds := fixed_delta_seconds * (1.0 - contact.contact_fraction)
	if action.action_type == MatchAction.Type.HEADER_SHOT:
		if _shot_aim_selector.is_valid():
			_current_shot_aim = _shot_aim_selector.call(player, contact.contact_position_m)
			direction = (_current_shot_aim.point_m - contact.contact_position_m).normalized()
		_record_shot_source(player)
		var speed_mps := _shot_config.header_shot_speed_mps
		var stop_speed_mps := _shot_config.shot_stop_speed_mps
		var range_m := (speed_mps * speed_mps - stop_speed_mps * stop_speed_mps) / (
			2.0 * _shot_config.shot_ground_deceleration_mps2)
		if _current_shot_aim != null:
			range_m = minf(range_m, contact.contact_position_m.distance_to(_current_shot_aim.point_m))
		_state._launch_shot(contact.contact_position_m, direction.normalized() * speed_mps,
			range_m, _shot_config.header_shot_apex_height_m, contact_height_m)
		if defer_shot_motion:
			result.deferred_shot_seconds = remaining_seconds
		elif remaining_seconds > 0.0:
			_advance_shot(remaining_seconds)
	else:
		_state._launch_clearance(contact.contact_position_m,
			direction.normalized() * _shot_config.header_clear_speed_mps,
			_max_pass_distance_m, _shot_config.header_clear_apex_height_m, contact_height_m)
		if remaining_seconds > 0.0:
			var clearance_distance_m := minf(
				_state.velocity_mps.length() * remaining_seconds,
				_state.flight_range_m)
			var clearance_end_m := _state.position_m + direction.normalized() * clearance_distance_m
			_state._advance_flight(clearance_end_m, clearance_distance_m)
	result.motion_end_position_m = _state.position_m


## Decelerates the shot horizontally while height follows its fixed-distance arc.
func _advance_shot(fixed_delta_seconds: float) -> void:
	var speed_mps := _state.velocity_mps.length()
	if speed_mps <= _shot_config.shot_stop_speed_mps:
		_state._release(_state.position_m)
		_clear_shot_context()
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
	if _shot_context != null:
		_shot_context._advance_distance(travel_distance_m)
	if moving_seconds + DISTANCE_EPSILON >= seconds_until_stop:
		_state._release(next_position_m)
		_clear_shot_context()
	else:
		var next_speed_mps := speed_mps - deceleration * fixed_delta_seconds
		_state._advance_shot(next_position_m, direction * next_speed_mps, travel_distance_m)


## Clears old trajectories and protection while assigning exactly one ball owner.
func _claim_ball(receiver: PlayerRuntime, result: BallAdvanceResult) -> void:
	_last_touch_player_id = receiver.player_id
	_clear_shot_context()
	_last_releaser_id = ""
	_reacquire_delay_remaining_seconds = 0.0
	_reacquire_delay_at_step_start_seconds = 0.0
	_state._set_owner(receiver.player_id)
	receiver.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	_set_ball_at_control_point(receiver)
	result.new_owner_player_id = receiver.player_id


## Protects only the latest releasing player for the same configured interval after any kick.
func _protect_releaser(player_id: String) -> void:
	_last_touch_player_id = player_id
	_last_releaser_id = player_id
	_reacquire_delay_remaining_seconds = (
		_shot_config.shot_reacquire_delay_seconds if _shot_config != null else 0.0)
	_reacquire_delay_at_step_start_seconds = _reacquire_delay_remaining_seconds


## Gives a stopped or free ball to the nearest eligible player.
func _try_acquire_loose_ball(players: PlayerRuntimeSystem, result: BallAdvanceResult) -> void:
	var new_owner := _find_possession_candidate(players)
	if new_owner == null:
		return
	_claim_ball(new_owner, result)


## Finds the nearest available player after excluding the protected last releaser.
func _find_possession_candidate(players: PlayerRuntimeSystem) -> PlayerRuntime:
	var nearest_player: PlayerRuntime
	var nearest_distance_squared := _possession_radius_m * _possession_radius_m + DISTANCE_EPSILON
	if not _is_controllable_ball_speed(_state.velocity_mps.length()):
		return null
	for player_runtime in players.get_players():
		if not _can_gain_ball(player_runtime):
			continue
		if (
			player_runtime.player_id == _last_releaser_id
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


## Requires ground availability for static pickup and selecting a pass target.
func _can_gain_ball(player: PlayerRuntime) -> bool:
	return _can_control_ball(player) and player.state.jump_phase == PlayerMatchState.JumpPhase.NONE


## Shares action and possession eligibility across every ordinary unowned-ball reception.
func _can_control_ball(player: PlayerRuntime) -> bool:
	# A keeper facing a shot must use F04, even when ordinary pickup would be earlier.
	if player != null and player.is_goalkeeper and _state != null and (
		_state.flight_kind == BallMatchState.FlightKind.SHOT):
		return false
	return (
		player != null
		and player.state.action_state == PlayerMatchState.ActionState.IDLE
		and player.state.jump_phase in [
			PlayerMatchState.JumpPhase.NONE, PlayerMatchState.JumpPhase.AIRBORNE]
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


## Keeps a catch in the hands during SAVING, then uses the ordinary dribble attachment.
func _set_ball_at_control_point(owner: PlayerRuntime) -> void:
	if (_state.control_attachment == BallMatchState.ControlAttachment.KEEPER_HANDS
		and owner.state.action_state != PlayerMatchState.ActionState.SAVING):
		_state._set_attachment(BallMatchState.ControlAttachment.FOOT)
	if _state.control_attachment == BallMatchState.ControlAttachment.KEEPER_HANDS:
		var lateral := float(owner.state.save_lane - ShotAim.Lane.CENTER)
		_state._set_position(owner.state.position_m
			+ owner.state.facing_direction * _shot_config.keeper_hand_forward_m
			+ Vector2(0.0, lateral * _shot_config.keeper_hand_lateral_m))
		_state._set_control_height(owner.state.height_m + _shot_config.keeper_hand_height_m)
		return
	_state._set_position(
		owner.state.position_m + owner.state.facing_direction * _dribble_offset_m
	)
	_state._set_control_height(owner.state.height_m)


## Clears a queued shot after it is launched or ownership is cancelled.
func _clear_pending_shot() -> void:
	_pending_shot_player_id = ""
	_pending_shot_direction = Vector2.ZERO
	_pending_shot_power = 0.0
	_pending_shot_elapsed_seconds = 0.0
	_pending_shot_started_airborne = false


## Injects release-time targeting without letting input adapters alter a ball trajectory.
func configure_shot_aim(selector: Callable) -> void:
	_shot_aim_selector = selector


## Commits an authorized F04 catch through the unique ownership path, then attaches hands.
func catch_by_keeper(keeper: PlayerRuntime) -> BallAdvanceResult:
	var result := BallAdvanceResult.new()
	_claim_ball(keeper, result)
	_state._set_attachment(BallMatchState.ControlAttachment.KEEPER_HANDS)
	_set_ball_at_control_point(keeper)
	return result


## Ends only the whole-shot accumulator; rebound segment creation must never call this.
func _clear_shot_context() -> void:
	_shot_source = null
	_shot_context = null


## Cancels not-yet-released touches while preserving already flying balls and current ownership.
func cancel_pending_actions() -> void:
	_pending_pass_target_id = ""
	_pending_pass_elapsed_seconds = 0.0
	_clear_pending_shot()

## Freezes the final observation without resetting position, ownership or animation pose.
func freeze_for_terminal() -> void:
	cancel_pending_actions()
	if _state != null:
		_state._freeze_motion()
