## Verifies fixed-step knockdown contact, ball release, lunge, and recovery.
extends SceneTree

const STEP := 0.1
const ATTACKER_ID := "attacker"
const TARGET_ID := "target"

var _config: MatchConfigDefinition
var _field: FieldDefinition
var _failures: PackedStringArray = []


## Loads real rules and runs deterministic contact scenarios without rendering.
func _init() -> void:
	var repository := DataRepository.new()
	_expect(repository.load_all(), "Static data failed to load")
	if not _failures.is_empty():
		_finish()
		return
	_config = repository.get_match_config_by_id("demo_match")
	_field = repository.get_field_by_id("demo_field")
	test_attack_rejects_invalid_geometry_and_team()
	test_knockdown_waits_for_contact_and_releases_ball()
	test_configured_knockback_distance()
	test_overlap_uses_attack_direction_for_knockback()
	test_lunge_reaches_target_started_outside_contact_range()
	test_target_outside_contact_range_is_not_hit()
	test_hit_at_window_start()
	test_delayed_window_ignores_early_contact()
	test_hit_at_window_end()
	test_hit_at_full_action_endpoint()
	test_contact_after_window_is_ignored()
	test_repeat_hit_does_not_restart_down_timer()
	test_lunge_uses_initial_direction_and_configured_distance()
	test_landing_animation_and_crouch_hold_block_actions()
	test_knockdown_blocks_actions_until_getting_up_finishes()
	test_reset_clears_knockdown()
	_finish()


## A distant or back-facing lunge misses once when its hit window expires.
func test_attack_rejects_invalid_geometry_and_team() -> void:
	for target_position_m in [Vector2(7.0, 0.0), Vector2(-1.0, 0.0)]:
		var simulation := _create_match(target_position_m, "away")
		var miss_count := 0
		var start_events := simulation.advance_fixed_step(STEP, [_attack_command()])
		_expect(_find_event(start_events, MatchEvent.Type.ACTION_ACCEPTED) != null,
			"Legal lunge was rejected before checking contact")
		for event in start_events:
			if event.event_type == MatchEvent.Type.KNOCKDOWN_MISSED:
				miss_count += 1
		for step_index in range(8):
			var events := simulation.advance_fixed_step(STEP, [])
			for event in events:
				if event.event_type == MatchEvent.Type.KNOCKDOWN_MISSED:
					miss_count += 1
		_expect(miss_count == 1, "Missed lunge did not emit exactly one expiry event")
		_expect(simulation.create_snapshot().get_player(TARGET_ID).action_state
			== PlayerMatchState.ActionState.IDLE,
			"Missed attack changed the target")
	var teammate_simulation := _create_match(Vector2(1.0, 0.0), "home")
	var teammate_events := teammate_simulation.advance_fixed_step(STEP, [_attack_command()])
	_expect(_find_event(teammate_events, MatchEvent.Type.ACTION_ACCEPTED) == null,
		"Teammate attack was accepted")


