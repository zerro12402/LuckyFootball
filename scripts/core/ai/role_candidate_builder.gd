## Generates position-specific legal proposals and explicit destinations, with no runtime or scene access.
class_name RoleCandidateBuilder
extends RefCounted

var _tuning: AIBehaviorConfig
var _rules: MatchConfigDefinition
var _field: FieldDefinition

func _init(tuning: AIBehaviorConfig, rules: MatchConfigDefinition, field: FieldDefinition) -> void:
	_tuning = tuning
	_rules = rules
	_field = field

## Builds categories once per review; precision jump/save opportunities are also checked every fixed step.
func build(snapshot: MatchStateSnapshot, player_id: String, role: String,
		anchor: Vector2, goal: Vector2, primary: String, is_pressured: bool,
		stamina_ratio: float = -1.0) -> Array[AIActionCandidate]:
	var player := snapshot.get_player(player_id)
	if player == null or snapshot.ball == null:
		return []
	if player.is_goalkeeper:
		return _keeper(snapshot, player, goal)
	var candidates: Array[AIActionCandidate] = []
	var ball := snapshot.ball
	var phase := TeamTacticalContext.phase_for(snapshot, player.team_id)
	var owns := ball.owner_player_id == player_id
	if owns:
		candidates.append(_move(player, goal, AIActionCandidate.Behavior.ADVANCE,
			_tuning.weight(role, AIActionCandidate.Behavior.ADVANCE) * (_tuning.number("press_dribble_multiplier") if is_pressured else 1.0)))
		candidates.append(_passes(snapshot, player, role, is_pressured))
		var distance := player.position_m.distance_to(goal)
		var floor_weight := _tuning.number("shot_min_multiplier")
		var shot_factor := floor_weight + (1.0 - floor_weight) / (1.0 + pow(distance / _tuning.number("shot_distance_scale_m"), 2.0))
		candidates.append(_one(player_id, AIActionCandidate.Behavior.SHOOT,
			_tuning.weight(role, AIActionCandidate.Behavior.SHOOT) * shot_factor, MatchAction.Type.SHOOT))
		candidates.append(_one(player_id, AIActionCandidate.Behavior.JUMP,
			_tuning.weight(role, AIActionCandidate.Behavior.JUMP), MatchAction.Type.JUMP))
	elif phase == TeamTacticalContext.Phase.LOOSE and primary == player_id:
		var intercept := AIBallPrediction.point_at(ball, _tuning.number("heartbeat_seconds"), _rules)
		candidates.append(_move(player, intercept, AIActionCandidate.Behavior.CHASE,
			_tuning.weight(role, AIActionCandidate.Behavior.CHASE)))
	elif phase == TeamTacticalContext.Phase.DEFEND:
		var carrier := snapshot.get_player(ball.owner_player_id)
		if carrier != null and primary == player_id:
			candidates.append(_move(player, carrier.position_m, AIActionCandidate.Behavior.PRESS,
				_tuning.weight(role, AIActionCandidate.Behavior.PRESS)))
		candidates.append(_move(player, anchor, AIActionCandidate.Behavior.RETURN,
			_tuning.weight(role, AIActionCandidate.Behavior.RETURN)))
	else:
		var offset := Vector2(signf(goal.x) * _tuning.number("role_forward_offset_m"), 0.0)
		var support := anchor + offset
		if not is_zero_approx(anchor.y):
			support.y = signf(anchor.y) * maxf(absf(anchor.y), _tuning.number("support_spacing_m"))
		var owner := snapshot.get_player(ball.owner_player_id)
		if owner != null:
			support.x = (support.x + owner.position_m.x) * 0.5
		if ball.target_player_id == player_id:
			# Hold the planned receiving lane instead of running away from the directed high pass.
			support = player.position_m
		candidates.append(_move(player, support, AIActionCandidate.Behavior.SUPPORT,
			_tuning.weight(role, AIActionCandidate.Behavior.SUPPORT)))
	if not owns:
		_add_contests(snapshot, player, role, candidates)
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

