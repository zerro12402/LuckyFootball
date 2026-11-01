## Runs grounded and aerial receptions, finishes and keeper distribution through the production AI source.
extends SceneTree
const Fixture = preload("res://tests/support/ai_fixture.gd")
var _failures: PackedStringArray = []

## Uses setup-only state injection; all subsequent movement and touches are committed by the simulation.
func _init() -> void:
	_test_ground_receptions()
	_test_aerial_sequence()
	_test_keeper_sequence()
	for failure in _failures:
		printerr(failure)
	print("AI sequences: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

## Safe low passes and high passes outside finishing range are actually collected without automatic jumping.
func _test_ground_receptions() -> void:
	for high: bool in [false, true]:
		var f := Fixture.new()
		var simulation := f.formal.create(4.0)
		for runtime in simulation._player_runtime_system.get_players():
			runtime.state_machine.reset_to_spawn(Vector2(-20, 12))
		var receiver := simulation._player_runtime_system.get_player("formal_player_02")
		var distance := 10.0 if high else 6.0
		receiver.state_machine.reset_to_spawn(Vector2(distance, 0))
		var ball := simulation._ball_runtime_system
		ball.reset_ball(Vector2.ZERO)
		ball.state._launch_pass(receiver.player_id, Vector2.RIGHT * 14, distance, 1.8 if high else 0.0)
		ball._last_kicker_id = "swift_forward"
		ball._ai_flight_sequence += 1
		var source := f.source()
		var loop := GameLoop.new(simulation, 1.0 / 60.0, 0.25, 8, null, [], [source])
		simulation.start_match()
		var received := false
		var jumped := false
		for step in range(100):
			var frame := loop.advance_frame(1.0 / 60.0, [])
			var player := frame.snapshot.get_player(receiver.player_id)
			jumped = jumped or player.jump_phase != PlayerMatchState.JumpPhase.NONE
			if frame.snapshot.ball.owner_player_id == receiver.player_id:
				received = true
				break
		_check(received and not jumped, "safe " + ("high" if high else "ground") + " pass is received on the ground")
		var following := loop.advance_frame(1.0 / 60.0, [])
		_check(following.snapshot.get_player(receiver.player_id).jump_phase == PlayerMatchState.JumpPhase.NONE,
			"safe receiver does not randomly jump just after obtaining possession")

## Repeats the same real high pass after landing to catch stale one-shot jump markers.
func _test_aerial_sequence() -> void:
	var f := Fixture.new()
	var simulation := f.formal.create(8.0)
	var source := f.source()
	var loop := GameLoop.new(simulation, 1.0 / 60.0, 0.25, 8, null, [], [source])
	var receiver_id := "formal_player_02"
	var jumps := 0
	var shots := 0
	var airborne_receives := 0
	for repetition in range(2):
		for runtime in simulation._player_runtime_system.get_players():
			runtime.state_machine.reset_to_spawn(Vector2(-20, 12))
		var receiver := simulation._player_runtime_system.get_player(receiver_id)
		receiver.state_machine.reset_to_spawn(Vector2(14, 0))
		var ball := simulation._ball_runtime_system
		ball.reset_ball(Vector2.ZERO)
		ball.state._launch_pass(receiver_id, Vector2(14, 0), 14, 1.8)
		ball._last_kicker_id = "swift_forward"
		ball._ai_flight_sequence += 1
		source.invalidate_control(simulation.create_snapshot())
		if repetition == 0:
			simulation.start_match()
		var saw_jump := false
		for step in range(150):
			var frame := loop.advance_frame(1.0 / 60.0, [])
			var player := frame.snapshot.get_player(receiver_id)
			saw_jump = saw_jump or player.jump_phase != PlayerMatchState.JumpPhase.NONE
			for event in frame.events:
				if event.event_type == MatchEvent.Type.BALL_POSSESSION_GAINED and event.subject_id == receiver_id \
						and player.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE:
					airborne_receives += 1
				if event.event_type == MatchEvent.Type.BALL_SHOT and event.subject_id == receiver_id:
					shots += 1
			if step > 70 and player.jump_phase == PlayerMatchState.JumpPhase.NONE \
					and player.action_state == PlayerMatchState.ActionState.IDLE:
				break
		if saw_jump:
			jumps += 1
	_check(jumps == 2 and shots == 2 and airborne_receives == 2,
		"successive high passes cause airborne receive and actual shot on both attempts")

## Forces only a contact sample, not the catch itself; F04 and the hand/foot attachment still execute.
func _test_keeper_sequence() -> void:
	var f := Fixture.new()
	var simulation := f.formal.create(5.0)
	for runtime in simulation._player_runtime_system.get_players():
		runtime.state_machine.reset_to_spawn(Vector2(-20, 12))
	var keeper := simulation._player_runtime_system.get_player("formal_player_09")
	keeper.state_machine.reset_to_spawn(Vector2(24.2, 0))
	keeper.state._set_facing_direction(Vector2.LEFT)
	var mate := simulation._player_runtime_system.get_player("formal_player_06")
	mate.state_machine.reset_to_spawn(Vector2(15, 5))
	var ball := simulation._ball_runtime_system
	ball.reset_ball(Vector2(16, 0))
	ball.state._launch_shot(Vector2(16, 0), Vector2(20, 0), 20, 0.65)
	ball._last_kicker_id = "swift_forward"
	ball._shot_source = BallShotSource.new("swift_forward", "home", 84, 1)
	ball._shot_context = ShotFlightContext.new(ball._shot_source)
	ball._ai_flight_sequence += 1
	simulation._keeper_sampler = func() -> float: return 0.0
	var source := f.source()
	var loop := GameLoop.new(simulation, 1.0 / 60.0, 0.25, 8, null, [], [source])
	simulation.start_match()
	var caught := false
	var passed := false
	for step in range(250):
		var frame := loop.advance_frame(1.0 / 60.0, [])
		for event in frame.events:
			if event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED and event.goalkeeper_save.did_catch:
				caught = true
			if event.event_type == MatchEvent.Type.BALL_PASSED and event.subject_id == keeper.player_id:
				passed = true
		if caught and frame.snapshot.ball.owner_player_id == keeper.player_id:
			_check(frame.snapshot.get_player(keeper.player_id).movement_input == Vector2.ZERO,
				"keeper never carries a catch away from goal")
		if passed:
			break
	_check(caught and passed, "keeper responds to actual shot, catches via F04 and passes from a stationary position")

## Records sequence-level failures independently.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