## A target reached on a later active step drops the ball and produces one hit.
func test_knockdown_waits_for_contact_and_releases_ball() -> void:
	var target_position := Vector2(1.8, 0.0)
	var simulation := _create_match(target_position, "away", true)
	_expect(simulation.create_snapshot().ball.owner_player_id == TARGET_ID,
		"Test target did not start with the ball")
	var first_events := simulation.advance_fixed_step(STEP, [_attack_command()])
	_expect(_find_event(first_events, MatchEvent.Type.ACTION_ACCEPTED) != null,
		"Legal attack was rejected")
	_expect(_find_event(first_events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) == null,
		"Attack hit before the players entered contact range")
	var contact_events := simulation.advance_fixed_step(STEP, [])
	var impact := _find_event(contact_events, MatchEvent.Type.PLAYER_KNOCKED_DOWN)
	_expect(impact != null, "Attack did not knock target down on later contact")
	if impact != null:
		_expect(impact.subject_id == ATTACKER_ID
			and impact.target_player_id == TARGET_ID
			and impact.previous_owner_id == TARGET_ID
			and impact.new_owner_id.is_empty(),
			"Knockdown event lost participants or ball ownership transition")
	var snapshot := simulation.create_snapshot()
	_expect(snapshot.get_player(TARGET_ID).action_state
		== PlayerMatchState.ActionState.KNOCKED_DOWN,
		"Target did not enter knocked-down state")
	_expect(snapshot.get_player(ATTACKER_ID).action_state
		== PlayerMatchState.ActionState.ATTACKING,
		"Attacker stopped lunging at contact")
	_expect(snapshot.ball.owner_player_id.is_empty(),
		"Attack transferred the ball instead of dropping it")
	_expect(snapshot.ball.position_m.distance_to(target_position) < 0.0001,
		"Dropped ball did not stay at target contact")
	_expect(snapshot.get_player(TARGET_ID).position_m == target_position,
		"Knockback moved before the post-motion contact frame ended")
	var midpoint_events := simulation.advance_fixed_step(STEP, [])
	_expect(_find_event(midpoint_events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) == null,
		"One attack knocked down the target more than once")
	_expect(simulation.create_snapshot().get_player(TARGET_ID).position_m.distance_to(
		target_position + Vector2.RIGHT * 1.0
	) < 0.0001, "Target did not reach the knockback midpoint")
	simulation.advance_fixed_step(STEP, [])
	var final_position := simulation.create_snapshot().get_player(TARGET_ID).position_m
	_expect(final_position.distance_to(
		target_position + Vector2.RIGHT * _config.knockdown_knockback_distance_m
	) < 0.0001, "Knocked-down carrier was not pushed two metres")
	_expect(simulation.create_snapshot().ball.position_m == target_position,
		"Dropped ball moved with the knocked-back carrier")
	simulation.advance_fixed_step(STEP, [])
	_expect(simulation.create_snapshot().get_player(TARGET_ID).position_m == final_position,
		"Knockback continued after its configured duration")


## A CSV override changes the displacement without changing contact rules.
func test_configured_knockback_distance() -> void:
	var result := MatchConfigDataRepository.new().load_from_csv(
		"res://tests/fixtures/match_configs_short_knockback.csv"
	)
	_expect(result.is_success and result.configs.size() == 1,
		"Short knockback configuration did not load")
	if not result.is_success or result.configs.is_empty():
		return
	var target_position := Vector2(1.8, 0.0)
	var simulation := _create_match(
		target_position, "away", false, 5.0, result.configs[0]
	)
	simulation.advance_fixed_step(STEP, [_attack_command()])
	var events := simulation.advance_fixed_step(STEP, [])
	_expect(_find_event(events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) != null,
		"Short knockback test did not hit")
	simulation.advance_fixed_step(STEP, [])
	simulation.advance_fixed_step(STEP, [])
	_expect(simulation.create_snapshot().get_player(TARGET_ID).position_m.distance_to(
		target_position + Vector2.RIGHT * 0.75
	) < 0.0001, "Target did not use configured short knockback distance")


## A coincident contact uses the captured attack direction, including diagonal movement.
func test_overlap_uses_attack_direction_for_knockback() -> void:
	var direction := Vector2.ONE.normalized()
	var target_position := direction * 0.5
	var simulation := _create_match(target_position, "away")
	simulation.advance_fixed_step(STEP, [
		MatchAction.new(ATTACKER_ID, MatchAction.Type.MOVE, Vector2.ONE)
	])
	var events := simulation.advance_fixed_step(STEP, [_attack_command()])
	_expect(_find_event(events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) != null,
		"Overlapping target was not hit at attack start")
	simulation.advance_fixed_step(STEP, [])
	_expect(simulation.create_snapshot().get_player(TARGET_ID).position_m.distance_to(
		target_position + direction * _config.knockdown_knockback_distance_m
	) < 0.0001, "Overlapping target was not pushed along the attack direction")


## The lunge can reach a target that was beyond contact range at key press.
func test_lunge_reaches_target_started_outside_contact_range() -> void:
	var simulation := _create_match(Vector2(1.8, 0.0), "away")
	var start_events := simulation.advance_fixed_step(STEP, [_attack_command()])
	_expect(_find_event(start_events, MatchEvent.Type.ACTION_ACCEPTED) != null,
		"Attack outside initial contact radius did not start a lunge")
	_expect(_find_event(start_events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) == null,
		"Target was hit before entering range")
	var contact_events := simulation.advance_fixed_step(STEP, [])
	_expect(_find_event(contact_events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) != null,
		"Forward lunge did not reach the target on a later active step")


