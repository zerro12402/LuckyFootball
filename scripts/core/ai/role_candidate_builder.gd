## Generates position-specific legal proposals and explicit destinations, with no runtime or scene access.
class_name RoleCandidateBuilder
extends RefCounted

var _tuning: AIBehaviorConfig
var _rules: MatchConfigDefinition
var _field: FieldDefinition
var _regions: PlayerActivityRegionRepository

func _init(tuning: AIBehaviorConfig, rules: MatchConfigDefinition, field: FieldDefinition,
		regions: PlayerActivityRegionRepository = null) -> void:
	_tuning = tuning
	_rules = rules
	_field = field
	_regions = regions

## Builds categories once per review; precision jump/save opportunities are also checked every fixed step.
func build(snapshot: MatchStateSnapshot, player_id: String, role: String,
		anchor: Vector2, goal: Vector2, primary: String, is_pressured: bool,
		stamina_ratio: float = -1.0, position_id: String = "") -> Array[AIActionCandidate]:
	var player := snapshot.get_player(player_id)
	if player == null or snapshot.ball == null:
		return []
	if player.is_goalkeeper:
		return _keeper(snapshot, player, goal)
	var candidates: Array[AIActionCandidate] = []
	var ball := snapshot.ball
	var phase := TeamTacticalContext.phase_for(snapshot, player.team_id)
	var owns := ball.owner_player_id == player_id
	var is_primary_defender := phase == TeamTacticalContext.Phase.DEFEND \
		and not ball.owner_player_id.is_empty() and primary == player_id
	var is_primary_collector := phase == TeamTacticalContext.Phase.LOOSE and primary == player_id
	if TeamTacticalContext.is_defending_keeper_possession(snapshot, player.team_id):
		var retreat := movement_target(snapshot, player, AIActionCandidate.Behavior.RETURN,
			role, anchor, goal, position_id)
		return [_move(player, retreat, AIActionCandidate.Behavior.RETURN,
			_tuning.weight(role, AIActionCandidate.Behavior.RETURN))]
	if requires_region_return(snapshot, player, primary, position_id, goal):
		var bounds := activity_bounds(snapshot, player, position_id, goal)
		return [_move(player, _clamp_to_rect(player.position_m, bounds), AIActionCandidate.Behavior.RETURN,
			maxf(1.0, _tuning.weight(role, AIActionCandidate.Behavior.RETURN)))]
	if owns:
		candidates.append(_move(player, goal, AIActionCandidate.Behavior.ADVANCE,
			_advance_weight(snapshot, player, role, is_pressured)))
		candidates.append(_passes(snapshot, player, role, is_pressured, goal))
		if can_attempt_shot(player, goal):
			var distance := player.position_m.distance_to(goal)
			var floor_weight := _tuning.number("shot_min_multiplier")
			var scaled_distance := distance / _tuning.number("shot_distance_scale_m")
			var distance_factor := floor_weight + (1.0 - floor_weight) / (1.0 + scaled_distance * scaled_distance)
			# Start the ground shot lottery at zero weight when the carrier crosses the range limit.
			var range_ratio := distance / _tuning.number("shot_max_distance_m")
			var range_factor := maxf(0.0, 1.0 - range_ratio * range_ratio)
			var shot_weight := _tuning.weight(role, AIActionCandidate.Behavior.SHOOT) * distance_factor * range_factor
			candidates.append(_one(player_id, AIActionCandidate.Behavior.SHOOT,
				shot_weight, MatchAction.Type.SHOOT))
		if is_pressured:
			candidates.append(_one(player_id, AIActionCandidate.Behavior.JUMP,
				_tuning.weight(role, AIActionCandidate.Behavior.JUMP), MatchAction.Type.JUMP))
	elif is_primary_collector:
		candidates.append(_move(player, movement_target(snapshot, player,
			AIActionCandidate.Behavior.CHASE, role, anchor, goal, position_id), AIActionCandidate.Behavior.CHASE,
			_tuning.weight(role, AIActionCandidate.Behavior.CHASE)))
	elif phase == TeamTacticalContext.Phase.DEFEND:
		if is_primary_defender:
			candidates.append(_move(player, movement_target(snapshot, player,
				AIActionCandidate.Behavior.PRESS, role, anchor, goal, position_id), AIActionCandidate.Behavior.PRESS,
				_tuning.weight(role, AIActionCandidate.Behavior.PRESS)))
		else:
			candidates.append(_move(player, movement_target(snapshot, player,
				AIActionCandidate.Behavior.RETURN, role, anchor, goal, position_id), AIActionCandidate.Behavior.RETURN,
				_tuning.weight(role, AIActionCandidate.Behavior.RETURN)))
	else:
		var support := movement_target(snapshot, player, AIActionCandidate.Behavior.SUPPORT,
			role, anchor, goal, position_id)
		candidates.append(_move(player, support, AIActionCandidate.Behavior.SUPPORT,
			_tuning.weight(role, AIActionCandidate.Behavior.SUPPORT)))
	if not owns:
		_add_contests(snapshot, player, role, candidates)
	if not owns and not is_primary_defender and not is_primary_collector:
		candidates.append(_move(player, player.position_m, AIActionCandidate.Behavior.HOLD,
			_tuning.weight(role, AIActionCandidate.Behavior.HOLD)))
	if is_finite(stamina_ratio) and stamina_ratio >= 0.0:
		var scaled: Array[AIActionCandidate] = []
		for candidate in candidates:
			var factor := 1.0
			if candidate.behavior in [AIActionCandidate.Behavior.ADVANCE, AIActionCandidate.Behavior.PRESS,
					AIActionCandidate.Behavior.CHASE, AIActionCandidate.Behavior.JUMP, AIActionCandidate.Behavior.ATTACK]:
				factor = lerpf(_tuning.number("stamina_min_multiplier"), 1.0, clampf(stamina_ratio, 0.0, 1.0))
			scaled.append(AIActionCandidate.new(candidate.behavior, candidate.weight * factor, candidate.targets))
		return scaled
	return candidates

