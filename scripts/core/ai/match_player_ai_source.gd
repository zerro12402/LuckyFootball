## Coordinates twelve snapshot-driven AIs through the existing fixed-step action-source contract.
class_name MatchPlayerAISource
extends MatchActionSource

var errors: PackedStringArray:
	get: return _errors.duplicate()
var _errors: PackedStringArray = []
var _tuning: AIBehaviorConfig
var _rules: MatchConfigDefinition
var _field: FieldDefinition
var _builder: RoleCandidateBuilder
var _roles: Dictionary[String, String] = {}
var _positions: Dictionary[String, String] = {}
var _anchors: Dictionary[String, Vector2] = {}
var _goals: Dictionary[String, Vector2] = {}
var _brains: Dictionary[String, PlayerAI] = {}
var _plans: Dictionary[String, PlayerAIPlan] = {}
var _pressure: Dictionary[String, bool] = {}
var _save_sequences: Dictionary[String, int] = {}
var _aerial_pending: Dictionary[String, int] = {}
var _coordinator := TeamRoleCoordinator.new()
var _last_tactics: Dictionary[String, int] = {}
var _cached_batch: MatchActionBatch
var _stamina: AIStaminaSource
var _modifier: AIWeightModifier
var _fixed_delta_seconds: float

## Captures validated immutable setup, with an explicit unavailable-stamina adapter by default.
func _init(teams: TeamDataRepository, field: FieldDefinition, rules: MatchConfigDefinition,
		tuning: AIBehaviorConfig, modifier: AIWeightModifier = null,
		stamina: AIStaminaSource = null, fixed_delta_seconds: float = 1.0 / 60.0,
		regions: PlayerActivityRegionRepository = null) -> void:
	assert(is_finite(fixed_delta_seconds) and fixed_delta_seconds > 0.0)
	_fixed_delta_seconds = fixed_delta_seconds
	_tuning = tuning
	_rules = rules
	_field = field
	_modifier = modifier
	_stamina = stamina if stamina != null else AIStaminaSource.new()
	_builder = RoleCandidateBuilder.new(tuning, rules, field, regions)
	if tuning.number("keeper_post_margin_m") >= field.goal_width_m * 0.5 \
			or tuning.number("keeper_line_offset_m") >= field.length_m * 0.5 \
			or tuning.number("field_margin_m") >= minf(field.length_m, field.width_m) * 0.5:
		_errors.append("AI goal-mouth or field margins exceed this field")
	for team in teams.teams:
		for entry in teams.get_roster(team.team_id):
			var role := "keeper"
			if entry.default_position.begins_with("back"):
				role = "back"
			elif entry.default_position.begins_with("mid"):
				role = "mid"
			elif entry.default_position.begins_with("forward"):
				role = "forward"
			elif entry.default_position != "keeper":
				_errors.append("Unknown AI position: " + entry.default_position)
				continue
			_roles[entry.player_id] = role
			_positions[entry.player_id] = entry.default_position
			var point := teams.get_position(team.default_formation, entry.default_position).position_m
			_anchors[entry.player_id] = Vector2(point.x * team.attacking_direction, point.y)
			_goals[entry.player_id] = Vector2(field.length_m * 0.5 * team.attacking_direction, 0.0)

## Decisions depend only on the complete input step; repeated calls replay copies without extra draws.
func propose_actions(snapshot: MatchStateSnapshot) -> Array[MatchAction]:
	if snapshot == null or not snapshot.can_decide_player_actions or not _errors.is_empty():
		return []
	if _cached_batch != null and _cached_batch.matches(snapshot):
		return _cached_batch.actions
	var ids: Array[String] = []
	for player in snapshot.players:
		if not _roles.has(player.player_id):
			return []
		ids.append(player.player_id)
	ids.sort()
	var primaries: Dictionary[String, String] = {}
	for player in snapshot.players:
		if primaries.has(player.team_id):
			continue
		var phase := TeamTacticalContext.phase_for(snapshot, player.team_id)
		if _last_tactics.get(player.team_id, -1) != phase:
			_coordinator.clear_team(player.team_id)
		_last_tactics[player.team_id] = phase
		var carrier := snapshot.get_player(snapshot.ball.owner_player_id)
		var target := carrier.position_m if carrier != null else snapshot.ball.position_m
		primaries[player.team_id] = _coordinator.select_primary(snapshot, player.team_id, target, _tuning)
	var actions: Array[MatchAction] = []
	for id in ids:
		if not _brains.has(id):
			_brains[id] = PlayerAI.new(snapshot.random_seed, id, _modifier)
		var player := snapshot.get_player(id)
		actions.append_array(_advance_player(snapshot, player, primaries[player.team_id]))
	_cached_batch = MatchActionBatch.new(snapshot, actions)
	return actions.duplicate()