## A faster target can escape the lunge before contact and remain unharmed.
func test_target_outside_contact_range_is_not_hit() -> void:
	var simulation := _create_match(Vector2(1.8, 0.0), "away", false, 12.0)
	var first_events := simulation.advance_fixed_step(STEP, [_attack_command()])
	_expect(_find_event(first_events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) == null,
		"Target was hit before entering range")
	var escape := MatchAction.new(TARGET_ID, MatchAction.Type.MOVE, Vector2.RIGHT)
	var contact_events := simulation.advance_fixed_step(STEP, [escape])
	_expect(_find_event(contact_events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) == null,
		"Escaping target was knocked down")
	_expect(simulation.create_snapshot().get_player(TARGET_ID).action_state
		== PlayerMatchState.ActionState.IDLE,
		"Escaping target changed to down state")


## Contact on the first active step is valid even before animation windup ends.
func test_hit_at_window_start() -> void:
	var simulation := _create_match(Vector2(0.1, 0.0), "away")
	var events := simulation.advance_fixed_step(STEP, [_attack_command()])
	_expect(_find_event(events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) != null,
		"Contact at attack start did not hit before forward movement")


## Configured delayed starts ignore early contact but allow a later hit.
func test_delayed_window_ignores_early_contact() -> void:
	var result := MatchConfigDataRepository.new().load_from_csv(
		"res://tests/fixtures/match_configs_hit_window_delayed.csv"
	)
	_expect(result.is_success and result.configs.size() == 1,
		"Delayed hit-window configuration did not load")
	if not result.is_success or result.configs.is_empty():
		return
	var simulation := _create_match(
		Vector2(1.5, 0.0), "away", false, 5.0, result.configs[0]
	)
	var first_events := simulation.advance_fixed_step(STEP, [_attack_command()])
	_expect(_find_event(first_events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) == null,
		"Target was hit before the delayed window started")
	var second_events := simulation.advance_fixed_step(STEP, [])
	_expect(_find_event(second_events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) == null,
		"Target was hit on the second pre-window step")
	var third_events := simulation.advance_fixed_step(STEP, [])
	_expect(_find_event(third_events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) != null,
		"Target was not hit when the delayed window opened")


## The final eligible step can still hit a target met late in the lunge.
func test_hit_at_window_end() -> void:
	var simulation := _create_match(Vector2(4.8, 0.0), "away")
	var hit_count := 0
	for step_index in range(8):
		var actions: Array[MatchAction] = []
		if step_index == 0:
			actions.append(_attack_command())
		var events := simulation.advance_fixed_step(STEP, actions)
		for event in events:
			if event.event_type == MatchEvent.Type.PLAYER_KNOCKED_DOWN:
				hit_count += 1
		_expect(_find_event(events, MatchEvent.Type.KNOCKDOWN_MISSED) == null,
			"Lunge missed before its hit window ended")
	_expect(hit_count == 1, "Target at the hit-window endpoint was not hit once")


## A window configured through one second includes contact as landing begins.
func test_hit_at_full_action_endpoint() -> void:
	var result := MatchConfigDataRepository.new().load_from_csv(
		"res://tests/fixtures/match_configs_hit_window_full_action.csv"
	)
	_expect(result.is_success and result.configs.size() == 1,
		"Full-action hit-window configuration did not load")
	if not result.is_success or result.configs.is_empty():
		return
	var simulation := _create_match(
		Vector2(5.9, 0.0), "away", false, 5.0, result.configs[0]
	)
	var impact_count := 0
	for step_index in range(10):
		var actions: Array[MatchAction] = []
		if step_index == 0:
			actions.append(_attack_command())
		var events := simulation.advance_fixed_step(STEP, actions)
		for event in events:
			if event.event_type == MatchEvent.Type.PLAYER_KNOCKED_DOWN:
				impact_count += 1
	_expect(impact_count == 1,
		"Contact at the configured one-second endpoint did not hit exactly once")


## A target reached after expiry is ignored while the rest of the lunge completes.
func test_contact_after_window_is_ignored() -> void:
	var simulation := _create_match(Vector2(5.3, 0.0), "away")
	var miss_count := 0
	for step_index in range(10):
		var actions: Array[MatchAction] = []
		if step_index == 0:
			actions.append(_attack_command())
		var events := simulation.advance_fixed_step(STEP, actions)
		_expect(_find_event(events, MatchEvent.Type.PLAYER_KNOCKED_DOWN) == null,
			"Target was hit after the configured window")
		for event in events:
			if event.event_type == MatchEvent.Type.KNOCKDOWN_MISSED:
				miss_count += 1
	_expect(miss_count == 1, "Expired hit window did not miss exactly once")
	_expect(simulation.create_snapshot().get_player(TARGET_ID).action_state
		== PlayerMatchState.ActionState.IDLE,
		"Late contact knocked down the target")


