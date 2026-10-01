## Verifies that test keyboard input emits typed shots without scene rendering.
extends SceneTree

var _actions: Array[MatchAction] = []
var _failures: PackedStringArray = []


## Exercises default, held-direction, repeat, and control-switch shot commands.
func _init() -> void:
	test_k_requests_full_power_shot_to_default_right()
	test_held_direction_overrides_previous_aim()
	test_key_repeat_does_not_emit_duplicate_shot()
	test_tab_changes_shooter()
	test_touch_only_mode_does_not_emit_shot()
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


## Lets the demo shoot immediately before any movement command.
func test_k_requests_full_power_shot_to_default_right() -> void:
	_actions.clear()
	var adapter := _create_adapter()
	_press_key(adapter, KEY_K)
	_expect(_actions.size() == 1, "K should emit one shot")
	if _actions.size() == 1:
		_expect(_actions[0].action_type == MatchAction.Type.SHOOT, "K did not emit SHOOT")
		_expect(_actions[0].direction == Vector2.RIGHT, "Initial aim should be right")
		_expect(is_equal_approx(_actions[0].power, 1.0), "Demo shot power should be full")
		_expect(_actions[0].player_id == "player_a", "Wrong shooter ID")
	adapter.free()


## Reads held movement input when K is pressed rather than waiting for _process.
func test_held_direction_overrides_previous_aim() -> void:
	_actions.clear()
	var adapter := _create_adapter()
	Input.action_press(&"move_up")
	_press_key(adapter, KEY_K)
	Input.action_release(&"move_up")
	_expect(_actions.size() == 1, "Held up and K should emit one shot")
	if _actions.size() == 1:
		_expect(_actions[0].direction == Vector2.UP, "Held up should aim upward")
	_actions.clear()
	_press_key(adapter, KEY_K)
	_expect(_actions.size() == 1 and _actions[0].direction == Vector2.UP,
		"Shot should retain last nonzero aim after release")
	adapter.free()


## Rejects operating-system key repeat as a second shot request.
func test_key_repeat_does_not_emit_duplicate_shot() -> void:
	_actions.clear()
	var adapter := _create_adapter()
	var event := InputEventKey.new()
	event.keycode = KEY_K
	event.pressed = true
	event.echo = true
	adapter._unhandled_key_input(event)
	_expect(_actions.is_empty(), "Key repeat emitted a shot")
	adapter.free()


## Uses the newly controlled teammate's player ID after Tab.
func test_tab_changes_shooter() -> void:
	_actions.clear()
	var adapter := _create_adapter()
	_press_key(adapter, KEY_TAB)
	_press_key(adapter, KEY_K)
	_expect(_actions.size() == 2, "Tab then K should emit stop and shoot")
	if _actions.size() == 2:
		_expect(_actions[1].player_id == "player_b", "Tab did not switch shooter")
	adapter.free()


## Leaves the touch-and-dribble mode focused on its original controls.
func test_touch_only_mode_does_not_emit_shot() -> void:
	_actions.clear()
	var adapter := KeyboardPlayerInputAdapter.new()
	adapter.action_requested.connect(_record_action)
	adapter.configure("player_a")
	_press_key(adapter, KEY_K)
	_expect(_actions.is_empty(), "Touch-only mode emitted a shot")
	adapter.free()


## Connects the input signal to a typed command recorder.
func _create_adapter() -> KeyboardPlayerInputAdapter:
	var adapter := KeyboardPlayerInputAdapter.new()
	adapter.action_requested.connect(_record_action)
	adapter.configure("player_a", "player_b")
	return adapter


## Sends one key-down event directly to the input adapter.
func _press_key(adapter: KeyboardPlayerInputAdapter, key_code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key_code
	event.pressed = true
	adapter._unhandled_key_input(event)


## Captures the command without mutating match state.
func _record_action(action: MatchAction) -> void:
	_actions.append(action)


## Accumulates assertion failures across independent cases.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