## Clears plans and deadlines on control changes; RNG progress survives pause and round reset.
func invalidate_control(_snapshot: MatchStateSnapshot) -> void:
	_plans.clear()
	_pressure.clear()
	_save_sequences.clear()
	_aerial_pending.clear()
	_last_tactics.clear()
	_coordinator.clear()
	_cached_batch = null

## Returns copied plan diagnostics; observing the source never advances its random streams.
func get_plan(id: String) -> MatchAction:
	return _plans[id].action if _plans.has(id) else null

func get_random_draws(id: String) -> int:
	return _brains[id].random_draws if _brains.has(id) else 0

## Returns a detached rectangle for diagnostics, without changing plans or random streams.
func get_activity_bounds(snapshot: MatchStateSnapshot, id: String) -> Rect2:
	var player := snapshot.get_player(id)
	if player == null or not _positions.has(id):
		return Rect2()
	return _builder.activity_bounds(snapshot, player, _positions[id], _goals[id])

## Copies already proposed commands for diagnostics without evaluating the next simulation step.
func get_last_actions() -> Array[MatchAction]:
	var actions: Array[MatchAction] = []
	if _cached_batch != null:
		actions.assign(_cached_batch.actions)
	return actions

## Checks precision opportunities before ordinary reviews, while preserving noncancelable runtime actions.
func _advance_player(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot,
		primary: String) -> Array[MatchAction]:
	var id := player.player_id
	if snapshot.kickoff_pending and id != snapshot.kickoff_player_id:
		return []
	if player.action_state != PlayerMatchState.ActionState.IDLE:
		_plans.erase(id)
		return []
	var phase := TeamTacticalContext.phase_for(snapshot, player.team_id)
	var hold_seconds := _tuning.number("keeper_hold_seconds") if player.is_goalkeeper else _tuning.number("hold_seconds")
	var precision := _precision_action(snapshot, player)
	if precision != null:
		_plans.erase(id)
		return _emit_action(precision, player)
	var plan: PlayerAIPlan = _plans.get(id)
	var has_contest := _can_challenge_carrier(snapshot, player, primary)
	var changed := plan == null
	if plan != null:
		changed = plan.owner_id != snapshot.ball.owner_player_id or plan.tactical_phase != phase \
			or plan.flight_sequence != snapshot.ball.flight_sequence or snapshot.elapsed_seconds >= plan.expires_at
		changed = changed or plan.primary_player_id != primary \
			or (has_contest and not plan.had_contest_opportunity)
		changed = changed or (plan.behavior != AIActionCandidate.Behavior.RETURN
			and _builder.requires_region_return(snapshot, player, primary, _positions[id], _goals[id]))
		if player.is_goalkeeper:
			var pickup := _builder.keeper_pickup_target(snapshot, player, _goals[id])
			var was_collecting := plan.behavior == AIActionCandidate.Behavior.CHASE
			changed = changed or was_collecting != pickup.is_finite()
			if was_collecting and pickup.is_finite():
				plan.target_m = pickup
		if snapshot.elapsed_seconds >= plan.next_review_at:
			plan.next_review_at = snapshot.elapsed_seconds + _tuning.number("heartbeat_seconds")
			changed = changed or snapshot.elapsed_seconds >= plan.started_at + hold_seconds
		if plan.action.action_type != MatchAction.Type.MOVE:
			changed = changed or plan.was_sent
		elif plan.target_m.is_finite() and player.position_m.distance_to(plan.target_m) <= _tuning.number("arrival_m"):
			changed = changed or snapshot.elapsed_seconds >= plan.started_at + hold_seconds
	if changed:
		_update_pressure(snapshot, player)
		var choices := _builder.build(snapshot, id, _roles[id], _anchors[id], _goals[id],
			primary, _pressure.get(id, false), _stamina.ratio(snapshot, id), _positions[id])
		var selected := _brains[id].choose(snapshot, id, choices, _rules)
		if selected == null:
			_plans.erase(id)
			return []
		var destination := player.position_m
		if _brains[id].selected_target != null and _brains[id].selected_target.destination_m.is_finite():
			destination = _brains[id].selected_target.destination_m
		plan = PlayerAIPlan.new(selected, destination, snapshot, phase, _tuning)
		plan.behavior = _brains[id].selected_behavior
		plan.primary_player_id = primary
		_plans[id] = plan
	plan.had_contest_opportunity = has_contest
	if not player.is_goalkeeper and plan.behavior in [
		AIActionCandidate.Behavior.PRESS, AIActionCandidate.Behavior.SUPPORT, AIActionCandidate.Behavior.RETURN,
		AIActionCandidate.Behavior.CHASE]:
		plan.target_m = _builder.movement_target(snapshot, player, plan.behavior,
			_roles[id], _anchors[id], _goals[id], _positions[id])
	if plan.action.action_type == MatchAction.Type.MOVE:
		var remaining := plan.target_m - player.position_m
		var direction := remaining.normalized()
		var outside_region := plan.behavior == AIActionCandidate.Behavior.RETURN \
			and _builder.requires_region_return(snapshot, player, primary, _positions[id], _goals[id])
		if remaining.length() <= _tuning.number("arrival_m") and not outside_region \
				and plan.behavior != AIActionCandidate.Behavior.CHASE:
			direction = Vector2.ZERO
		else:
			# Clamp to destination within one fixed step; speed comes from actual copied runtime values.
			var speed := player.movement_speed_mps
			if snapshot.ball.owner_player_id == id:
				speed *= PlayerStateMachine.POSSESSION_MOVEMENT_SPEED_MULTIPLIER
			direction *= minf(1.0, remaining.length() / (speed * _fixed_delta_seconds))
		return [MatchAction.new(id, MatchAction.Type.MOVE, direction)]
	if not ActionEligibility.allows(snapshot, plan.action, _rules):
		_plans.erase(id)
		return [MatchAction.new(id, MatchAction.Type.MOVE)]
	plan.was_sent = true
	if plan.action.action_type == MatchAction.Type.JUMP:
		_aerial_pending[id] = snapshot.ball.flight_sequence
	return _emit_action(plan.action, player)