## A second command cannot restart a down target's countdown.
func test_repeat_hit_does_not_restart_down_timer() -> void:
	var simulation := _create_match(Vector2(1.05, 0.0), "away")
	simulation.advance_fixed_step(STEP, [_attack_command()])
	simulation.advance_fixed_step(STEP, [])
	for step_index in range(11):
		simulation.advance_fixed_step(STEP, [])
	var before := simulation.create_snapshot().get_player(TARGET_ID).action_state_elapsed_seconds
	var events := simulation.advance_fixed_step(STEP, [_attack_command()])
	_expect(_find_event(events, MatchEvent.Type.ACTION_ACCEPTED) == null,
		"Attack was accepted against an already down target")
	_expect(simulation.create_snapshot().get_player(TARGET_ID).action_state_elapsed_seconds > before,
		"Repeated attack restarted the down timer")


## The entire lunge moves five metres in one second without later steering.
func test_lunge_uses_initial_direction_and_configured_distance() -> void:
	var state := PlayerMatchState.new("lunge", Vector2.ZERO)
	var machine := PlayerStateMachine.new(state)
	var direction := Vector2(1.0, 1.0).normalized()
	_expect(machine.set_movement_input(direction), "Initial direction was rejected")
	_expect(is_equal_approx(_config.knockdown_action_duration_seconds, 1.0),
		"Default lunge duration was not read from CSV")
	_expect(is_equal_approx(_config.knockdown_lunge_distance_m, 5.0),
		"Default lunge distance was not read from CSV")
	_expect(machine.try_start_knockdown(_config), "Knockdown lunge did not start")
	machine.advance(_config.knockdown_action_duration_seconds * 0.5)
	_expect(not machine.set_movement_input(Vector2.LEFT),
		"Active knockdown accepted new movement direction")
	_expect(state.position_m.distance_to(
		direction * _config.knockdown_lunge_distance_m * 0.5) < 0.0001,
		"Midpoint did not match configured lunge")
	machine.advance(_config.knockdown_action_duration_seconds * 0.5)
	_expect(state.position_m.distance_to(
		direction * _config.knockdown_lunge_distance_m) < 0.0001,
		"Attack did not finish at configured lunge distance")
	_expect(state.action_state == PlayerMatchState.ActionState.LANDING,
		"Attack did not enter landing after its lunge duration")
	_expect(is_equal_approx(_config.knockdown_jump_height_m, 0.5),
		"Default jump height was not read from CSV")


## Plays the landing interval, then holds the final crouch frame before restoring control.
func test_landing_animation_and_crouch_hold_block_actions() -> void:
	var state := PlayerMatchState.new("landing", Vector2.ZERO)
	var machine := PlayerStateMachine.new(state)
	_expect(is_equal_approx(_config.knockdown_landing_animation_seconds, 0.3),
		"Landing animation duration was not read from CSV")
	_expect(is_equal_approx(_config.knockdown_crouch_hold_seconds, 0.5),
		"Crouch hold duration was not read from CSV")
	_expect(machine.try_start_knockdown(_config), "Knockdown did not start")
	machine.advance(_config.knockdown_action_duration_seconds)
	var landing_position := state.position_m
	_expect(state.action_state == PlayerMatchState.ActionState.LANDING,
		"Landing did not begin after the lunge")
	_expect(not machine.set_movement_input(Vector2.LEFT),
		"Landing accepted movement")
	_expect(not machine.try_start_knockdown(_config),
		"Landing accepted another attack")
	machine.advance(_config.knockdown_landing_animation_seconds)
	_expect(state.action_state == PlayerMatchState.ActionState.LANDING,
		"Landing ended before the crouch hold")
	machine.advance(_config.knockdown_crouch_hold_seconds * 0.5)
	_expect(state.action_state == PlayerMatchState.ActionState.LANDING,
		"Crouch hold ended early")
	_expect(state.position_m == landing_position,
		"Player moved after finishing the lunge")
	machine.advance(_config.knockdown_crouch_hold_seconds * 0.5)
	_expect(state.action_state == PlayerMatchState.ActionState.IDLE,
		"Landing remained locked after the crouch hold")


