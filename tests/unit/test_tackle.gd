## Verifies deterministic tackle eligibility, possession transfer, and chase AI.
extends SceneTree

const STEP := 0.1
const CARRIER_ID := "carrier"
const DEFENDER_ID := "defender"

var _field: FieldDefinition
var _config: MatchConfigDefinition
var _failures: PackedStringArray = []


## Loads real match data and executes isolated tackle scenarios.
func _init() -> void:
	var repository := DataRepository.new()
	_expect(repository.load_all(), "Expected match configuration")
	if not _failures.is_empty():
		_finish()
		return
	_field = repository.get_field_by_id("demo_field")
	_config = repository.get_match_config_by_id("demo_match")
	test_illegal_tackles_leave_possession_unchanged()
	test_legal_tackle_transfers_ball_at_contact_frame()
	test_tackle_lunge_keeps_initial_direction_and_distance()
	test_tackled_player_stays_stunned_then_resumes_input()
	test_round_reset_clears_hit_stun()
	test_same_step_contest_has_one_owner()
	test_chase_ai_uses_commands_to_steal_ball()
	_finish()


## Distance, facing, and team checks reject commands without changing the carrier.
func test_illegal_tackles_leave_possession_unchanged() -> void:
	var simulation := _create_match(Vector2(4.0, 0.0))
	var far_events := simulation.advance_fixed_step(STEP, [
		MatchAction.new(DEFENDER_ID, MatchAction.Type.TACKLE, Vector2.ZERO, CARRIER_ID)
	])
	_expect(_find_event(far_events, MatchEvent.Type.ACTION_ACCEPTED) == null,
		"Out-of-range tackle was accepted")
	_expect(simulation.create_snapshot().ball.owner_player_id == CARRIER_ID,
		"Out-of-range tackle moved possession")
	var front_simulation := _create_match(Vector2(1.0, 0.0))
	var back_events := front_simulation.advance_fixed_step(STEP, [
		MatchAction.new(DEFENDER_ID, MatchAction.Type.TACKLE, Vector2.ZERO, CARRIER_ID)
	])
	_expect(_find_event(back_events, MatchEvent.Type.ACTION_ACCEPTED) == null,
		"Back-facing tackle was accepted")
	_expect(front_simulation.create_snapshot().ball.owner_player_id == CARRIER_ID,
		"Back-facing tackle moved possession")
	var empty_ball_simulation := _create_match(Vector2(-1.0, 0.0), false, false, false)
	var empty_events := empty_ball_simulation.advance_fixed_step(STEP, [
		MatchAction.new(DEFENDER_ID, MatchAction.Type.TACKLE, Vector2.ZERO, CARRIER_ID)
	])
	_expect(_find_event(empty_events, MatchEvent.Type.ACTION_ACCEPTED) == null,
		"Tackle was accepted without a carrier")
	var teammate_simulation := _create_match(Vector2(-1.0, 0.0), true)
	var teammate_events := teammate_simulation.advance_fixed_step(STEP, [
		MatchAction.new(DEFENDER_ID, MatchAction.Type.TACKLE, Vector2.ZERO, CARRIER_ID)
	])
	_expect(_find_event(teammate_events, MatchEvent.Type.ACTION_ACCEPTED) == null,
		"Teammate tackle was accepted")
	_expect(teammate_simulation.create_snapshot().ball.owner_player_id == CARRIER_ID,
		"Teammate tackle moved possession")


## A legal command waits for its animation contact before the ball changes owner.
func test_legal_tackle_transfers_ball_at_contact_frame() -> void:
	var simulation := _create_match(Vector2(-1.0, 0.0))
	var command_events := simulation.advance_fixed_step(STEP, [
		MatchAction.new(DEFENDER_ID, MatchAction.Type.TACKLE, Vector2.ZERO, CARRIER_ID)
	])
	_expect(_find_event(command_events, MatchEvent.Type.ACTION_ACCEPTED) != null,
		"Legal tackle command was rejected")
	_expect(_find_event(command_events, MatchEvent.Type.TACKLE_SUCCEEDED) == null,
		"Tackle resolved before its windup")
	_expect(simulation.create_snapshot().ball.owner_player_id == CARRIER_ID,
		"Windup transferred the ball early")
	var contact_events := simulation.advance_fixed_step(STEP, [])
	var success := _find_event(contact_events, MatchEvent.Type.TACKLE_SUCCEEDED)
	_expect(success != null, "Tackle did not resolve at contact")
	if success != null:
		_expect(success.subject_id == DEFENDER_ID
			and success.target_player_id == CARRIER_ID
			and success.previous_owner_id == CARRIER_ID
			and success.new_owner_id == DEFENDER_ID,
			"Tackle event lost its actor, target, or ownership transition")
	var snapshot := simulation.create_snapshot()
	_expect(snapshot.ball.owner_player_id == DEFENDER_ID,
		"Successful tackle did not transfer ball ownership")
	_expect(_find_event(contact_events, MatchEvent.Type.BALL_POSSESSION_GAINED) != null,
		"Tackle omitted the ball possession event")
	_expect(snapshot.get_player(CARRIER_ID).possession_state
		== PlayerMatchState.PossessionState.NO_BALL,
		"Old owner retained possession")
	_expect(snapshot.get_player(CARRIER_ID).action_state
		== PlayerMatchState.ActionState.STAGGERED,
		"Tackled carrier did not enter hit stun")
	_expect(snapshot.get_player(DEFENDER_ID).possession_state
		== PlayerMatchState.PossessionState.POSSESSING,
		"Tackler was not marked as ball owner")
	_expect(snapshot.get_player(DEFENDER_ID).action_state
		== PlayerMatchState.ActionState.TACKLING,
		"Successful contact ended the configured tackle action early")
	var repeated_events := simulation.advance_fixed_step(STEP, [
		MatchAction.new(DEFENDER_ID, MatchAction.Type.TACKLE, Vector2.ZERO, CARRIER_ID)
	])
	_expect(_find_event(repeated_events, MatchEvent.Type.TACKLE_SUCCEEDED) == null,
		"Tackle succeeded twice on the same possession")