## Recognizes new legal contest windows without sampling or directly starting a runtime action.
func _can_challenge_carrier(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot,
		primary: String) -> bool:
	if player.is_goalkeeper or player.player_id != primary:
		return false
	var carrier := snapshot.get_player(snapshot.ball.owner_player_id)
	if carrier == null or carrier.team_id == player.team_id:
		return false
	var direction := (carrier.position_m - player.position_m).normalized()
	var tackle := MatchAction.new(player.player_id, MatchAction.Type.TACKLE, direction, carrier.player_id)
	if ActionEligibility.allows(snapshot, tackle, _rules):
		return true
	if player.position_m.distance_to(carrier.position_m) > _tuning.number("attack_start_m"):
		return false
	return ActionEligibility.allows(snapshot, MatchAction.new(player.player_id,
		MatchAction.Type.ATTACK, direction, carrier.player_id), _rules)

## Keeps aerial receptions and legal shot saves responsive at every simulation step.
func _precision_action(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot) -> MatchAction:
	var id := player.player_id
	var ball := snapshot.ball
	if player.is_goalkeeper:
		if _save_sequences.get(id, -1) == ball.flight_sequence:
			return null
		var save := _builder.save_candidate(snapshot, player, _goals[id])
		if save != null and not save.targets.is_empty():
			var action := _brains[id].choose(snapshot, id, [save], _rules)
			if action != null and action.action_type == MatchAction.Type.SAVE:
				_save_sequences[id] = ball.flight_sequence
				return action
		return null
	if _aerial_pending.has(id) and player.jump_phase == PlayerMatchState.JumpPhase.NONE:
		_aerial_pending.erase(id)
	var aerial := _builder.aerial_action(snapshot, player, _goals[id])
	if aerial != null and aerial.action_type == MatchAction.Type.SHOOT and (
		not _aerial_pending.has(id) or _aerial_pending[id] != ball.flight_sequence):
		return null
	if aerial != null and ActionEligibility.allows(snapshot, aerial, _rules):
		if aerial.action_type == MatchAction.Type.JUMP:
			_aerial_pending[id] = ball.flight_sequence
		return aerial
	return null

## Applies hysteresis to actionable opponents; a nearby downed player does not exert live pressure.
func _update_pressure(snapshot: MatchStateSnapshot, player: PlayerStateSnapshot) -> void:
	var distance := INF
	for opponent in snapshot.players:
		if opponent.team_id != player.team_id and opponent.action_state == PlayerMatchState.ActionState.IDLE:
			distance = minf(distance, opponent.position_m.distance_to(player.position_m))
	var threshold := _tuning.number("pressure_exit_m") if _pressure.get(player.player_id, false) else _tuning.number("pressure_m")
	_pressure[player.player_id] = distance <= threshold

## Stops for kicks/receptions, preserves a carrier's moving jump, and captures lunge direction.
func _emit_action(action: MatchAction, player: PlayerStateSnapshot) -> Array[MatchAction]:
	var direction := Vector2.ZERO
	if action.action_type in [MatchAction.Type.TACKLE, MatchAction.Type.ATTACK]:
		direction = action.direction
	elif action.action_type == MatchAction.Type.JUMP \
			and player.possession_state == PlayerMatchState.PossessionState.POSSESSING:
		direction = player.movement_input
	return [MatchAction.new(player.player_id, MatchAction.Type.MOVE, direction), action]