## Down and get-up states reject commands, then restore normal movement.
func test_knockdown_blocks_actions_until_getting_up_finishes() -> void:
	var simulation := _create_match(Vector2(1.05, 0.0), "away")
	simulation.advance_fixed_step(STEP, [_attack_command()])
	simulation.advance_fixed_step(STEP, [])
	var down_position := simulation.create_snapshot().get_player(TARGET_ID).position_m
	var move_command := MatchAction.new(TARGET_ID, MatchAction.Type.MOVE, Vector2.RIGHT)
	var rejected := simulation.advance_fixed_step(STEP, [move_command])
	_expect(_find_event(rejected, MatchEvent.Type.ACTION_ACCEPTED) == null,
		"Knocked-down target accepted movement")
	_expect(simulation.create_snapshot().get_player(TARGET_ID).position_m == down_position,
		"Knocked-down target moved")
	for step_index in range(14):
		simulation.advance_fixed_step(STEP, [])
	_expect(simulation.create_snapshot().get_player(TARGET_ID).action_state
		== PlayerMatchState.ActionState.GETTING_UP,
		"Target did not enter get-up state")
	_expect(_find_event(simulation.advance_fixed_step(STEP, [move_command]),
		MatchEvent.Type.ACTION_ACCEPTED) == null,
		"Getting-up target accepted movement")
	var recovered_event: MatchEvent
	for step_index in range(5):
		var events := simulation.advance_fixed_step(STEP, [])
		recovered_event = _find_event(events, MatchEvent.Type.PLAYER_RECOVERED)
		if recovered_event != null:
			break
	_expect(recovered_event != null, "Recovery event was not emitted")
	_expect(simulation.create_snapshot().get_player(TARGET_ID).action_state
		== PlayerMatchState.ActionState.IDLE,
		"Get-up timer did not restore action eligibility")
	var resumed := simulation.advance_fixed_step(STEP, [move_command])
	_expect(_find_event(resumed, MatchEvent.Type.ACTION_ACCEPTED) != null,
		"Recovered target could not move")


## Manual reset removes the down timer and restores initial positions.
func test_reset_clears_knockdown() -> void:
	var simulation := _create_match(Vector2(1.05, 0.0), "away")
	simulation.advance_fixed_step(STEP, [_attack_command()])
	simulation.advance_fixed_step(STEP, [])
	simulation.advance_fixed_step(STEP, [
		MatchAction.new("", MatchAction.Type.RESET_ROUND)
	])
	_expect(simulation.create_snapshot().get_player(TARGET_ID).action_state
		== PlayerMatchState.ActionState.IDLE,
		"Reset retained knockdown state")
	_expect(simulation.create_snapshot().get_player(ATTACKER_ID).position_m == Vector2.ZERO,
		"Reset retained lunge displacement")


## Places a stationary target in front and optionally gives them the loose ball.
func _create_match(
	target_position_m: Vector2,
	target_team_id: String,
	target_has_ball: bool = false,
	target_speed_mps: float = 5.0,
	config_override: MatchConfigDefinition = null,
) -> MatchSimulation:
	var match_config: MatchConfigDefinition = config_override if config_override != null else _config
	var simulation := MatchSimulation.new(91, match_config, _field)
	_expect(simulation.register_player(ATTACKER_ID, Vector2.ZERO, 5.0, "home"),
		"Attacker registration failed")
	_expect(simulation.register_player(TARGET_ID, target_position_m, target_speed_mps, target_team_id),
		"Target registration failed")
	_expect(simulation.register_ball(target_position_m + Vector2(0.55, 0.0)),
		"Ball registration failed")
	_expect(simulation.start_match(), "Match failed to start")
	if target_has_ball:
		simulation.advance_fixed_step(STEP, [])
	return simulation


func _attack_command() -> MatchAction:
	return MatchAction.new(ATTACKER_ID, MatchAction.Type.ATTACK, Vector2.ZERO, TARGET_ID)


## Finds a structured fact without depending on unrelated step events.
func _find_event(events: Array[MatchEvent], event_type: int) -> MatchEvent:
	for event in events:
		if event.event_type == event_type:
			return event
	return null


## Collects independent facts before returning one process status.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Reports failures once at the end of the non-rendering script.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
