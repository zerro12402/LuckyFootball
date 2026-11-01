## Checks shared demo mode setup, switching, input availability, and reset flow.
extends SceneTree

var _started_snapshots: Array[MatchStateSnapshot] = []
var _actions: Array[MatchAction] = []
var _failures: PackedStringArray = []


## Waits for the scene tree before creating mode scenes.
func _init() -> void:
	call_deferred("_run_tests")


## Runs the independent mode checks and returns a failure code when needed.
func _run_tests() -> void:
	test_mode_scenes_when_loaded_have_expected_demo_configuration()
	test_mode_menu_when_selected_replaces_active_scene()
	test_touch_dribble_mode_when_reset_keeps_one_player()

	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## Ensures each saved entry scene still selects its intended shared demo preset.
func test_mode_scenes_when_loaded_have_expected_demo_configuration() -> void:
	var formal_scene := load("res://scenes/match/formal_match.tscn") as PackedScene
	var touch_scene := load("res://scenes/test/touch_dribble_demo.tscn") as PackedScene
	var pass_scene := load("res://scenes/test/pass_shoot_demo.tscn") as PackedScene
	var menu_scene := load("res://scenes/main/game_modes.tscn") as PackedScene
	_expect(formal_scene != null, "Expected empty formal match scene")
	_expect(touch_scene != null, "Expected touch and dribble scene")
	_expect(pass_scene != null, "Expected pass and shoot scene")
	_expect(menu_scene != null, "Expected mode menu scene")
	if touch_scene == null or pass_scene == null:
		return
	var touch_demo := touch_scene.instantiate() as GameBootstrap
	var pass_demo := pass_scene.instantiate() as GameBootstrap
	_expect(touch_demo != null, "Expected touch mode to inherit GameBootstrap")
	_expect(pass_demo != null, "Expected pass mode to inherit GameBootstrap")
	if touch_demo != null:
		_expect(
			touch_demo.demo_mode == GameBootstrap.DemoMode.TOUCH_AND_DRIBBLE,
			"Expected one-player touch mode",
		)
		touch_demo.free()
	if pass_demo != null:
		_expect(
			pass_demo.demo_mode == GameBootstrap.DemoMode.PASS_AND_SHOOT,
			"Expected two-player pass mode",
		)
		pass_demo.free()


## Verifies menu selection replaces one active scene with the next.
func test_mode_menu_when_selected_replaces_active_scene() -> void:
	var menu_scene := load("res://scenes/main/game_modes.tscn") as PackedScene
	if menu_scene == null:
		return
	var menu := menu_scene.instantiate() as GameModeController
	if menu == null:
		_expect(false, "Expected a GameModeController root")
		return
	root.add_child(menu)
	var mode_host := menu.get_node("ModeHost")
	var mode_panel := menu.get_node_or_null("%ModePanel") as PanelContainer
	var menu_toggle := menu.get_node_or_null("%TestUiToggleButton") as Button
	_expect(mode_panel != null and menu_toggle != null, "Expected both unique test-menu nodes in the saved main scene")
	if mode_panel == null or menu_toggle == null:
		menu.queue_free()
		return
	_expect(mode_panel.visible and not menu_toggle.visible, "Expected expanded demo menu without a formal-only toggle")
	_expect(menu.current_mode == GameModeController.Mode.PASS_AND_SHOOT, "Expected pass demo")
	_expect(mode_host.get_child_count() == 1, "Expected one active mode scene")
	var formal_button := menu.get_node(
		"ModeUi/ModePanel/ModeButtons/FormalMatchButton"
	) as Button
	var touch_button := menu.get_node(
		"ModeUi/ModePanel/ModeButtons/TouchDribbleButton"
	) as Button
	var pass_button := menu.get_node(
		"ModeUi/ModePanel/ModeButtons/PassShootButton"
	) as Button
	formal_button.pressed.emit()
	_expect(menu.current_mode == GameModeController.Mode.FORMAL_MATCH, "Expected formal mode")
	_expect(mode_host.get_child_count() == 1, "Expected one empty formal scene")
	_expect(mode_host.get_child(0).name == "FormalMatch", "Expected formal scene root")
	_expect(not mode_panel.visible and menu_toggle.visible, "Expected formal entry to collapse the test menu")
	var formal_instance := mode_host.get_child(0)
	menu_toggle.pressed.emit()
	_expect(mode_panel.visible and menu_toggle.text == "收起测试面板", "Expected toggle to expand the test menu")
	_expect(mode_host.get_child(0) == formal_instance, "Expected expansion to preserve the active match instance")
	menu_toggle.pressed.emit()
	_expect(not mode_panel.visible and menu_toggle.text == "展开测试面板", "Expected toggle to collapse again")
	touch_button.pressed.emit()
	_expect(mode_panel.visible and not menu_toggle.visible, "Expected returning to a demo to restore the full test menu")
	_expect(
		menu.current_mode == GameModeController.Mode.TOUCH_AND_DRIBBLE,
		"Expected touch and dribble mode",
	)
	_expect(mode_host.get_child_count() == 1, "Expected one touch mode scene")
	var touch_demo := mode_host.get_child(0) as GameBootstrap
	_expect(
		touch_demo != null and touch_demo.demo_mode == GameBootstrap.DemoMode.TOUCH_AND_DRIBBLE,
		"Expected single-player touch scene",
	)
	pass_button.pressed.emit()
	_expect(menu.current_mode == GameModeController.Mode.PASS_AND_SHOOT, "Expected pass mode")
	_expect(mode_host.get_child_count() == 1, "Expected one pass mode scene")
	menu.queue_free()


