extends SceneTree

const FIXED_DELTA := 0.1

var _failures: PackedStringArray = []


func _init() -> void:
	test_new_match_when_started_emits_started_event()
	test_partial_frame_when_advanced_does_not_step_simulation()
	test_accumulated_time_when_reaching_fixed_delta_advances_once()
	test_large_frame_when_advanced_runs_multiple_fixed_steps()
	test_queued_action_before_fixed_step_is_consumed_once()
	test_paused_match_when_frames_advance_does_not_change_state()
	test_action_received_while_paused_is_discarded()
	test_ready_match_when_finished_is_rejected()
	test_finished_match_when_frames_advance_does_not_change_state()
	test_same_seed_and_frames_when_replayed_produce_same_snapshot()

	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func test_new_match_when_started_emits_started_event() -> void:
	var runtime := _create_started_runtime(11)
	var frame: MatchFrameResult = runtime.loop.advance_frame(0.0, _no_actions())
	_expect(frame.snapshot.phase == MatchState.Phase.RUNNING, "Expected running phase")
	_expect(_has_event(frame.events, MatchEvent.Type.MATCH_STARTED), "Expected start event")


func test_partial_frame_when_advanced_does_not_step_simulation() -> void:
	var runtime := _create_started_runtime(12)
	runtime.loop.advance_frame(0.0, _no_actions())
	var frame: MatchFrameResult = runtime.loop.advance_frame(FIXED_DELTA * 0.5, _no_actions())
	_expect(frame.simulation_steps == 0, "Expected no partial fixed step")
	_expect(frame.snapshot.simulation_step == 0, "Expected state to remain at step zero")
	_expect(is_equal_approx(frame.interpolation_alpha, 0.5), "Expected half interpolation")


func test_accumulated_time_when_reaching_fixed_delta_advances_once() -> void:
	var runtime := _create_started_runtime(13)
	runtime.loop.advance_frame(FIXED_DELTA * 0.4, _no_actions())
	var frame: MatchFrameResult = runtime.loop.advance_frame(FIXED_DELTA * 0.6, _no_actions())
	_expect(frame.simulation_steps == 1, "Expected one accumulated fixed step")
	_expect(frame.snapshot.simulation_step == 1, "Expected simulation step one")
	_expect(is_equal_approx(frame.snapshot.elapsed_seconds, FIXED_DELTA), "Expected fixed time")


func test_large_frame_when_advanced_runs_multiple_fixed_steps() -> void:
	var runtime := _create_started_runtime(14)
	var frame: MatchFrameResult = runtime.loop.advance_frame(FIXED_DELTA * 3.5, _no_actions())
	_expect(frame.simulation_steps == 3, "Expected three fixed steps")
	_expect(frame.snapshot.simulation_step == 3, "Expected state step three")
	_expect(is_equal_approx(frame.interpolation_alpha, 0.5), "Expected remaining half step")


func test_queued_action_before_fixed_step_is_consumed_once() -> void:
	var runtime := _create_started_runtime(15)
	var action := MatchAction.new("swift_forward", MatchAction.Type.MOVE, Vector2.RIGHT)
	var partial_frame: MatchFrameResult = runtime.loop.advance_frame(
		FIXED_DELTA * 0.5,
		_single_action(action),
	)
	_expect(
		not _has_event(partial_frame.events, MatchEvent.Type.ACTION_ACCEPTED),
		"Expected action to wait for a fixed step",
	)
	var fixed_frame: MatchFrameResult = runtime.loop.advance_frame(
		FIXED_DELTA * 0.5,
		_no_actions(),
	)
	_expect(
		_count_events(fixed_frame.events, MatchEvent.Type.ACTION_ACCEPTED) == 1,
		"Expected queued action to be consumed once",
	)
	_expect(
		_find_event_subject(fixed_frame.events, MatchEvent.Type.ACTION_ACCEPTED)
		== "swift_forward",
		"Expected action event subject",
	)


