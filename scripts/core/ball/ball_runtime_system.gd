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

var state: BallMatchState:
	get:
		return _state

var _state: BallMatchState
var _possession_radius_m: float
var _dribble_offset_m: float
var _pass_speed_mps: float
var _max_pass_distance_m: float
var _lofted_pass_min_distance_m: float
var _lofted_pass_apex_height_m: float
var _pending_pass_target_id: String = ""
var _pending_pass_elapsed_seconds: float = 0.0


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


func register_ball(initial_position_m: Vector2) -> bool:
	if _state != null:
		return false
	_state = BallMatchState.new(initial_position_m)
	return true


func try_start_pass(passer: PlayerRuntime, receiver: PlayerRuntime) -> bool:
	if _state == null or passer == null or receiver == null:
		return false
	if _state.motion_state != BallMatchState.MotionState.OWNED:
		return false
	if _state.owner_player_id != passer.player_id or not _pending_pass_target_id.is_empty():
		return false
	if passer.player_id == receiver.player_id or passer.team_id != receiver.team_id:
		return false
	if receiver.state.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN:
		return false
	var pass_distance_m := _state.position_m.distance_to(receiver.state.position_m)
	if pass_distance_m < MIN_PASS_DISTANCE_M or pass_distance_m > _max_pass_distance_m:
		return false
	if not passer.state_machine.try_start_action(PlayerMatchState.ActionState.PASSING):
		return false
	_pending_pass_target_id = receiver.player_id
	_pending_pass_elapsed_seconds = 0.0
	return true


func advance(
	fixed_delta_seconds: float,
	player_runtime_system: PlayerRuntimeSystem,
) -> BallAdvanceResult:
	assert(fixed_delta_seconds > 0.0, "Fixed delta must be positive")
	assert(player_runtime_system != null, "Ball system requires player runtimes")
	var result := BallAdvanceResult.new()
	if _state == null:
		return result
	if _state.motion_state == BallMatchState.MotionState.OWNED:
		_advance_owned(fixed_delta_seconds, player_runtime_system, result)
	if _state.motion_state == BallMatchState.MotionState.IN_FLIGHT:
		_advance_flight(fixed_delta_seconds, player_runtime_system, result)
	elif _state.motion_state == BallMatchState.MotionState.LOOSE:
		_try_acquire_loose_ball(player_runtime_system, result)
	return result


func create_snapshot() -> BallStateSnapshot:
	if _state == null:
		return null
	return BallStateSnapshot.new(_state)


func _advance_owned(
	fixed_delta_seconds: float,
	players: PlayerRuntimeSystem,
	result: BallAdvanceResult,
) -> void:
	_follow_owner(players)
	if _state.motion_state != BallMatchState.MotionState.OWNED:
		_pending_pass_target_id = ""
		return
	if _pending_pass_target_id.is_empty():
		return
	_pending_pass_elapsed_seconds += fixed_delta_seconds
	if _pending_pass_elapsed_seconds >= PlayerStateMachine.PASS_WINDUP_SECONDS:
		_launch_pending_pass(players, result)


func _launch_pending_pass(
	players: PlayerRuntimeSystem,
	result: BallAdvanceResult,
) -> void:
	var passer := players.get_player(_state.owner_player_id)
	var receiver := players.get_player(_pending_pass_target_id)
	_pending_pass_target_id = ""
	_pending_pass_elapsed_seconds = 0.0
	if passer == null or receiver == null:
		return
	var pass_direction := receiver.state.position_m - _state.position_m
	if pass_direction.is_zero_approx():
		pass_direction = passer.state.facing_direction
	passer.state_machine.set_possession_state(
		PlayerMatchState.PossessionState.NO_BALL
	)
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
	result.passed_by_player_id = passer.player_id


func _advance_flight(
	fixed_delta_seconds: float,
	players: PlayerRuntimeSystem,
	result: BallAdvanceResult,
) -> void:
	var remaining_distance_m := _state.flight_range_m - _state.flight_distance_m
	var travel_distance_m := minf(
		_state.velocity_mps.length() * fixed_delta_seconds,
		remaining_distance_m,
	)
	var next_position_m := (
		_state.position_m + _state.velocity_mps.normalized() * travel_distance_m
	)
	var receiver := players.get_player(_state.target_player_id)
	if _can_receive_flight(receiver, next_position_m):
		_receive_pass(receiver, result)
		return
	_state._advance_flight(next_position_m, travel_distance_m)
	if _state.flight_distance_m + DISTANCE_EPSILON >= _state.flight_range_m:
		_state._release(next_position_m)
		result.was_pass_missed = true


func _can_receive_flight(
	receiver: PlayerRuntime,
	next_position_m: Vector2,
) -> bool:
	if receiver == null:
		return false
	if receiver.state.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN:
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
	var closest_flight_distance_m := (
		_state.flight_distance_m + segment.length() * segment_fraction
	)
	if _state.calculate_height_at_distance(closest_flight_distance_m) > MAX_RECEIVE_HEIGHT_M:
		return false
	return closest_position_m.distance_squared_to(receiver.state.position_m) <= (
		_possession_radius_m * _possession_radius_m
	)


func _receive_pass(receiver: PlayerRuntime, result: BallAdvanceResult) -> void:
	_state._set_owner(receiver.player_id)
	receiver.state_machine.set_possession_state(
		PlayerMatchState.PossessionState.POSSESSING
	)
	_set_ball_at_control_point(receiver)
	result.new_owner_player_id = receiver.player_id
	result.received_by_player_id = receiver.player_id


func _try_acquire_loose_ball(
	players: PlayerRuntimeSystem,
	result: BallAdvanceResult,
) -> void:
	var new_owner := _find_possession_candidate(players)
	if new_owner == null:
		return
	_state._set_owner(new_owner.player_id)
	new_owner.state_machine.set_possession_state(
		PlayerMatchState.PossessionState.POSSESSING
	)
	_set_ball_at_control_point(new_owner)
	result.new_owner_player_id = new_owner.player_id


func _find_possession_candidate(players: PlayerRuntimeSystem) -> PlayerRuntime:
	var nearest_player: PlayerRuntime
	var nearest_distance_squared := (
		_possession_radius_m * _possession_radius_m + DISTANCE_EPSILON
	)
	for player_runtime in players.get_players():
		if (
			player_runtime.state.possession_state
			!= PlayerMatchState.PossessionState.NO_BALL
		):
			continue
		var distance_squared := player_runtime.state.position_m.distance_squared_to(
			_state.position_m
		)
		if distance_squared < nearest_distance_squared:
			nearest_player = player_runtime
			nearest_distance_squared = distance_squared
	return nearest_player


func _follow_owner(players: PlayerRuntimeSystem) -> void:
	var owner := players.get_player(_state.owner_player_id)
	if owner == null:
		_state._release(_state.position_m)
		return
	_set_ball_at_control_point(owner)


func _set_ball_at_control_point(owner: PlayerRuntime) -> void:
	_state._set_position(
		owner.state.position_m
		+ owner.state.facing_direction * _dribble_offset_m
	)
