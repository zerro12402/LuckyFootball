## Proposes chase, tackle, and goal-directed dribble commands for one demo opponent.
class_name TackleChaseAI
extends RefCounted

var _defender_id: String
var _target_id: String
var _config: MatchConfigDefinition
var _opponent_goal_center_m: Vector2


## Stores fixed test identities and target goal without holding mutable match state.
func _init(
	defender_id: String,
	target_id: String,
	config: MatchConfigDefinition,
	opponent_goal_center_m: Vector2,
) -> void:
	assert(not defender_id.is_empty() and not target_id.is_empty())
	assert(defender_id != target_id and config != null)
	assert(opponent_goal_center_m.is_finite())
	_defender_id = defender_id
	_target_id = target_id
	_config = config
	_opponent_goal_center_m = opponent_goal_center_m


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
	var toward_target := target.position_m - defender.position_m
	var direction := Vector2.ZERO
	if not toward_target.is_zero_approx():
		direction = toward_target.normalized()
	actions.append(MatchAction.new(_defender_id, MatchAction.Type.MOVE, direction))
	if snapshot.ball.owner_player_id != _target_id:
		return actions
	if defender.action_state != PlayerMatchState.ActionState.IDLE:
		return actions
	if toward_target.length() > _config.tackle_range_m:
		return actions
	actions.append(MatchAction.new(
		_defender_id, MatchAction.Type.TACKLE, Vector2.ZERO, _target_id
	))
	return actions