## Tackle motion is capped at the configured distance and ignores later input changes.
func test_tackle_lunge_keeps_initial_direction_and_distance() -> void:
	var state := PlayerMatchState.new("lunge", Vector2.ZERO)
	var machine := PlayerStateMachine.new(state)
	var starting_direction := Vector2(1.0, 1.0).normalized()
	_expect(machine.set_movement_input(starting_direction), "Initial direction was rejected")
	_expect(machine.try_start_tackle(_config), "Lunge did not start")
	machine.advance(0.25)
	_expect(state.action_state == PlayerMatchState.ActionState.TACKLING,
		"Tackle ended before the configured duration")
	_expect(state.position_m.distance_to(starting_direction * 0.25) < 0.0001,
		"Tackle did not move along its initial direction")
	_expect(not machine.set_movement_input(Vector2.LEFT),
		"New input changed an active tackle")
	machine.advance(0.75)
	_expect(state.action_state == PlayerMatchState.ActionState.IDLE,
		"Tackle did not finish after the configured second")
	_expect(state.position_m.distance_to(starting_direction) < 0.0001,
		"Tackle exceeded or missed its configured one-metre distance")
	machine.advance(0.25)
	_expect(state.position_m.distance_to(starting_direction) < 0.0001,
		"Tackle continued moving after its action ended")
	var facing_state := PlayerMatchState.new("facing", Vector2.ZERO)
	var facing_machine := PlayerStateMachine.new(facing_state)
	_expect(facing_machine.try_start_tackle(_config), "Standing tackle did not start")
	facing_machine.advance(1.0)
	_expect(facing_state.position_m.distance_to(Vector2.RIGHT) < 0.0001,
		"Standing tackle did not use its initial facing direction")


## A tackled carrier stays still for configured time and then uses their latest input.
func test_tackled_player_stays_stunned_then_resumes_input() -> void:
	var simulation := _create_match(Vector2(-1.0, 0.0))
	simulation.advance_fixed_step(STEP, [
		MatchAction.new(DEFENDER_ID, MatchAction.Type.TACKLE, Vector2.ZERO, CARRIER_ID)
	])
	simulation.advance_fixed_step(STEP, [])
	var stunned_position := simulation.create_snapshot().get_player(CARRIER_ID).position_m
	var move_right := MatchAction.new(CARRIER_ID, MatchAction.Type.MOVE, Vector2.RIGHT)
	for step_index in range(3):
		simulation.advance_fixed_step(0.25, [move_right])
		var snapshot := simulation.create_snapshot().get_player(CARRIER_ID)
		_expect(snapshot.action_state == PlayerMatchState.ActionState.STAGGERED,
			"Hit stun ended before the configured second")
		_expect(snapshot.position_m == stunned_position,
			"Tackled carrier moved during hit stun")
	simulation.advance_fixed_step(0.25, [move_right])
	var recovered := simulation.create_snapshot().get_player(CARRIER_ID)
	_expect(recovered.action_state == PlayerMatchState.ActionState.IDLE,
		"Hit stun did not end after the configured second")
	_expect(recovered.position_m == stunned_position,
		"Tackled carrier moved in the recovery transition step")
	simulation.advance_fixed_step(STEP, [])
	_expect(simulation.create_snapshot().get_player(CARRIER_ID).position_m.x > stunned_position.x,
		"Held movement input did not resume after hit stun")


## Round reset clears temporary hit stun and restores an actionable player.
func test_round_reset_clears_hit_stun() -> void:
	var simulation := _create_match(Vector2(-1.0, 0.0))
	simulation.advance_fixed_step(STEP, [
		MatchAction.new(DEFENDER_ID, MatchAction.Type.TACKLE, Vector2.ZERO, CARRIER_ID)
	])
	simulation.advance_fixed_step(STEP, [])
	_expect(simulation.create_snapshot().get_player(CARRIER_ID).action_state
		== PlayerMatchState.ActionState.STAGGERED,
		"Reset precondition did not enter hit stun")
	simulation.advance_fixed_step(STEP, [
		MatchAction.new("", MatchAction.Type.RESET_ROUND)
	])
	_expect(simulation.create_snapshot().get_player(CARRIER_ID).action_state
		== PlayerMatchState.ActionState.IDLE,
		"Round reset retained the previous hit stun")


