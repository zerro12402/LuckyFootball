## Verifies real sideline restarts, last-touch ownership and temporal isolation without a renderer.
extends SceneTree
const Fixture = preload("res://tests/support/formal_match_fixture.gd")
var _failures: PackedStringArray = []

## Covers geometry, both touchlines, carried and flying exits, defensive touches and terminal priority.
func _init() -> void:
	var f := Fixture.new()
	_test_selection(f)
	for side in [-1.0, 1.0]:
		for kind in ["carry", "pass", "shot"]:
			_test_exit(f, side, kind)
	_test_deflection(f)
	_test_terminal(f)
	for failure in _failures:
		printerr(failure)
	print("Sideline restarts: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

## Creates a production-enabled formal session, then uses explicit fixture setup for a known trajectory.
func _session(f: RefCounted, duration: float = 20.0) -> MatchSimulation:
	var simulation: MatchSimulation = f.create(duration, "sideline", 42, true)
	simulation.start_match()
	simulation.advance_fixed_step(0.01, [MatchAction.new(simulation.create_snapshot().kickoff_player_id,
		MatchAction.Type.MOVE, Vector2.RIGHT)])
	return simulation

## Stages the ball just inside a line; ownership is assigned through the same atomic runtime path.
func _stage(simulation: MatchSimulation, side: float, kind: String, owner_id: String = "swift_forward") -> void:
	for player in simulation._player_runtime_system.get_players():
		player.state_machine.reset_to_spawn(Vector2(-20 if player.team_id == "home" else 20, 0))
	var ball := simulation._ball_runtime_system
	var point := Vector2(7, side * (15.0 + simulation._match_config.ball_radius_m - 0.1))
	ball.reset_ball(point)
	var owner := simulation._player_runtime_system.get_player(owner_id)
	owner.state._set_position(point - Vector2.RIGHT * BallRuntimeSystem.DEFAULT_DRIBBLE_OFFSET_M)
	var contact := BallContactCandidate.new()
	contact.player_id = owner_id
	ball.acquire_contact_ball(contact, simulation._player_runtime_system)
	if kind == "carry":
		return
	owner.state_machine.set_possession_state(PlayerMatchState.PossessionState.NO_BALL)
	ball._protect_releaser(owner_id)
	ball._last_kicker_id = owner_id
	if kind == "pass":
		ball.state._launch_pass("formal_player_03" if owner.team_id == "home" else "formal_player_07",
			Vector2(2, side * 20), 100, 0.05)
	else:
		ball.state._launch_shot(point, Vector2(2, side * 20), 100, 0.05)
		ball._shot_source = BallShotSource.new(owner_id, owner.team_id, 100, 1)
		ball._shot_context = ShotFlightContext.new(ball._shot_source)

## Stops at the reset frame so subsequent AI or movement cannot hide which positions were retained.
func _wait_restart(simulation: MatchSimulation, round_number: int) -> Array[MatchEvent]:
	var events: Array[MatchEvent] = []
	for step in range(160):
		events.append_array(simulation.advance_fixed_step(0.05, []))
		if simulation.create_snapshot().round_sequence > round_number or not simulation.is_running():
			break
	return events

## Distance and ID selection ignore a closer keeper, and corners remain on the touchline inside the end line.
func _test_selection(f: RefCounted) -> void:
	var first := PlayerRuntime.new("a", Vector2(1, 0), 5, "home")
	var second := PlayerRuntime.new("b", Vector2(-1, 0), 5, "home")
	var keeper := PlayerRuntime.new("keeper", Vector2.ZERO, 5, "home", 84, 80, 80, true)
	var players: Array[PlayerStateSnapshot] = [
		PlayerStateSnapshot.new(second.state, "home", false, second),
		PlayerStateSnapshot.new(keeper.state, "home", true, keeper),
		PlayerStateSnapshot.new(first.state, "home", false, first)]
	_check(SidelineRestartRules.select_taker(players, "home", Vector2.ZERO) == "a", "equal distances use stable IDs and exclude keeper")
	var corner := SidelineRestartRules.ball_position(Vector2(30, -16),
		MatchBoundaryResult.Side.TOP, f.field, 0.1)
	_check(corner.is_equal_approx(Vector2(24.9, -15)), "corner restart projects inside end line")
	_check(SidelineRestartRules.restart_team("", "home", "away", "home") == "away",
		"unknown artificial touch has deterministic fallback")

## A completed sideline reset preserves bystanders, assigns one opponent and invalidates old-round commands.
func _test_exit(f: RefCounted, side: float, kind: String) -> void:
	var simulation := _session(f)
	_stage(simulation, side, kind)
	var old := MatchActionBatch.new(simulation.create_snapshot(), [
		MatchAction.new("formal_player_04", MatchAction.Type.MOVE, Vector2.UP)])
	var commands: Array[MatchAction] = []
	if kind == "carry":
		commands.append(MatchAction.new("swift_forward", MatchAction.Type.MOVE, Vector2(0, side)))
	var events := simulation.advance_fixed_step(0.1, commands)
	var stopped := simulation.create_snapshot()
	_check(stopped.round_phase == MatchState.RoundPhase.OUT_RESOLVED, "real " + kind + " trajectory crosses touchline")
	if stopped.round_phase != MatchState.RoundPhase.OUT_RESOLVED:
		return
	var point := simulation._pending_sideline_position_m
	var expected := SidelineRestartRules.select_taker(stopped.players, "away", point)
	var rng_state := simulation._rng.state
	simulation.pause_match()
	var paused := simulation.create_snapshot()
	simulation.advance_fixed_step(1.0, [])
	_check(simulation.create_snapshot().elapsed_seconds == paused.elapsed_seconds
		and simulation.create_snapshot().ball.position_m == paused.ball.position_m, "pause freezes boundary waiting")
	simulation.resume_match()
	events.append_array(_wait_restart(simulation, 1))
	var snapshot := simulation.create_snapshot()
	_check(snapshot.round_sequence == 2 and snapshot.kickoff_team_id == "away"
		and snapshot.kickoff_player_id == expected and snapshot.kickoff_pending, "opponent's nearest outfield player restarts")
	_check(snapshot.ball.position_m.is_equal_approx(point) and is_equal_approx(point.y, side * 15)
		and absf(point.x) > 6, "restart stays at locked crossing instead of center or drifting ball")
	var possessing := 0
	for player in snapshot.players:
		possessing += int(player.possession_state == PlayerMatchState.PossessionState.POSSESSING)
		if player.player_id != expected:
			_check(player.position_m == stopped.get_player(player.player_id).position_m, "bystander position retained")
		var runtime := simulation._player_runtime_system.get_player(player.player_id)
		_check(runtime.spawn_position_m != Vector2(-20 if player.team_id == "home" else 20, 0),
			"normal formation spawn remains independent of temporary fixture/restart position")
	_check(possessing == 1 and snapshot.ball.owner_player_id == expected, "restart has exactly one owner")
	_check(absf(snapshot.get_player(expected).position_m.y) < 15, "taker stands inside touchline")
	_check(simulation._rng.state == rng_state and snapshot.home_score == 0 and snapshot.away_score == 0,
		"restart preserves contest RNG and scores")
	var resets := 0
	for event in events:
		if event.event_type == MatchEvent.Type.RESET_COMPLETED:
			resets += 1
			_check(event.ball_position_m.is_equal_approx(point), "reset event carries actual sideline position")
	_check(resets == 1, "one exit produces one reset")
	simulation.advance_action_batch(0.01, old)
	_check(simulation.create_snapshot().kickoff_pending, "old round batch cannot take new restart")
	simulation.advance_fixed_step(0.01, [
		MatchAction.new(expected, MatchAction.Type.MOVE, Vector2(-1, -side))])
	_check(not simulation.create_snapshot().kickoff_pending
		and simulation.create_snapshot().round_phase == MatchState.RoundPhase.PLAYING, "inward move safely resumes normal play")
	if side > 0 and kind == "carry":
		_stage(simulation, -side, "pass", "formal_player_08")
		simulation.advance_fixed_step(0.1, [])
		_wait_restart(simulation, 2)
		_check(simulation.create_snapshot().round_sequence == 3
			and simulation.create_snapshot().kickoff_team_id == "home", "repeated opposite touchline exit uses new last toucher")

## A real F08 body hit is the last touch even when the shot continues under its original source.
func _test_deflection(f: RefCounted) -> void:
	var simulation := _session(f)
	_stage(simulation, -1.0, "shot")
	var ball := simulation._ball_runtime_system
	ball.state._launch_shot(Vector2(7, -12), Vector2(0, -20), 100, 0.05)
	var target := simulation._player_runtime_system.get_player("formal_player_04")
	target.state._set_position(Vector2(7, -14.5))
	simulation._ball_route_sampler = func() -> float: return 0.0
	var hit := false
	for step in range(60):
		for event in simulation.advance_fixed_step(0.01, []):
			hit = hit or event.event_type == MatchEvent.Type.BALL_HIT
		if simulation.create_snapshot().round_phase != MatchState.RoundPhase.PLAYING:
			break
	_check(hit and ball.last_touch_player_id == target.player_id and ball.last_kicker_id == "swift_forward",
		"actual body touch updates last toucher without replacing shot source")
	_wait_restart(simulation, 1)
	_check(simulation.create_snapshot().kickoff_team_id == "home", "defender's contact gives original shooting team sideline restart")

## The existing deadline ends settlement without inventing an extra round or restart.
func _test_terminal(f: RefCounted) -> void:
	var simulation := _session(f, 0.5)
	_stage(simulation, -1.0, "shot")
	simulation.advance_fixed_step(0.1, [])
	var events := _wait_restart(simulation, 1)
	_check(simulation.create_snapshot().phase == MatchState.Phase.FINISHED
		and simulation.create_snapshot().round_sequence == 1, "deadline preempts pending sideline restart")
	for event in events:
		_check(event.event_type != MatchEvent.Type.RESET_COMPLETED, "no restart after final whistle")

## Aggregates failures while retaining independent coverage.
func _check(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
