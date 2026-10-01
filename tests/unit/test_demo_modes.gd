extends SceneTree

var _started_snapshots: Array[MatchStateSnapshot] = []
var _actions: Array[MatchAction] = []
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run_tests")


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
	touch_button.pressed.emit()
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
	_expect(_started_snapshots.size() == 2, "Expected reset to restart touch mode")
	_expect(_started_snapshots[1].players.size() == 1, "Expected one player after reset")
	_expect(_started_snapshots[1].simulation_step == 0, "Expected fresh simulation")
	bootstrap.queue_free()


func _press_key(adapter: KeyboardPlayerInputAdapter, key_code: int) -> void:
	var key_event := InputEventKey.new()
	key_event.keycode = key_code
	key_event.pressed = true
	adapter._unhandled_key_input(key_event)


func _record_start(snapshot: MatchStateSnapshot) -> void:
	_started_snapshots.append(snapshot)


func _record_action(action: MatchAction) -> void:
	_actions.append(action)


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
