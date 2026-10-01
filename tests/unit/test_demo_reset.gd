extends SceneTree

var _started_snapshots: Array[MatchStateSnapshot] = []
var _latest_snapshot: MatchStateSnapshot
var _actions: Array[MatchAction] = []
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	test_tilde_when_pressed_restores_demo_and_clears_pending_actions()

	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func test_tilde_when_pressed_restores_demo_and_clears_pending_actions() -> void:
	var bootstrap := GameBootstrap.new()
	var keyboard := KeyboardPlayerInputAdapter.new()
	keyboard.name = "KeyboardPlayerInputAdapter"
	bootstrap.add_child(keyboard)
	bootstrap.game_started.connect(_record_start)
	bootstrap.presentation_frame_ready.connect(_record_frame)
	keyboard.action_requested.connect(_record_action)
	root.add_child(bootstrap)
	_expect(_started_snapshots.size() == 1, "Expected demo to start")
	if _started_snapshots.is_empty():
		bootstrap.queue_free()
		return

	var initial_snapshot := _started_snapshots[0]
	var player_id := initial_snapshot.players[0].player_id
	var teammate_id := initial_snapshot.players[1].player_id
	bootstrap.queue_action(
		MatchAction.new(player_id, MatchAction.Type.MOVE, Vector2.RIGHT)
	)
	bootstrap._process(0.2)
	_expect(_latest_snapshot.simulation_step > 0, "Expected demo to advance")
	_expect(
		_latest_snapshot.get_player(player_id).position_m.x > 0.0,
		"Expected player to move before reset",
	)
	bootstrap.queue_action(
		MatchAction.new(player_id, MatchAction.Type.MOVE, Vector2.LEFT)
	)
	_press_key(keyboard, KEY_TAB)
	_press_reset_key(keyboard)
	_expect(_started_snapshots.size() == 2, "Expected tilde to start a fresh demo")
	_expect(_latest_snapshot.phase == MatchState.Phase.RUNNING, "Expected running demo")
	_expect(_latest_snapshot.simulation_step == 0, "Expected simulation step zero")
	_expect(is_zero_approx(_latest_snapshot.elapsed_seconds), "Expected time zero")
	_expect(
		_latest_snapshot.get_player(player_id).position_m == Vector2.ZERO,
		"Expected first player at initial position",
	)
	_expect(
		_latest_snapshot.get_player(teammate_id).position_m
		== GameBootstrap.TEST_TEAMMATE_POSITION_M,
		"Expected teammate at initial position",
	)
	_expect(
		_latest_snapshot.ball.position_m == GameBootstrap.TEST_BALL_INITIAL_POSITION_M,
		"Expected ball at initial position",
	)
	_expect(
		_latest_snapshot.ball.owner_player_id.is_empty(),
		"Expected no ball owner after reset",
	)
	bootstrap._process(bootstrap.fixed_delta_seconds)
	_expect(
		_latest_snapshot.get_player(player_id).position_m == Vector2.ZERO,
		"Expected queued movement to be discarded by reset",
	)
	_actions.clear()
	_press_key(keyboard, KEY_J)
	_expect(
		_actions.size() == 1 and _actions[0].player_id == player_id,
		"Expected reset to restore control to first player",
	)

	_expect(bootstrap.finish_match(), "Expected demo to finish")
	_press_reset_key(keyboard)
	_expect(_started_snapshots.size() == 3, "Expected reset to restart finished demo")
	_expect(_latest_snapshot.phase == MatchState.Phase.RUNNING, "Expected restarted demo")
	bootstrap.queue_free()


func _press_key(adapter: KeyboardPlayerInputAdapter, key_code: int) -> void:
	var key_event := InputEventKey.new()
	key_event.keycode = key_code
	key_event.pressed = true
	adapter._unhandled_key_input(key_event)


func _press_reset_key(adapter: KeyboardPlayerInputAdapter) -> void:
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_QUOTELEFT
	key_event.shift_pressed = true
	key_event.pressed = true
	adapter._unhandled_key_input(key_event)


func _record_start(snapshot: MatchStateSnapshot) -> void:
	_started_snapshots.append(snapshot)


func _record_frame(
	snapshot: MatchStateSnapshot,
	_events: Array[MatchEvent],
	_interpolation_alpha: float,
) -> void:
	_latest_snapshot = snapshot


func _record_action(action: MatchAction) -> void:
	_actions.append(action)


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
