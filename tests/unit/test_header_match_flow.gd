## Verifies that head contests redirect a high pass without temporary possession.
extends SceneTree

var _failures: PackedStringArray = []
var _config: MatchConfigDefinition


## Runs shot, clearance, contest, reset, and invalid-command cases headlessly.
func _init() -> void:
	var repository := DataRepository.new()
	_check(repository.load_all(), "Match data must load")
	if not _failures.is_empty():
		_finish()
		return
	_config = repository.get_match_config_by_id("demo_match")
	_check(_config != null, "Match config must exist")
	_test_header_shot()
	_test_header_clear()
	_test_near_simultaneous_winner()
	_finish()


## Makes the first defender head toward goal and checks unowned shot motion.
func _test_header_shot() -> void:
	var match_state := _create_match(false)
	_check(not _has_event(match_state.advance_fixed_step(0.05, [
		MatchAction.new("defender", MatchAction.Type.HEADER_SHOT)]),
		MatchEvent.Type.ACTION_ACCEPTED), "Header command without a pass must fail")
	_start_high_pass(match_state)
	var events := _advance_until_header(match_state,
		MatchAction.new("defender", MatchAction.Type.HEADER_SHOT))
	_check(_has_event(events, MatchEvent.Type.HEADER_CONTEST_WON),
		"Single defender should win high contact")
	_check(_has_event(events, MatchEvent.Type.BALL_HEADED), "Head shot event must fire")
	var ball := match_state.create_snapshot().ball
	_check(ball.owner_player_id.is_empty(), "Head shot must never assign possession")
	_check(match_state._ball_runtime_system.state.flight_kind == BallMatchState.FlightKind.SHOT,
		"Head shot must become a shot trajectory")
	_check(ball.velocity_mps.x > 0.0 and ball.height_m > 0.0,
		"Head shot must travel toward opponent goal above ground")
	_check(match_state.create_snapshot().get_player("defender").action_state
		== PlayerMatchState.ActionState.HEADING,
		"Winning player must enter a timed header action")
	match_state.advance_fixed_step(
		_config.header_first_frame_seconds + _config.header_second_frame_seconds, [])
	_check(match_state.create_snapshot().get_player("defender").action_state
		== PlayerMatchState.ActionState.LANDING,
		"Header action must enter landing after its two frames")
	match_state.advance_fixed_step(PlayerStateMachine.HEADER_LANDING_DURATION_SECONDS, [])
	_check(match_state.create_snapshot().get_player("defender").action_state
		== PlayerMatchState.ActionState.IDLE,
		"Header landing must finish after its fixed duration")
	match_state.advance_fixed_step(0.05, [MatchAction.new("", MatchAction.Type.RESTART_TEST)])
	_check(match_state.create_snapshot().ball.owner_player_id.is_empty(),
		"Reset must clear head motion and possession")


## Redirects the same high pass along a chosen clearance vector.
func _test_header_clear() -> void:
	var match_state := _create_match(false)
	_start_high_pass(match_state)
	var events := _advance_until_header(match_state,
		MatchAction.new("defender", MatchAction.Type.HEADER_CLEAR, Vector2.UP))
	_check(_has_event(events, MatchEvent.Type.BALL_HEADED), "Header clearance must fire")
	var ball := match_state.create_snapshot().ball
	_check(ball.owner_player_id.is_empty() and ball.target_player_id.is_empty(),
		"Clearance must have no owner or pass target")
	_check(match_state._ball_runtime_system.state.flight_kind == BallMatchState.FlightKind.CLEARANCE,
		"Clearance must have its own flight kind, not a header pass")
	_check(ball.velocity_mps.y < 0.0, "Clearance must use its selected direction")


## Lets a slightly later but stronger opponent win the same contact window.
func _test_near_simultaneous_winner() -> void:
	var match_state := _create_match(true)
	_start_high_pass(match_state)
	var first := MatchAction.new("defender", MatchAction.Type.HEADER_CLEAR, Vector2.UP)
	var stronger := MatchAction.new("challenger", MatchAction.Type.HEADER_CLEAR, Vector2.DOWN)
	var events: Array[MatchEvent] = []
	for step in range(25):
		var actions: Array[MatchAction] = []
		if step == 0:
			actions.append_array([first, stronger])
		var step_events := match_state.advance_fixed_step(0.05, actions)
		if _has_event(step_events, MatchEvent.Type.BALL_HEADED):
			events = step_events
			break
	_check(_has_subject(events, MatchEvent.Type.HEADER_CONTEST_WON, "challenger"),
		"Strength and technique must decide near-simultaneous opponents")
	_check(match_state.create_snapshot().ball.velocity_mps.y > 0.0,
		"Winning opponent's clearance must control trajectory")


## Builds a directed lofted pass with a stationary player on its route.
func _create_match(with_challenger: bool) -> MatchSimulation:
	var match_state := MatchSimulation.new(47, _config)
	_check(match_state.register_team_attacking_goal("blue", Vector2(25.0, 0.0)),
		"Blue goal registration")
	_check(match_state.register_team_attacking_goal("red", Vector2(25.0, 0.0)),
		"Red goal registration")
	_check(match_state.register_player("passer", Vector2.ZERO, 5.0, "blue", 50),
		"Passer registration")
	_check(match_state.register_player("receiver", Vector2(10.0, 0.0), 5.0, "blue", 50),
		"Receiver registration")
	_check(match_state.register_player("defender", Vector2(3.8, 0.0), 5.0,
		"red", 50, 20, 20), "Defender registration")
	if with_challenger:
		_check(match_state.register_player("challenger", Vector2(3.9, 0.0), 5.0,
			"green", 50, 90, 90), "Challenger registration")
	_check(match_state.register_ball(Vector2(0.55, 0.0)), "Ball registration")
	_check(match_state.start_match(), "Match start")
	match_state.advance_fixed_step(0.05, [])
	return match_state


## Completes pass windup and stops before any defender reaches the high ball.
func _start_high_pass(match_state: MatchSimulation) -> void:
	match_state.advance_fixed_step(0.05, [
		MatchAction.new("passer", MatchAction.Type.PASS, Vector2.ZERO, "receiver")])
	for step in range(15):
		if match_state._ball_runtime_system.state.flight_kind == BallMatchState.FlightKind.PASS:
			return
		match_state.advance_fixed_step(0.05, [])
	_check(false, "Lofted pass should launch")


## Holds the requested header action through the pass and collects its contact step.
func _advance_until_header(match_state: MatchSimulation, action: MatchAction) -> Array[MatchEvent]:
	for step in range(25):
		var actions: Array[MatchAction] = []
		if step == 0:
			actions.append(action)
		var events := match_state.advance_fixed_step(0.05, actions)
		if _has_event(events, MatchEvent.Type.BALL_HEADED):
			return events
	_check(false, "Header should happen before pass ends")
	return []


## Checks a specific event kind in one fixed-step batch.
func _has_event(events: Array[MatchEvent], event_type: int) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false


## Checks which player won a contested high contact.
func _has_subject(events: Array[MatchEvent], event_type: int, subject_id: String) -> bool:
	for event in events:
		if event.event_type == event_type and event.subject_id == subject_id:
			return true
	return false


## Reports each invariant and quits with a nonzero status on failure.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Ends the non-rendering unit test with concise diagnostics.
func _finish() -> void:
	if _failures.is_empty():
		print("PASS: header match flow")
	else:
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)
