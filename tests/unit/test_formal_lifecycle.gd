## Verifies official lifecycle/terminal exclusivity and global permissions without a scene tree dependency.
extends SceneTree
const Fixture = preload("res://tests/support/formal_match_fixture.gd")
var _failures: PackedStringArray = []

## Covers READY, pause/resume, cancellation, normal terminal outcomes and all policy combinations.
func _init() -> void:
	var fixture := Fixture.new()
	var simulation := fixture.create(0.05)
	_check(simulation != null, "formal fixture assembled")
	if simulation == null:
		_finish()
		return
	_check(not simulation.pause_match() and not simulation.resume_match() and not simulation.finish_match(), "invalid READY controls rejected")
	simulation.advance_fixed_step(1.0, [])
	_check(simulation.create_snapshot().elapsed_seconds == 0.0 and simulation.get_event_history().is_empty(), "READY never runs clock or emits invented result")
	_check(simulation.start_match() and not simulation.start_match(), "start exactly once")
	simulation.advance_fixed_step(0.01, [MatchAction.new("swift_forward", MatchAction.Type.MOVE, Vector2.RIGHT)])
	var before := simulation.create_snapshot()
	var seed_state := simulation._rng.state
	_check(simulation.pause_match() and not simulation.pause_match(), "pause exactly once")
	simulation.advance_fixed_step(1.0, [MatchAction.new("swift_forward", MatchAction.Type.SHOOT)])
	var paused := simulation.create_snapshot()
	_check(paused.elapsed_seconds == before.elapsed_seconds and paused.simulation_step == before.simulation_step and paused.get_player("swift_forward").position_m == before.get_player("swift_forward").position_m and simulation._rng.state == seed_state, "pause freezes clock, positions, random source and step")
	_check(paused.get_player("swift_forward").movement_input == Vector2.ZERO, "pause neutralizes persistent move")
	_check(simulation.resume_match() and not simulation.resume_match(), "resume exactly once")
	var events := simulation.advance_fixed_step(1.0, [])
	var ended := simulation.create_snapshot()
	_check(ended.phase == MatchState.Phase.FINISHED and ended.elapsed_seconds == 0.05 and ended.remaining_seconds == 0, "last short step ends exactly at deadline")
	_check(ended.result != null and ended.result.outcome == FormalMatchResult.Outcome.DRAW, "zero scores produce official draw")
	_check(_count(events, MatchEvent.Type.MATCH_FINISHED) == 1, "one finish event")
	_check(not simulation.start_match() and not simulation.resume_match() and not simulation.pause_match() and not simulation.finish_match() and not simulation.cancel_match(), "finished terminal is immutable")
	_check(simulation.advance_fixed_step(1.0, []).is_empty(), "finished instance cannot advance")
	for phase in [MatchState.Phase.READY, MatchState.Phase.RUNNING, MatchState.Phase.PAUSED]:
		var cancelled := fixture.create()
		if phase != MatchState.Phase.READY:
			cancelled.start_match()
		if phase == MatchState.Phase.PAUSED:
			cancelled.pause_match()
		_check(cancelled.cancel_match("test_cancel") and not cancelled.cancel_match(), "cancellation accepted exactly once")
		var observation := cancelled.create_snapshot()
		_check(observation.phase == MatchState.Phase.CANCELLED and observation.result == null and observation.cancellation_reason == "test_cancel", "cancelled observation has reason, no official outcome")
		_check(not cancelled.start_match() and not cancelled.resume_match() and not cancelled.finish_match(), "cancel cannot be changed to finish or restart")
	for phase in MatchState.Phase.values():
		for round_phase in MatchState.RoundPhase.values():
			_check(MatchControlPolicy.can_decide(phase, round_phase) == (phase == MatchState.Phase.RUNNING and round_phase == MatchState.RoundPhase.PLAYING), "permission truth table")
	# The public simulation gate is rechecked independently of any source or UI adapter.
	for round_phase in MatchState.RoundPhase.values():
		if round_phase == MatchState.RoundPhase.PLAYING:
			continue
		var blocked := fixture.create()
		blocked.start_match()
		blocked._state._set_round_phase(round_phase)
		var snapshot := blocked.create_snapshot()
		var random_state := blocked._rng.state
		var commands: Array[MatchAction] = []
		for player in snapshot.players:
			for action in [MatchAction.Type.MOVE, MatchAction.Type.PASS, MatchAction.Type.SHOOT, MatchAction.Type.TACKLE, MatchAction.Type.ATTACK, MatchAction.Type.JUMP, MatchAction.Type.HEADER_SHOT, MatchAction.Type.SAVE]:
				commands.append(MatchAction.new(player.player_id, action, Vector2.RIGHT, "iron_guard"))
		var facts := blocked.advance_fixed_step(0.01, commands)
		_check(_count(facts, MatchEvent.Type.ACTION_ACCEPTED) == 0 and blocked._rng.state == random_state, "all non-playing stages reject field/GK actions without draws")
		for player in snapshot.players:
			_check(blocked.create_snapshot().get_player(player.player_id).position_m == player.position_m, "nonplaying phase does not move any actor")
	var serial := 0
	for event in simulation.get_event_history():
		_check(event.event_sequence > serial and event.match_id == "fixture_match", "ordered events identify their match")
		serial = event.event_sequence
	_finish()

## Counts only committed fact types.
func _count(events: Array[MatchEvent], type: int) -> int:
	var count := 0
	for event in events:
		count += int(event.event_type == type)
	return count

## Aggregates independent state contract failures.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

## Reports the deterministic lifecycle result.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print("Formal lifecycle failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)
