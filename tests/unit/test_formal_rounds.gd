## Verifies twelve-player reset, stop-play isolation, net/save tails and whole-session deterministic replay.
extends SceneTree
const Fixture = preload("res://tests/support/formal_match_fixture.gd")
var _failures: PackedStringArray = []

class ScriptedSource extends MatchActionSource:
	var calls: int = 0
	## Follows a fixed test route, issuing only normal commands for all twelve actors.
	func propose_actions(snapshot: MatchStateSnapshot) -> Array[MatchAction]:
		calls += 1
		var commands: Array[MatchAction] = []
		for player in snapshot.players:
			if player.player_id != "swift_forward":
				commands.append(MatchAction.new(player.player_id, MatchAction.Type.MOVE, Vector2.ZERO))
		var shooter := snapshot.get_player("swift_forward")
		if snapshot.round_sequence == 1:
			if shooter.position_m.x < 20.0:
				commands.append(MatchAction.new(shooter.player_id, MatchAction.Type.MOVE, Vector2.RIGHT))
			elif snapshot.ball.owner_player_id == shooter.player_id:
				commands.append(MatchAction.new(shooter.player_id, MatchAction.Type.MOVE, Vector2.ZERO))
				commands.append(MatchAction.new(shooter.player_id, MatchAction.Type.SHOOT))
		elif snapshot.round_sequence == 2:
			commands.append(MatchAction.new(shooter.player_id, MatchAction.Type.MOVE,
				Vector2.UP if snapshot.ball.owner_player_id == shooter.player_id else (snapshot.ball.position_m - shooter.position_m).normalized()))
		return commands

