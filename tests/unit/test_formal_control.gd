## Verifies same-snapshot scheduling, source ordering, stale batches, input neutralization and terminal frames.
extends SceneTree
const Fixture = preload("res://tests/support/formal_match_fixture.gd")
var _failures: PackedStringArray = []

class CountingSource extends MatchActionSource:
	var calls: int = 0
	var invalidations: int = 0
	var snapshots: Array[MatchStateSnapshot] = []
	var commands: Array[MatchAction] = []
	## Returns explicit test intent while retaining the exact snapshot identity supplied by the scheduler.
	func propose_actions(snapshot: MatchStateSnapshot) -> Array[MatchAction]:
		calls += 1
		snapshots.append(snapshot)
		return commands.duplicate()
	## Tracks cache invalidations separately from tactical calls.
	func invalidate_control(_snapshot: MatchStateSnapshot) -> void:
		invalidations += 1

## Exercises scheduling without constructing UI, actors or animations.
func _init() -> void:
	var fixture := Fixture.new()
	var simulation := fixture.create(0.25)
	var first := CountingSource.new()
	var second := CountingSource.new()
	first.commands = [MatchAction.new("swift_forward", MatchAction.Type.MOVE, Vector2.RIGHT)]
	var loop := GameLoop.new(simulation, 0.1, 1.0, 10, null, [], [first, second])
	loop.advance_frame(0.5, [])
	_check(first.calls == 0 and second.calls == 0, "READY sources never called")
	simulation.start_match()
	loop.advance_frame(0.1, [])
	_check(first.calls == 1 and second.calls == 1 and first.snapshots[0] == second.snapshots[0], "sources share one exact immutable snapshot")
	var old_snapshot := simulation.create_snapshot()
	var old_batch := MatchActionBatch.new(old_snapshot, [MatchAction.new("swift_forward", MatchAction.Type.MOVE, Vector2.LEFT)])
	loop.advance_frame(0.04, old_batch.actions)
	simulation.pause_match()
	simulation.resume_match()
	var stopped := simulation.create_snapshot().get_player("swift_forward").position_m
	first.commands = []
	loop.advance_frame(0.01, [])
	_check(first.calls == 1 and loop._pending_actions.is_empty(), "unobserved pause/resume clears cached commands and frame remainder")
	simulation.advance_action_batch(0.01, old_batch)
	_check(simulation.create_snapshot().get_player("swift_forward").position_m == stopped, "pre-pause batch cannot execute after resume")
	var other := fixture.create(1.0, "other_instance")
	other.start_match()
	other.advance_action_batch(0.01, old_batch)
	_check(other.create_snapshot().get_player("swift_forward").movement_input == Vector2.ZERO, "old-instance batch rejected")
	loop.advance_frame(0.7, [])
	_check(simulation.create_snapshot().phase == MatchState.Phase.FINISHED and first.calls == 3 and second.calls == 3, "one display frame stops source calls at short final step")
	var calls := first.calls
	loop.advance_frame(1.0, [])
	_check(first.calls == calls and loop._accumulator_seconds == 0.0, "terminal frames neither call sources nor accumulate catchup")
	for round_phase in MatchState.RoundPhase.values():
		if round_phase == MatchState.RoundPhase.PLAYING:
			continue
		var session := fixture.create(1.0)
		session.start_match()
		session._state._set_round_phase(round_phase)
		var source := CountingSource.new()
		var paused_loop := GameLoop.new(session, 0.1, 1.0, 10, null, [], [source])
		paused_loop.advance_frame(0.3, [])
		_check(source.calls == 0, "nonplaying round never schedules tactical sources")
	var original_instance := fixture.create()
	var replacement_instance := fixture.create()
	original_instance.start_match()
	replacement_instance.start_match()
	var colliding_id_batch := MatchActionBatch.new(original_instance.create_snapshot(), [MatchAction.new("swift_forward", MatchAction.Type.MOVE, Vector2.RIGHT)])
	replacement_instance.advance_action_batch(0.01, colliding_id_batch)
	_check(replacement_instance.create_snapshot().get_player("swift_forward").movement_input == Vector2.ZERO, "old instance cannot submit even if an external caller reuses the same match label")
	var sorted_session := fixture.create()
	sorted_session.start_match()
	var source := CountingSource.new()
	source.commands = [MatchAction.new("swift_forward", MatchAction.Type.MOVE, Vector2.LEFT), MatchAction.new("iron_guard", MatchAction.Type.MOVE, Vector2.UP), MatchAction.new("swift_forward", MatchAction.Type.MOVE, Vector2.RIGHT)]
	var ordered_loop := GameLoop.new(sorted_session, 0.1, 1.0, 10, null, [], [source])
	var frame := ordered_loop.advance_frame(0.1, [])
	var ids: PackedStringArray = []
	for event in frame.events:
		if event.event_type == MatchEvent.Type.ACTION_ACCEPTED:
			ids.append(event.subject_id)
	_check(ids == PackedStringArray(["iron_guard", "swift_forward", "swift_forward"]), "stable player order preserves per-player command order")
	_check(frame.snapshot.get_player("swift_forward").movement_input == Vector2.RIGHT, "same-player intent order preserved")
	var frozen := frame.snapshot
	var copied := frozen.players
	copied.clear()
	var random_state := sorted_session._rng.state
	for read in range(5):
		sorted_session.create_snapshot()
	_check(frozen.players.size() == 12 and sorted_session._rng.state == random_state, "deep readonly observation and reads never draw")
	for failure in _failures:
		push_error(failure)
	print("Formal control failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Collects independent scheduler and stamp failures.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