## Favors a forward's dribble when the immediate space is clear, independently of broader pressure.
func _advance_weight(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot,
		role: String, is_pressured: bool) -> float:
	var weight := _tuning.weight(role, AIActionCandidate.Behavior.ADVANCE)
	if is_pressured:
		weight *= _tuning.number("press_dribble_multiplier")
	if role != "forward":
		return weight
	var radius := _tuning.number("forward_clear_dribble_radius_m")
	for opponent in snapshot.players:
		if opponent.team_id != player.team_id \
				and opponent.position_m.distance_squared_to(player.position_m) <= radius * radius:
			return weight
	return weight * _tuning.number("forward_clear_dribble_multiplier")


## Gives passes a category weight independent of how many eligible teammates exist.
func _passes(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot,
		role: String, is_pressured: bool, goal: Vector2) -> AIActionCandidate:
	var targets: Array[AITargetOption] = []
	var best_direction_weight := 0.0
	for teammate in snapshot.players:
		var action := MatchAction.new(player.player_id, MatchAction.Type.PASS, Vector2.ZERO, teammate.player_id)
		if ActionEligibility.allows(snapshot, action, _rules):
			var progress := (teammate.position_m.x - player.position_m.x) * signf(goal.x)
			var direction_weight := _tuning.number("pass_lateral_weight")
			if progress > _tuning.number("pass_direction_deadzone_m"):
				direction_weight = _tuning.number("pass_forward_weight")
			elif progress < -_tuning.number("pass_direction_deadzone_m"):
				direction_weight = _tuning.number("pass_backward_weight")
			targets.append(AITargetOption.new(action, direction_weight))
			best_direction_weight = maxf(best_direction_weight, direction_weight)
	var category_factor := best_direction_weight / _tuning.number("pass_forward_weight")
	return AIActionCandidate.new(AIActionCandidate.Behavior.PASS,
		_tuning.weight(role, AIActionCandidate.Behavior.PASS) * category_factor
		* (_tuning.number("press_pass_multiplier") if is_pressured else 1.0), targets)

