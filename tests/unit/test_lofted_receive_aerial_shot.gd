## Verifies the teammate anticipates a high pass, receives airborne, then shoots.
extends SceneTree

var _failures: PackedStringArray = []


## Replays the shared bootstrap with fixed steps and checks the observable event order.
func _init() -> void:
	var bootstrap := GameBootstrap.new()
	bootstrap.demo_mode = GameBootstrap.DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST
	bootstrap.random_seed = 47
	bootstrap._ready()
	_check(not bootstrap.demo_teammate_id.is_empty(), "Demo teammate must be registered")
	_check(bootstrap._match_simulation.create_snapshot().ball.owner_player_id
		== bootstrap.demo_player_id, "Passer must start with the ball")
	bootstrap.queue_action(MatchAction.new(bootstrap.demo_player_id,
		MatchAction.Type.PASS, Vector2.ZERO, bootstrap.demo_teammate_id))
	var saw_high_pass := false
	var saw_reception := false
	var saw_jump := false
	var jumped_before_reception := false
	var reception_was_airborne := false
	var received_above_ground := false
	var caught_on_ground_first := false
	var saw_shot := false
	var shot_was_airborne := false
	var shot_position_m := Vector2.ZERO
	var shot_velocity_mps := Vector2.ZERO
	var shot_motion_state := BallMatchState.MotionState.LOOSE
	for step in range(360):
		bootstrap._process(bootstrap.fixed_delta_seconds * 0.5)
		var snapshot := bootstrap._match_simulation.create_snapshot()
		if snapshot.ball.height_m > 0.2 and (
			bootstrap._match_simulation._ball_runtime_system.state.flight_kind
			== BallMatchState.FlightKind.PASS
		):
			saw_high_pass = true
		var teammate := snapshot.get_player(bootstrap.demo_teammate_id)
		if teammate != null and teammate.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE:
			saw_jump = true
			if snapshot.ball.motion_state == BallMatchState.MotionState.IN_FLIGHT and (
				snapshot.ball.target_player_id == bootstrap.demo_teammate_id
			):
				jumped_before_reception = true
		if snapshot.ball.owner_player_id == bootstrap.demo_teammate_id and (
			teammate != null and teammate.jump_phase == PlayerMatchState.JumpPhase.NONE
		):
			caught_on_ground_first = true
		for event in bootstrap.get_event_history():
			if event.event_type == MatchEvent.Type.BALL_PASS_RECEIVED and (
				event.subject_id == bootstrap.demo_teammate_id
			):
				saw_reception = true
				reception_was_airborne = (
					teammate != null
					and teammate.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE
				)
				received_above_ground = snapshot.ball.height_m > 0.2
			if event.event_type == MatchEvent.Type.BALL_SHOT and (
				event.subject_id == bootstrap.demo_teammate_id
			):
				saw_shot = true
				shot_position_m = snapshot.ball.position_m
				shot_velocity_mps = snapshot.ball.velocity_mps
				shot_motion_state = snapshot.ball.motion_state
				shot_was_airborne = (
					teammate != null
					and teammate.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE
					and snapshot.ball.height_m > 0.0
				)
		if saw_shot:
			break
	_check(saw_high_pass, "Pass must travel above the normal receive height")
	_check(saw_reception, "Teammate must receive the descending pass")
	_check(saw_jump and jumped_before_reception,
		"Teammate must jump before receiving the pass")
	_check(reception_was_airborne and received_above_ground,
		"Teammate must gain possession while airborne above normal catch height")
	_check(not caught_on_ground_first, "Teammate must not catch the pass on the ground first")
	_check(saw_shot, "Teammate must shoot while airborne")
	_check(shot_was_airborne, "Shot must release from a nonzero airborne height")
	_check(shot_motion_state == BallMatchState.MotionState.IN_FLIGHT,
		"Shot event must leave the ball in flight")
	_check(shot_velocity_mps.x > 0.0, "Shot must launch toward the opponent goal")
	_check(bootstrap._lofted_receiver_jump_requested,
		"Jump request must remain locked while the shooter is airborne")
	for step in range(12):
		bootstrap._process(bootstrap.fixed_delta_seconds * 0.5)
	_check(bootstrap._match_simulation.create_snapshot().ball.position_m.x
		> shot_position_m.x + 0.5, "Shot ball must travel independently after release")
	for event in bootstrap.get_event_history():
		_check(event.event_type != MatchEvent.Type.BALL_HEADED,
			"Replacement demo must not trigger a header")
	_test_request_clears_after_landing(bootstrap)
	_test_repeat_after_automatic_reset(bootstrap)
	bootstrap.queue_action(MatchAction.new("", MatchAction.Type.RESTART_TEST))
	bootstrap._process(bootstrap.fixed_delta_seconds)
	bootstrap._process(bootstrap.fixed_delta_seconds)
	_check_repeated_aerial_pass(bootstrap, "Manual restart")
	bootstrap.free()
	if _failures.is_empty():
		print("PASS: lofted receive aerial shot")
	else:
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