## Gives passes a category weight independent of how many eligible teammates exist.
func _passes(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot,
		role: String, is_pressured: bool) -> AIActionCandidate:
	var targets: Array[AITargetOption] = []
	for teammate in snapshot.players:
		var action := MatchAction.new(player.player_id, MatchAction.Type.PASS, Vector2.ZERO, teammate.player_id)
		if ActionEligibility.allows(snapshot, action, _rules):
			targets.append(AITargetOption.new(action))
	return AIActionCandidate.new(AIActionCandidate.Behavior.PASS,
		_tuning.weight(role, AIActionCandidate.Behavior.PASS) * (_tuning.number("press_pass_multiplier") if is_pressured else 1.0), targets)

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

## Predicts the first receive window and jumps only while the directed high pass can arrive airborne.
func aerial_action(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot) -> MatchAction:
	var ball := snapshot.ball
	if player.is_goalkeeper or ball == null or player.action_state != PlayerMatchState.ActionState.IDLE:
		return null
	if ball.owner_player_id == player.player_id and player.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE:
		return MatchAction.new(player.player_id, MatchAction.Type.SHOOT)
	if ball.flight_kind != BallMatchState.FlightKind.PASS or ball.target_player_id != player.player_id \
			or ball.flight_apex_height_m <= BallRuntimeSystem.MAX_RECEIVE_HEIGHT_M \
			or player.jump_phase != PlayerMatchState.JumpPhase.NONE:
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

## Keeps the keeper inside its goal mouth; forced displacement is recovered through ordinary movement.
func _keeper(snapshot: MatchStateSnapshot, keeper: PlayerStateSnapshot, goal: Vector2) -> Array[AIActionCandidate]:
	var candidates: Array[AIActionCandidate] = []
	if snapshot.ball.owner_player_id == keeper.player_id:
		candidates.append(_passes(snapshot, keeper, "keeper", false))
		candidates.append(_move(keeper, keeper.position_m, AIActionCandidate.Behavior.HOLD,
			_tuning.weight("keeper", AIActionCandidate.Behavior.HOLD)))
		return candidates
	var margin := _tuning.number("keeper_post_margin_m")
	var limit := maxf(0.0, _field.goal_width_m * 0.5 - margin)
	var target := Vector2(-goal.x + signf(goal.x) * _tuning.number("keeper_line_offset_m"),
		clampf(snapshot.ball.position_m.y * 0.5, -limit, limit))
	if absf(keeper.position_m.x - target.x) > _tuning.number("arrival_m"):
		target.y = keeper.position_m.y
	candidates.append(_move(keeper, target, AIActionCandidate.Behavior.RETURN,
		_tuning.weight("keeper", AIActionCandidate.Behavior.RETURN)))
	candidates.append(_move(keeper, keeper.position_m, AIActionCandidate.Behavior.HOLD,
		_tuning.weight("keeper", AIActionCandidate.Behavior.HOLD)))
	return candidates

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

## Bounds ordinary field-player destinations; keepers use their stricter goal-mouth targets above.
func _move(player: PlayerStateSnapshot, destination: Vector2, behavior: int, weight: float) -> AIActionCandidate:
	var margin := _tuning.number("field_margin_m")
	var point := Vector2(clampf(destination.x, -_field.length_m * 0.5 + margin, _field.length_m * 0.5 - margin),
		clampf(destination.y, -_field.width_m * 0.5 + margin, _field.width_m * 0.5 - margin))
	if player.is_goalkeeper:
		point = destination
	var direction := (point - player.position_m).normalized()
	if point.distance_to(player.position_m) <= _tuning.number("arrival_m"):
		direction = Vector2.ZERO
	return AIActionCandidate.new(behavior, weight,
		[AITargetOption.new(MatchAction.new(player.player_id, MatchAction.Type.MOVE, direction), 1.0, point)])

## Wraps a target-free instantaneous intent without multiplying its category weight.
func _one(id: String, behavior: int, weight: float, kind: int) -> AIActionCandidate:
	return AIActionCandidate.new(behavior, weight, [AITargetOption.new(MatchAction.new(id, kind))])