## Updates live movement destinations without reselecting behaviors or consuming AI samples.
func movement_target(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot,
		behavior: int, role: String, anchor: Vector2, goal: Vector2, position_id: String = "") -> Vector2:
	var carrier := snapshot.get_player(snapshot.ball.owner_player_id)
	var direction := signf(goal.x)
	var point := anchor
	match behavior:
		AIActionCandidate.Behavior.CHASE:
			# A live collection point must remain reachable even inside the ordinary field margin.
			return AIBallPrediction.point_at(snapshot.ball, _tuning.number("heartbeat_seconds"), _rules)
		AIActionCandidate.Behavior.PRESS:
			if carrier != null:
				point = carrier.position_m + carrier.movement_input * carrier.movement_speed_mps \
					* PlayerStateMachine.POSSESSION_MOVEMENT_SPEED_MULTIPLIER * _tuning.number("press_prediction_seconds")
		AIActionCandidate.Behavior.RETURN:
			if carrier == null or not carrier.is_goalkeeper or carrier.team_id == player.team_id:
				var threat := carrier.position_m if carrier != null else snapshot.ball.position_m
				point = anchor.lerp(threat - Vector2(direction * _tuning.number("defense_standoff_m"), 0), 0.5)
		AIActionCandidate.Behavior.SUPPORT:
			if snapshot.ball.target_player_id == player.player_id:
				return player.position_m
			point = anchor + Vector2(direction * _tuning.number("role_forward_offset_m"), 0)
			if carrier != null and carrier.team_id == player.team_id:
				var forward_offset := _tuning.number("role_forward_offset_m")
				if role == "back":
					forward_offset = -forward_offset
				point.x = carrier.position_m.x + direction * forward_offset
				point.y = carrier.position_m.y
				if not is_zero_approx(anchor.y):
					point.y += signf(anchor.y) * _tuning.number("support_spacing_m")
	if snapshot.ball.owner_player_id != player.player_id and behavior != AIActionCandidate.Behavior.PRESS:
		point = _clamp_to_rect(point, activity_bounds(snapshot, player, position_id, goal))
	return _bound_field_point(point)

## Resolves the current team's phase-specific bounds; legacy isolated sources can omit region data.
func activity_bounds(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot,
		position_id: String, goal: Vector2) -> Rect2:
	if _regions != null and not position_id.is_empty():
		var region := _regions.get_region(position_id, TeamTacticalContext.phase_for(snapshot, player.team_id))
		if region != null:
			return region.bounds(_field, signf(goal.x))
	return Rect2(Vector2(-_field.length_m, -_field.width_m) * 0.5,
		Vector2(_field.length_m, _field.width_m))

## Gives released ball duties a normal return path without cancelling possession or live receiving windows.
func requires_region_return(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot,
		primary: String, position_id: String, goal: Vector2) -> bool:
	if _regions == null or position_id.is_empty() or player.is_goalkeeper \
			or snapshot.ball.owner_player_id == player.player_id or primary == player.player_id \
			or (snapshot.ball.flight_kind == BallMatchState.FlightKind.PASS
				and snapshot.ball.target_player_id == player.player_id):
		return false
	var bounds := activity_bounds(snapshot, player, position_id, goal)
	return not player.position_m.is_equal_approx(_clamp_to_rect(player.position_m, bounds))