## Two simultaneous legal tacklers cannot both receive one ball.
func test_same_step_contest_has_one_owner() -> void:
	var simulation := _create_match(Vector2(-1.0, 0.0), false, true)
	var commands: Array[MatchAction] = [
		MatchAction.new(DEFENDER_ID, MatchAction.Type.TACKLE, Vector2.ZERO, CARRIER_ID),
		MatchAction.new("other", MatchAction.Type.TACKLE, Vector2.ZERO, CARRIER_ID),
	]
	simulation.advance_fixed_step(STEP, commands)
	var events := simulation.advance_fixed_step(STEP, [])
	var successes := 0
	for event in events:
		if event.event_type == MatchEvent.Type.TACKLE_SUCCEEDED:
			successes += 1
	_expect(successes == 1, "One ball was awarded by more than one tackle")


## The opponent chases the carrier and submits the same tackle command as a player.
func test_chase_ai_uses_commands_to_steal_ball() -> void:
	var simulation := _create_match(Vector2(6.0, 0.0))
	var ai := TackleChaseAI.new(
		DEFENDER_ID, CARRIER_ID, _config, Vector2(-_field.length_m * 0.5, 0.0)
	)
	var loop := GameLoop.new(simulation, STEP, 0.25, 8, ai)
	var success: MatchEvent
	for step_index in range(80):
		var frame := loop.advance_frame(STEP, [])
		success = _find_event(frame.events, MatchEvent.Type.TACKLE_SUCCEEDED)
		if success != null:
			break
	_expect(success != null, "Chase AI never reached and tackled the carrier")
	_expect(simulation.create_snapshot().ball.owner_player_id == DEFENDER_ID,
		"AI tackle did not give the ball to the opponent")
	var contact_position := simulation.create_snapshot().get_player(DEFENDER_ID).position_m
	loop.advance_frame(STEP, [])
	var lunge_snapshot := simulation.create_snapshot()
	_expect(lunge_snapshot.get_player(DEFENDER_ID).position_m.x < contact_position.x,
		"AI stopped moving along its initial direction during the tackle")
	_expect(lunge_snapshot.ball.owner_player_id == DEFENDER_ID,
		"AI lost possession during the tackle lunge")
	for step_index in range(20):
		if simulation.create_snapshot().get_player(DEFENDER_ID).action_state == PlayerMatchState.ActionState.IDLE:
			break
		loop.advance_frame(STEP, [])
	var tackle_end_position := simulation.create_snapshot().get_player(DEFENDER_ID).position_m
	_expect(simulation.create_snapshot().get_player(DEFENDER_ID).action_state
		== PlayerMatchState.ActionState.IDLE,
		"AI tackle did not finish after one second")
	loop.advance_frame(STEP, [])
	var dribble_snapshot := simulation.create_snapshot()
	_expect(dribble_snapshot.get_player(DEFENDER_ID).position_m.x < tackle_end_position.x,
		"AI did not turn toward the opponent goal after tackling")
	_expect(dribble_snapshot.ball.owner_player_id == DEFENDER_ID,
		"AI lost possession while dribbling away from the tackle")


## Registers a carrier at the ball and one defender with configurable geometry.
func _create_match(
	defender_position_m: Vector2, same_team: bool = false,
	extra_defender: bool = false, ball_near_carrier: bool = true
) -> MatchSimulation:
	var simulation := MatchSimulation.new(44, _config, _field)
	_expect(simulation.register_player(CARRIER_ID, Vector2.ZERO, 5.0, "home"),
		"Carrier registration failed")
	var defender_team := "home" if same_team else "away"
	_expect(simulation.register_player(
		DEFENDER_ID, defender_position_m, 5.0, defender_team
	), "Defender registration failed")
	if extra_defender:
		_expect(simulation.register_player(
			"other", Vector2(-1.0, 0.0), 5.0, "other_team"
		), "Expected second defender registration")
	_expect(simulation.register_ball(Vector2(0.5, 0.0)), "Ball registration failed")
	_expect(simulation.start_match(), "Match did not start")
	if ball_near_carrier:
		simulation.advance_fixed_step(STEP, [])
		_expect(simulation.create_snapshot().ball.owner_player_id == CARRIER_ID,
			"Carrier did not acquire the initial ball")
	return simulation


## Finds an event by type without depending on unrelated clock events.
func _find_event(events: Array[MatchEvent], event_type: int) -> MatchEvent:
	for event in events:
		if event.event_type == event_type:
			return event
	return null


## Records each failed business fact and continues the remaining cases.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Exits with an error when any tackle invariant fails.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