## Requires landing itself to unlock the next jump before any round reset occurs.
func _test_request_clears_after_landing(bootstrap: GameBootstrap) -> void:
	var landed := false
	for step in range(120):
		var receiver := bootstrap._match_simulation.create_snapshot().get_player(
			bootstrap.demo_teammate_id)
		if receiver.jump_phase == PlayerMatchState.JumpPhase.NONE:
			landed = true
			break
		_check(bootstrap._lofted_receiver_jump_requested,
			"Jump request must stay locked through the landing phase")
		bootstrap._process(bootstrap.fixed_delta_seconds * 0.5)
	_check(landed, "Receiver must finish landing after the aerial shot")
	_check(not bootstrap._lofted_receiver_jump_requested,
		"Landing must clear the jump request before the next pass or round reset")
	for event in bootstrap.get_event_history():
		_check(event.event_type != MatchEvent.Type.RESET_COMPLETED,
			"Landing lifecycle must be verified before automatic reset")


## Waits for normal goal/out settlement before repeating the same playable action.
func _test_repeat_after_automatic_reset(bootstrap: GameBootstrap) -> void:
	var did_reset := false
	for step in range(600):
		bootstrap._process(bootstrap.fixed_delta_seconds)
		for event in bootstrap.get_event_history():
			if event.event_type == MatchEvent.Type.RESET_COMPLETED and event.reason in [
				MatchEvent.ResetReason.GOAL, MatchEvent.ResetReason.OUT,
			]:
				did_reset = true
		if did_reset:
			break
	_check(did_reset, "Shot must finish automatic settlement before the next pass")
	bootstrap._process(bootstrap.fixed_delta_seconds)
	_check_repeated_aerial_pass(bootstrap, "Automatic reset")


## Observes only new events so an earlier successful jump cannot satisfy a later round.
func _check_repeated_aerial_pass(bootstrap: GameBootstrap, context: String) -> void:
	_check(bootstrap._match_simulation.create_snapshot().ball.owner_player_id
		== bootstrap.demo_player_id, context + ": passer must regain possession")
	var event_cursor := bootstrap.get_event_history().size()
	bootstrap.queue_action(MatchAction.new(bootstrap.demo_player_id,
		MatchAction.Type.PASS, Vector2.ZERO, bootstrap.demo_teammate_id))
	var jumped_before_catch := false
	var caught_airborne := false
	var shot_airborne := false
	for step in range(360):
		bootstrap._process(bootstrap.fixed_delta_seconds * 0.5)
		var snapshot := bootstrap._match_simulation.create_snapshot()
		var receiver := snapshot.get_player(bootstrap.demo_teammate_id)
		if receiver.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE and (
			snapshot.ball.target_player_id == bootstrap.demo_teammate_id
		):
			jumped_before_catch = true
		var events := bootstrap.get_event_history()
		var saw_shot := false
		for index in range(event_cursor, events.size()):
			var event := events[index]
			if event.subject_id != bootstrap.demo_teammate_id:
				continue
			if event.event_type == MatchEvent.Type.BALL_PASS_RECEIVED:
				caught_airborne = receiver.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE
			if event.event_type == MatchEvent.Type.BALL_SHOT:
				saw_shot = true
				shot_airborne = (
					receiver.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE
					and snapshot.ball.height_m > 0.2
				)
		event_cursor = events.size()
		if saw_shot:
			break
	_check(jumped_before_catch, context + ": receiver must jump before the next catch")
	_check(caught_airborne, context + ": next pass must be caught airborne")
	_check(shot_airborne, context + ": next shot must release while airborne")


## Collects failed event and state assertions without depending on rendered frames.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