## Runs both boundary kinds with real flight, then checks atomic reset and preserved persistent metadata.
func _init() -> void:
	var fixture := Fixture.new()
	for goal: bool in [false, true]:
		var simulation := fixture.create(10.0)
		var initial := simulation.create_snapshot()
		simulation.start_match()
		simulation._rng.randi()
		var random_state := simulation._rng.state
		fixture.launch_boundary(simulation, 0.05, goal)
		var commands: Array[MatchAction] = [MatchAction.new("iron_guard", MatchAction.Type.MOVE, Vector2.DOWN), MatchAction.new("formal_player_02", MatchAction.Type.ATTACK, Vector2.ZERO, "formal_player_04")]
		var facts := simulation.advance_fixed_step(0.1, commands)
		var stopped := simulation.create_snapshot()
		_check(stopped.round_phase != MatchState.RoundPhase.PLAYING and not stopped.can_decide_player_actions, "boundary disables player control")
		_check(simulation._pending_knockdown_targets.is_empty(), "settlement cancels unfinished melee intent")
		var stale := MatchActionBatch.new(stopped, [MatchAction.new("iron_guard", MatchAction.Type.MOVE, Vector2.UP)])
		var counts := 0
		for step in range(60):
			var events := simulation.advance_fixed_step(0.05, commands)
			facts.append_array(events)
			var snapshot := simulation.create_snapshot()
			for event in events:
				if event.event_type == MatchEvent.Type.RESET_COMPLETED:
					counts += 1
			if snapshot.round_sequence == 2:
				break
			for player in stopped.players:
				_check(snapshot.get_player(player.player_id).position_m == player.position_m, "settlement freezes all ordinary/lunge/forced positions")
		_check(counts == 1, "boundary produces one reset")
		var restored := simulation.create_snapshot()
		_check(restored.round_sequence == 2 and restored.simulation_step > stopped.simulation_step and restored.elapsed_seconds > stopped.elapsed_seconds, "round increments while clock and steps remain cumulative")
		_check(restored.match_id == initial.match_id and restored.home_score == (1 if goal else 0), "identity and team scores survive reset")
		_check(simulation._rng.state == random_state, "round reset preserves RNG progress")
		_check(restored.ball.position_m == Vector2.ZERO and restored.ball.owner_player_id.is_empty() and restored.ball.height_m == 0 and restored.ball.velocity_mps == Vector2.ZERO and restored.ball.control_attachment == BallMatchState.ControlAttachment.FOOT, "one centered free ball with cleared hands and trajectory")
		for player in initial.players:
			var current := restored.get_player(player.player_id)
			_check(current.position_m == player.position_m and current.movement_input == Vector2.ZERO and current.action_state == PlayerMatchState.ActionState.IDLE and current.possession_state == PlayerMatchState.PossessionState.NO_BALL, "all twelve reset atomically")
			if current.is_goalkeeper:
				_check(current.facing_direction == (Vector2.RIGHT if current.team_id == "home" else Vector2.LEFT), "keepers face into the field after reset")
		simulation.advance_action_batch(0.01, stale)
		_check(simulation.create_snapshot().get_player("iron_guard").movement_input == Vector2.ZERO, "old round batch cannot resume old movement")
		var phases: PackedInt32Array = []
		for event in facts:
			if event.event_type == MatchEvent.Type.ROUND_PHASE_CHANGED:
				phases.append(event.round_phase)
		var expected := PackedInt32Array([MatchState.RoundPhase.GOAL_RESOLVED, MatchState.RoundPhase.POST_GOAL_MOTION, MatchState.RoundPhase.RESETTING, MatchState.RoundPhase.PLAYING]) if goal else PackedInt32Array([MatchState.RoundPhase.OUT_RESOLVED, MatchState.RoundPhase.RESETTING, MatchState.RoundPhase.PLAYING])
		_check(phases == expected, "transient phases remain observable and ordered")
	var chained := fixture.create(10.0)
	chained.start_match()
	chained._ball_route_sampler = func() -> float: return 0.0
	var wall := chained._player_runtime_system.get_player("formal_player_04")
	wall.state._set_position(Vector2(22, 0))
	fixture.launch_boundary(chained, 0.3)
	var chain_events := chained.advance_fixed_step(0.4, [])
	var hit_seen := false
	for event in chain_events:
		if event.event_type == MatchEvent.Type.BALL_HIT:
			hit_seen = true
			_check(event.round_phase == MatchState.RoundPhase.PLAYING, "pre-goal impact retains its actual phase context")
	_check(hit_seen and chained.create_snapshot().home_score == 1, "same-step impact and later goal share one ordered stream")
	var signatures: Array[PackedStringArray] = []
	for iteration in range(2):
		var simulation := fixture.create(5.0, "replay", 77)
		simulation.start_match()
		fixture.launch_boundary(simulation, 0.05)
		simulation.advance_fixed_step(0.1, [])
		simulation.pause_match()
		var before := simulation.create_snapshot()
		simulation.advance_fixed_step(1.0, [])
		_check(simulation.create_snapshot().ball.position_m == before.ball.position_m and simulation.create_snapshot().elapsed_seconds == before.elapsed_seconds, "paused goal tail freezes")
		simulation.resume_match()
		for step in range(60):
			simulation.advance_fixed_step(0.1, [])
			if simulation.create_snapshot().round_sequence > 1:
				break
		fixture.launch_boundary(simulation, 0.05, false)
		for step in range(70):
			simulation.advance_fixed_step(0.1, [])
		var snapshot := simulation.create_snapshot()
		_check(snapshot.phase == MatchState.Phase.FINISHED and snapshot.result != null and snapshot.home_score == 1, "preset twelve-player session reaches final score after goal/out/pause/reset")
		var signature: PackedStringArray = []
		for event in simulation.get_event_history():
			signature.append("%d/%d/%d/%d/%.6f" % [event.event_sequence, event.event_type, event.round_phase, event.control_revision, event.match_time_seconds])
		signatures.append(signature)
	_check(signatures[0] == signatures[1], "full same-seed session event replay matches")
	_scripted_session(fixture)
	for failure in _failures:
		push_error(failure)
	print("Formal rounds failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Completes one full formal match using sources and normal actions only, with no mid-play state mutation.
func _scripted_session(fixture: RefCounted) -> void:
	var signatures: Array[PackedStringArray] = []
	for iteration in range(2):
		var simulation: MatchSimulation = fixture.create(25.0, "scripted_replay", 99)
		# Only isolate F11 accuracy; positions, ownership, goals, exits and resets all follow real actions.
		simulation._shot_miss_override = 0
		simulation._shot_aim_sampler = func() -> int: return ShotAim.Lane.CENTER
		var source := ScriptedSource.new()
		var loop := GameLoop.new(simulation, 0.05, 1.0, 10, null, [], [source])
		simulation.start_match()
		for frame in range(600):
			if frame == 20:
				simulation.pause_match()
				var paused := simulation.create_snapshot()
				var calls := source.calls
				loop.advance_frame(0.5, [])
				_check(source.calls == calls and simulation.create_snapshot().elapsed_seconds == paused.elapsed_seconds, "full-session pause neither advances nor schedules")
				simulation.resume_match()
			loop.advance_frame(0.05, [])
			if simulation.create_snapshot().phase == MatchState.Phase.FINISHED:
				break
		var snapshot := simulation.create_snapshot()
		_check(snapshot.phase == MatchState.Phase.FINISHED and snapshot.home_score == 1 and snapshot.away_score == 0, "source-only twelve-player match scores, resets, exits and ends")
		var goals := 0
		var exits := 0
		var resets := 0
		var finishes := 0
		var signature: PackedStringArray = []
		for event in simulation.get_event_history():
			goals += int(event.event_type == MatchEvent.Type.GOAL_SCORED)
			exits += int(event.event_type == MatchEvent.Type.BALL_OUT_OF_BOUNDS)
			resets += int(event.event_type == MatchEvent.Type.RESET_COMPLETED)
			finishes += int(event.event_type == MatchEvent.Type.MATCH_FINISHED)
			signature.append("%d/%s/%d/%.6f" % [event.event_type, event.subject_id, event.round_sequence, event.match_time_seconds])
		_check(goals == 1 and exits == 1 and resets == 2 and finishes == 1, "source-only full flow has exactly one goal/exit/finish and two resets")
		signatures.append(signature)
	_check(signatures[0] == signatures[1], "full source-driven match reproduces the complete event stream")

## Collects independent settlement and reset failures.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
