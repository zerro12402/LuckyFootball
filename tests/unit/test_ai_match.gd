## Exercises complete autonomous production matches, replay identity, control invalidation and ownership invariants.
extends SceneTree
const Fixture = preload("res://tests/support/ai_fixture.gd")
var _failures: PackedStringArray = []

## Runs source-only real matches and separately inspects duplicate-step and invalid-phase semantics.
func _init() -> void:
	var first := _run_match()
	var second := _run_match()
	_check(first == second, "identical seeds replay identical action and event traces")
	var f := Fixture.new()
	var simulation := f.formal.create(3.0)
	var source := f.source()
	simulation.start_match()
	var snapshot := simulation.create_snapshot()
	var commands := source.propose_actions(snapshot)
	var draws := source.get_random_draws("swift_forward")
	var repeated := source.propose_actions(simulation.create_snapshot())
	_check(_trace_actions(commands) == _trace_actions(repeated) and source.get_random_draws("swift_forward") == draws, "repeated same step replays without random consumption")
	var old_batch := MatchActionBatch.new(snapshot, commands)
	simulation.pause_match()
	source.invalidate_control(simulation.create_snapshot())
	_check(source.propose_actions(simulation.create_snapshot()).is_empty(), "paused source returns no commands")
	_check(source.get_plan("swift_forward") == null, "pause invalidates old movement plan")
	simulation.resume_match()
	var before := simulation.create_snapshot()
	simulation.advance_action_batch(0.1, old_batch)
	_check(simulation.create_snapshot().get_player("swift_forward").movement_input == Vector2.ZERO
		and before.get_player("swift_forward").position_m == simulation.create_snapshot().get_player("swift_forward").position_m,
		"pre-pause batch cannot move a player")
	var config_path := "user://bad_ai.csv"
	var file := FileAccess.open(config_path, FileAccess.WRITE)
	file.store_string("key,value,comment\nheartbeat_seconds,0.2,ok\nheartbeat_seconds,0.3,duplicate\n")
	file.close()
	var loader := AIConfigDataRepository.new()
	_check(loader.load_from_csv(config_path) == null and not loader.errors.is_empty(), "AI CSV rejects duplicates and missing required tuning transactionally")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	for failure in _failures:
		printerr(failure)
	print("AI match: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

## Uses no keyboard or mid-match state edits; every player action originates in the production source.
func _run_match() -> PackedStringArray:
	var f := Fixture.new()
	var simulation := f.formal.create(180.0)
	var source := f.source()
	var loop := GameLoop.new(simulation, 1.0 / 60.0, 0.25, 8, null, [], [source])
	simulation.start_match()
	var trace: PackedStringArray = []
	var event_counts: Dictionary[int, int] = {}
	var owners: Dictionary[String, bool] = {}
	var rounds := 1
	for step in range(10810):
		var frame := loop.advance_frame(1.0 / 60.0, [])
		var snapshot := frame.snapshot
		var possessing := 0
		for player in snapshot.players:
			if player.possession_state == PlayerMatchState.PossessionState.POSSESSING:
				possessing += 1
			if player.is_goalkeeper and player.action_state == PlayerMatchState.ActionState.IDLE \
					and snapshot.ball.owner_player_id != player.player_id:
				var plan := source.get_plan(player.player_id)
				if plan != null:
					_check(plan.action_type == MatchAction.Type.MOVE or plan.action_type == MatchAction.Type.SAVE, "keeper only moves in goal mouth or saves")
		_check(possessing <= 1, "single ball has at most one possessing player")
		if not snapshot.ball.owner_player_id.is_empty():
			owners[snapshot.get_player(snapshot.ball.owner_player_id).team_id] = true
		for event in frame.events:
			event_counts[event.event_type] = event_counts.get(event.event_type, 0) + 1
			trace.append("%d:%d:%s:%.6f" % [event.simulation_step, event.event_type, event.subject_id, event.match_time_seconds])
		# This captures intended commands as well as committed events, including frames with no events.
		trace.append(_trace_actions(source.get_last_actions()) if snapshot.can_decide_player_actions else "disabled")
		rounds = maxi(rounds, snapshot.round_sequence)
		if snapshot.phase == MatchState.Phase.FINISHED:
			break
	var result := simulation.create_snapshot()
	_check(result.phase == MatchState.Phase.FINISHED and result.result != null, "AI reaches real unique terminal result")
	_check(event_counts.get(MatchEvent.Type.MATCH_FINISHED, 0) == 1, "finish emitted exactly once")
	_check(event_counts.get(MatchEvent.Type.BALL_PASSED, 0) > 0, "autonomous match produces actual passes")
	_check(event_counts.get(MatchEvent.Type.BALL_SHOT, 0) > 0, "autonomous match produces actual shots")
	_check(event_counts.get(MatchEvent.Type.TACKLE_SUCCEEDED, 0) + event_counts.get(MatchEvent.Type.TACKLE_FAILED, 0) > 0, "autonomous match resolves tackles")
	_check(event_counts.get(MatchEvent.Type.PLAYER_KNOCKED_DOWN, 0) > 0, "autonomous match includes knockdowns")
	_check(event_counts.get(MatchEvent.Type.GOALKEEPER_SAVE_STARTED, 0) > 0, "autonomous match includes keeper responses")
	_check(owners.size() == 2 and rounds > 1, "both teams gain possession and real round resets occur")
	trace.append("%d:%d" % [result.home_score, result.away_score])
	print("AI event coverage: ", event_counts, " owners=", owners.keys(), " rounds=", rounds)
	return trace

## Creates a stable public trace without serializing private instance identity.
func _trace_actions(actions: Array[MatchAction]) -> String:
	var parts := PackedStringArray()
	for action in actions:
		parts.append("%s:%d:%s:%.6f:%.6f" % [action.player_id, action.action_type,
			action.target_player_id, action.direction.x, action.direction.y])
	return "|".join(parts)

## Records invariant failures while letting the simulation complete for diagnostics.
func _check(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