## Checks that touch mode excludes team keys and resets on the next fixed step.
func test_touch_dribble_mode_when_reset_keeps_one_player() -> void:
	_started_snapshots.clear()
	_actions.clear()
	var bootstrap := GameBootstrap.new()
	bootstrap.demo_mode = GameBootstrap.DemoMode.TOUCH_AND_DRIBBLE
	var keyboard := KeyboardPlayerInputAdapter.new()
	keyboard.name = "KeyboardPlayerInputAdapter"
	bootstrap.add_child(keyboard)
	bootstrap.game_started.connect(_record_start)
	keyboard.action_requested.connect(_record_action)
	root.add_child(bootstrap)
	_expect(_started_snapshots.size() == 1, "Expected touch demo to start")
	if _started_snapshots.is_empty():
		bootstrap.queue_free()
		return
	var initial_snapshot := _started_snapshots[0]
	_expect(initial_snapshot.players.size() == 1, "Expected only one test player")
	_expect(
		initial_snapshot.ball.position_m == GameBootstrap.TEST_BALL_INITIAL_POSITION_M,
		"Expected free ball at test position",
	)
	_press_key(keyboard, KEY_J)
	_press_key(keyboard, KEY_TAB)
	_expect(_actions.is_empty(), "Expected pass and player switch unavailable")
	_press_key(keyboard, KEY_QUOTELEFT)
	bootstrap._process(bootstrap.fixed_delta_seconds)
	var reset_snapshot := bootstrap._match_simulation.create_snapshot()
	_expect(reset_snapshot.players.size() == 1, "Expected one player after reset")
	_expect(reset_snapshot.ball.position_m == GameBootstrap.TEST_BALL_INITIAL_POSITION_M,
		"Expected ball to return to its initial position")
	var did_reset := false
	for event in bootstrap.get_event_history():
		if event.event_type == MatchEvent.Type.RESET_COMPLETED:
			did_reset = true
	_expect(did_reset, "Expected reset completion after the queued fixed step")
	bootstrap.queue_free()


## Sends one keyboard event through the real input adapter.
func _press_key(adapter: KeyboardPlayerInputAdapter, key_code: int) -> void:
	var key_event := InputEventKey.new()
	key_event.keycode = key_code
	key_event.pressed = true
	adapter._unhandled_key_input(key_event)


## Collects startup snapshots emitted by the bootstrap.
func _record_start(snapshot: MatchStateSnapshot) -> void:
	_started_snapshots.append(snapshot)


## Collects actions proposed by keyboard input without altering the match.
func _record_action(action: MatchAction) -> void:
	_actions.append(action)


## Records one assertion for the test exit code.
func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