## Includes both rectangle edges, avoiding artificial oscillation at a responsibility boundary.
func _clamp_to_rect(point: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(clampf(point.x, bounds.position.x, bounds.end.x),
		clampf(point.y, bounds.position.y, bounds.end.y))

## Includes attacks against legal nearby opponents, not just the current ball carrier.
func _add_contests(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot, role: String,
		candidates: Array[AIActionCandidate]) -> void:
	var tackles: Array[AITargetOption] = []
	var attacks: Array[AITargetOption] = []
	for opponent in snapshot.players:
		if opponent.team_id == player.team_id:
			continue
		var direction := (opponent.position_m - player.position_m).normalized()
		if opponent.position_m.distance_to(player.position_m) <= _tuning.number("attack_start_m"):
			attacks.append(AITargetOption.new(MatchAction.new(player.player_id,
				MatchAction.Type.ATTACK, direction, opponent.player_id)))
		if opponent.player_id == snapshot.ball.owner_player_id:
			tackles.append(AITargetOption.new(MatchAction.new(player.player_id,
				MatchAction.Type.TACKLE, direction, opponent.player_id)))
	candidates.append(AIActionCandidate.new(AIActionCandidate.Behavior.ATTACK,
		_tuning.weight(role, AIActionCandidate.Behavior.ATTACK), attacks))
	candidates.append(AIActionCandidate.new(AIActionCandidate.Behavior.TACKLE,
		_tuning.weight(role, AIActionCandidate.Behavior.TACKLE), tackles))

## Predicts the receive window; automatic receiving jumps are reserved for an in-range aerial finish.
func aerial_action(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot,
		goal: Vector2 = Vector2.INF) -> MatchAction:
	var ball := snapshot.ball
	if player.is_goalkeeper or ball == null or player.action_state != PlayerMatchState.ActionState.IDLE:
		return null
	if ball.owner_player_id == player.player_id and player.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE:
		if goal.is_finite() and not can_attempt_shot(player, goal):
			return null
		return MatchAction.new(player.player_id, MatchAction.Type.SHOOT)
	if ball.flight_kind != BallMatchState.FlightKind.PASS or ball.target_player_id != player.player_id \
			or ball.flight_apex_height_m <= BallRuntimeSystem.MAX_RECEIVE_HEIGHT_M \
			or player.jump_phase != PlayerMatchState.JumpPhase.NONE:
		return null
	if goal.is_finite() and not can_attempt_shot(player, goal):
		return null
	var direction := ball.velocity_mps.normalized()
	var along := (player.position_m - ball.position_m).dot(direction)
	var lateral := (player.position_m - ball.position_m - direction * along).length()
	if lateral > BallRuntimeSystem.DEFAULT_POSSESSION_RADIUS_M:
		return null
	var time := AIBallPrediction.time_to(ball, player.position_m - direction * BallRuntimeSystem.DEFAULT_POSSESSION_RADIUS_M, _rules)
	if time < _rules.jump_takeoff_seconds or time > _tuning.number("aerial_receive_lead_seconds"):
		return null
	var contact_height := AIBallPrediction.height_at(ball,
		maxf(0.0, along - BallRuntimeSystem.DEFAULT_POSSESSION_RADIUS_M))
	var jump_progress := time / _rules.jump_duration_seconds
	var player_height := 4.0 * _rules.jump_apex_height_m * jump_progress * (1.0 - jump_progress)
	if absf(contact_height - player_height) > BallRuntimeSystem.AERIAL_RECEIVE_HEIGHT_TOLERANCE_M:
		return null
	return MatchAction.new(player.player_id, MatchAction.Type.JUMP)

## Collects controllable penalty-area balls, otherwise returns to ordinary goal-mouth positioning.
func _keeper(snapshot: MatchStateSnapshot, keeper: PlayerStateSnapshot, goal: Vector2) -> Array[AIActionCandidate]:
	var candidates: Array[AIActionCandidate] = []
	if snapshot.ball.owner_player_id == keeper.player_id:
		candidates.append(_passes(snapshot, keeper, "keeper", false, goal))
		candidates.append(_move(keeper, keeper.position_m, AIActionCandidate.Behavior.HOLD,
			_tuning.weight("keeper", AIActionCandidate.Behavior.HOLD)))
		return candidates
	var pickup := keeper_pickup_target(snapshot, keeper, goal)
	if pickup.is_finite():
		return [_move(keeper, pickup, AIActionCandidate.Behavior.CHASE,
			_tuning.weight("keeper", AIActionCandidate.Behavior.CHASE))]
	var margin := _tuning.number("keeper_post_margin_m")
	var limit := maxf(0.0, _field.goal_width_m * 0.5 - margin)
	var target := Vector2(-goal.x + signf(goal.x) * _tuning.number("keeper_line_offset_m"),
		clampf(snapshot.ball.position_m.y * 0.5, -limit, limit))
	if absf(keeper.position_m.x - target.x) > _tuning.number("arrival_m"):
		target.y = keeper.position_m.y
	candidates.append(_move(keeper, target, AIActionCandidate.Behavior.RETURN,
		_tuning.weight("keeper", AIActionCandidate.Behavior.RETURN)))
	if absf(keeper.position_m.x - target.x) > _tuning.number("arrival_m"):
		return candidates
	candidates.append(_move(keeper, keeper.position_m, AIActionCandidate.Behavior.HOLD,
		_tuning.weight("keeper", AIActionCandidate.Behavior.HOLD)))
	return candidates

## Limits AI shooting opportunities without restricting player commands or changing contest formulas.
func can_attempt_shot(player: PlayerStateSnapshot, goal: Vector2) -> bool:
	return goal.is_finite() and player.position_m.x * signf(goal.x) > 0.0 \
		and player.position_m.distance_to(goal) <= _tuning.number("shot_max_distance_m")

## Shares ordinary pickup limits and excludes active shots so collecting never bypasses F04.
func keeper_pickup_target(snapshot: MatchStateSnapshot, keeper: PlayerStateSnapshot,
		goal: Vector2) -> Vector2:
	var ball := snapshot.ball
	if not keeper.is_goalkeeper or ball == null or not ball.owner_player_id.is_empty() \
			or ball.flight_kind == BallMatchState.FlightKind.SHOT \
			or ball.height_m > BallRuntimeSystem.MAX_RECEIVE_HEIGHT_M + _rules.ball_radius_m \
			or ball.velocity_mps.length() > _rules.ball_control_max_speed_mps:
		return Vector2.INF
	var towards_own_goal := -signf(goal.x) * ball.position_m.x
	if towards_own_goal < _field.length_m * 0.5 - _field.penalty_area_depth_m \
			or towards_own_goal > _field.length_m * 0.5 \
			or absf(ball.position_m.y) > _field.penalty_area_width_m * 0.5:
		return Vector2.INF
	return ball.position_m

## Uses observable trajectory and the existing hand-cylinder contact solver to find legal save opportunities.
func save_candidate(snapshot: MatchStateSnapshot, keeper: PlayerStateSnapshot,
		goal: Vector2) -> AIActionCandidate:
	var ball := snapshot.ball
	if not keeper.is_goalkeeper or ball == null or ball.flight_kind != BallMatchState.FlightKind.SHOT:
		return null
	var until := minf(_tuning.number("keeper_prediction_seconds"), _rules.keeper_window_end_seconds)
	var copied := BallMatchState.new(ball.position_m)
	copied._launch_shot(ball.position_m, ball.velocity_mps, ball.flight_range_m,
		ball.flight_apex_height_m, ball.flight_start_height_m)
	copied._flight_distance_m = ball.flight_distance_m
	var trajectory := BallShotTrajectory.new(copied, until, _rules)
	var targets: Array[AITargetOption] = []
	for lane in [ShotAim.Lane.UPPER, ShotAim.Lane.CENTER, ShotAim.Lane.LOWER]:
		var facing := Vector2(signf(goal.x), 0.0)
		var hand := keeper.position_m + facing * _rules.keeper_hand_forward_m \
			+ Vector2(0.0, float(lane - ShotAim.Lane.CENTER) * _rules.keeper_hand_lateral_m)
		var body := BallContactPlayer.new(keeper.player_id, hand, hand,
			keeper.height_m + _rules.keeper_hand_height_m,
			keeper.height_m + _rules.keeper_hand_height_m, true)
		body.radius_m = _rules.keeper_contact_radius_m
		body.body_height_m = _rules.keeper_contact_height_m
		body.earliest_seconds = _rules.keeper_window_start_seconds
		body.latest_seconds = until
		if not BallContactResolver.find_candidates(trajectory, [body], _rules).is_empty():
			targets.append(AITargetOption.new(MatchAction.new(keeper.player_id, MatchAction.Type.SAVE,
				Vector2(facing.x, float(lane - ShotAim.Lane.CENTER)))))
	return AIActionCandidate.new(AIActionCandidate.Behavior.SAVE,
		_tuning.weight("keeper", AIActionCandidate.Behavior.SAVE), targets)

## Bounds ordinary positioning; live collection bypasses margins that could keep the ball outside pickup reach.
func _move(player: PlayerStateSnapshot, destination: Vector2, behavior: int, weight: float) -> AIActionCandidate:
	var point := _bound_field_point(destination)
	if player.is_goalkeeper or behavior == AIActionCandidate.Behavior.CHASE:
		point = destination
	var direction := (point - player.position_m).normalized()
	if behavior != AIActionCandidate.Behavior.CHASE and point.distance_to(player.position_m) <= _tuning.number("arrival_m"):
		direction = Vector2.ZERO
	return AIActionCandidate.new(behavior, weight,
		[AITargetOption.new(MatchAction.new(player.player_id, MatchAction.Type.MOVE, direction), 1.0, point)])

## Keeps recomputed tactical destinations inside the same field bounds as initial candidates.
func _bound_field_point(destination: Vector2) -> Vector2:
	var margin := _tuning.number("field_margin_m")
	return Vector2(clampf(destination.x, -_field.length_m * 0.5 + margin, _field.length_m * 0.5 - margin),
		clampf(destination.y, -_field.width_m * 0.5 + margin, _field.width_m * 0.5 - margin))

## Wraps a target-free instantaneous intent without multiplying its category weight.
func _one(id: String, behavior: int, weight: float, kind: int) -> AIActionCandidate:
	return AIActionCandidate.new(behavior, weight, [AITargetOption.new(MatchAction.new(id, kind))])
