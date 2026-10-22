## Proposes chase, tackle and goal-directed dribble commands for either test player.
class_name TackleChaseAI
extends RefCounted

var _defender_id: String
var _target_id: String
var _config: MatchConfigDefinition
var _opponent_goal_center_m: Vector2
var _target_movement_speed_mps: float


## Stores fixed test identities and target goal without holding mutable match state.
func _init(
	defender_id: String,
	target_id: String,
	config: MatchConfigDefinition,
	opponent_goal_center_m: Vector2,
	target_movement_speed_mps: float = PlayerStateMachine.DEFAULT_MOVEMENT_SPEED_MPS,
) -> void:
	assert(not defender_id.is_empty() and not target_id.is_empty())
	assert(defender_id != target_id and config != null)
	assert(opponent_goal_center_m.is_finite())
	assert(is_finite(target_movement_speed_mps) and target_movement_speed_mps > 0.0)
	_defender_id = defender_id
	_target_id = target_id
	_config = config
	_opponent_goal_center_m = opponent_goal_center_m
	_target_movement_speed_mps = target_movement_speed_mps


## Chases the carrier, tackles in range, then dribbles toward the opponent goal.
func propose_actions(snapshot: MatchStateSnapshot) -> Array[MatchAction]:
	var actions: Array[MatchAction] = []
	var defender := snapshot.get_player(_defender_id)
	var target := snapshot.get_player(_target_id)
	if defender == null or target == null or snapshot.ball == null:
		return actions
	if snapshot.round_phase != MatchState.RoundPhase.PLAYING:
		return actions
	if snapshot.ball.owner_player_id == _defender_id:
		var toward_goal := _opponent_goal_center_m - defender.position_m
		var goal_direction := Vector2.ZERO
		if not toward_goal.is_zero_approx():
			goal_direction = toward_goal.normalized()
		actions.append(MatchAction.new(_defender_id, MatchAction.Type.MOVE, goal_direction))
		return actions
	var chase_position := (snapshot.ball.position_m if snapshot.ball.owner_player_id.is_empty()
		else target.position_m)
	var toward_target := chase_position - defender.position_m
	var direction := Vector2.ZERO
	if not toward_target.is_zero_approx():
		direction = toward_target.normalized()
	actions.append(MatchAction.new(_defender_id, MatchAction.Type.MOVE, direction))
	if snapshot.ball.owner_player_id != _target_id:
		return actions
	if defender.action_state != PlayerMatchState.ActionState.IDLE:
		return actions
	if defender.jump_phase != PlayerMatchState.JumpPhase.NONE:
		return actions
	if toward_target.length() > _anticipation_distance(target, direction):
		return actions
	actions.append(MatchAction.new(
		_defender_id, MatchAction.Type.TACKLE, Vector2.ZERO, _target_id
	))
	return actions


## Compensates for windup travel, using the lunge speed rather than normal chase speed.
func _anticipation_distance(target: PlayerStateSnapshot, direction: Vector2) -> float:
	var target_velocity := Vector2.ZERO
	if target.action_state == PlayerMatchState.ActionState.IDLE:
		target_velocity = target.movement_input * _target_movement_speed_mps
		if target.possession_state == PlayerMatchState.PossessionState.POSSESSING:
			target_velocity *= PlayerStateMachine.POSSESSION_MOVEMENT_SPEED_MULTIPLIER
	var lunge_speed := _config.tackle_lunge_distance_m / _config.tackle_action_duration_seconds
	var closing_speed := lunge_speed - target_velocity.dot(direction)
	return minf(_config.tackle_start_range_m, maxf(0.0,
		_config.tackle_range_m + closing_speed * _config.tackle_windup_seconds))
