class_name BallRuntimeSystem
extends RefCounted

const DEFAULT_POSSESSION_RADIUS_M := 0.75
const DEFAULT_DRIBBLE_OFFSET_M := 0.55

var state: BallMatchState:
	get:
		return _state

var _state: BallMatchState
var _possession_radius_m: float
var _dribble_offset_m: float


func _init(
	possession_radius_m: float = DEFAULT_POSSESSION_RADIUS_M,
	dribble_offset_m: float = DEFAULT_DRIBBLE_OFFSET_M,
) -> void:
	assert(possession_radius_m > 0.0, "Possession radius must be positive")
	assert(dribble_offset_m > 0.0, "Dribble offset must be positive")
	_possession_radius_m = possession_radius_m
	_dribble_offset_m = dribble_offset_m


func register_ball(initial_position_m: Vector2) -> bool:
	if _state != null:
		return false
	_state = BallMatchState.new(initial_position_m)
	return true


func advance(player_runtime_system: PlayerRuntimeSystem) -> String:
	assert(player_runtime_system != null, "Ball system requires player runtimes")
	if _state == null:
		return ""
	if _state.motion_state == BallMatchState.MotionState.OWNED:
		_follow_owner(player_runtime_system)
		return ""
	if _state.motion_state != BallMatchState.MotionState.LOOSE:
		return ""

	var new_owner := _find_possession_candidate(player_runtime_system)
	if new_owner == null:
		return ""
	_state._set_owner(new_owner.player_id)
	new_owner.state_machine.set_possession_state(
		PlayerMatchState.PossessionState.POSSESSING
	)
	_set_ball_at_control_point(new_owner)
	return new_owner.player_id


func create_snapshot() -> BallStateSnapshot:
	if _state == null:
		return null
	return BallStateSnapshot.new(_state)


func _find_possession_candidate(
	player_runtime_system: PlayerRuntimeSystem,
) -> PlayerRuntime:
	var nearest_player: PlayerRuntime
	var nearest_distance_squared := (
		_possession_radius_m * _possession_radius_m + 0.000001
	)
	for player_runtime in player_runtime_system.get_players():
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


func _follow_owner(player_runtime_system: PlayerRuntimeSystem) -> void:
	var owner := player_runtime_system.get_player(_state.owner_player_id)
	if owner == null:
		_state._release(_state.position_m)
		return
	_set_ball_at_control_point(owner)


func _set_ball_at_control_point(owner: PlayerRuntime) -> void:
	_state._set_position(
		owner.state.position_m
		+ owner.state.facing_direction * _dribble_offset_m
	)