func test_paused_match_when_frames_advance_does_not_change_state() -> void:
	var runtime := _create_started_runtime(16)
	runtime.loop.advance_frame(FIXED_DELTA, _no_actions())
	_expect(runtime.simulation.pause_match(), "Expected running match to pause")
	var paused_frame: MatchFrameResult = runtime.loop.advance_frame(
		FIXED_DELTA * 4.0,
		_no_actions(),
	)
	_expect(paused_frame.snapshot.phase == MatchState.Phase.PAUSED, "Expected paused phase")
	_expect(paused_frame.snapshot.simulation_step == 1, "Expected paused state not to advance")
	_expect(_has_event(paused_frame.events, MatchEvent.Type.MATCH_PAUSED), "Expected pause event")


func test_action_received_while_paused_is_discarded() -> void:
	var runtime := _create_started_runtime(18)
	_expect(runtime.simulation.pause_match(), "Expected running match to pause")
	var action := MatchAction.new("swift_forward", MatchAction.Type.SHOOT)
	runtime.loop.advance_frame(0.0, _single_action(action))
	_expect(runtime.simulation.resume_match(), "Expected paused match to resume")
	var resumed_frame: MatchFrameResult = runtime.loop.advance_frame(FIXED_DELTA, _no_actions())
	_expect(
		not _has_event(resumed_frame.events, MatchEvent.Type.ACTION_ACCEPTED),
		"Expected action received while paused to be discarded",
	)


func test_ready_match_when_finished_is_rejected() -> void:
	var simulation := MatchSimulation.new(19)
	_expect(not simulation.finish_match(), "Expected ready match not to finish")
	_expect(
		simulation.create_snapshot().phase == MatchState.Phase.READY,
		"Expected rejected finish to preserve ready phase",
	)


func test_finished_match_when_frames_advance_does_not_change_state() -> void:
	var runtime := _create_started_runtime(20)
	_expect(runtime.simulation.finish_match(), "Expected match to finish")
	var frame: MatchFrameResult = runtime.loop.advance_frame(FIXED_DELTA * 2.0, _no_actions())
	_expect(frame.snapshot.phase == MatchState.Phase.FINISHED, "Expected finished phase")
	_expect(frame.snapshot.simulation_step == 0, "Expected finished state not to advance")
	_expect(_has_event(frame.events, MatchEvent.Type.MATCH_FINISHED), "Expected finish event")


func test_same_seed_and_frames_when_replayed_produce_same_snapshot() -> void:
	var first_runtime := _create_started_runtime(99)
	var second_runtime := _create_started_runtime(99)
	var frame_deltas: Array[float] = [0.03, 0.08, 0.21, 0.04]
	var first_frame: MatchFrameResult
	var second_frame: MatchFrameResult
	for frame_delta in frame_deltas:
		first_frame = first_runtime.loop.advance_frame(frame_delta, _no_actions())
		second_frame = second_runtime.loop.advance_frame(frame_delta, _no_actions())
	_expect(
		first_frame.snapshot.simulation_step == second_frame.snapshot.simulation_step,
		"Expected deterministic simulation step",
	)
	_expect(
		is_equal_approx(
			first_frame.snapshot.elapsed_seconds,
			second_frame.snapshot.elapsed_seconds,
		),
		"Expected deterministic elapsed time",
	)
	_expect(
		first_frame.snapshot.random_seed == second_frame.snapshot.random_seed,
		"Expected deterministic seed",
	)


func _create_started_runtime(random_seed: int) -> Dictionary:
	var simulation := MatchSimulation.new(random_seed)
	_expect(
		simulation.register_player("swift_forward", Vector2.ZERO),
		"Expected test player registration",
	)
	_expect(simulation.start_match(), "Expected a new simulation to start")
	var game_loop := GameLoop.new(simulation, FIXED_DELTA, 1.0, 8)
	return {
		"simulation": simulation,
		"loop": game_loop,
	}


func _no_actions() -> Array[MatchAction]:
	return []


func _single_action(action: MatchAction) -> Array[MatchAction]:
	return [action]


func _has_event(events: Array[MatchEvent], event_type: int) -> bool:
	return _count_events(events, event_type) > 0


func _count_events(events: Array[MatchEvent], event_type: int) -> int:
	var event_count := 0
	for event in events:
		if event.event_type == event_type:
			event_count += 1
	return event_count


func _find_event_subject(events: Array[MatchEvent], event_type: int) -> String:
	for event in events:
		if event.event_type == event_type:
			return event.subject_id
	return ""


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
