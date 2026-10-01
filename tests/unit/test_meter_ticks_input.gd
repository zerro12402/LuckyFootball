## Verifies the M shortcut requests display ticks without submitting a match action.
extends SceneTree

var _toggle_count: int = 0
var _action_count: int = 0
var _failures: PackedStringArray = []


## Runs the keyboard contract checks and reports any failed assertion.
func _init() -> void:
	test_m_when_pressed_requests_one_toggle()
	test_m_repeat_and_release_do_not_toggle_again()
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## Ensures the display shortcut never reaches the match command queue.
func test_m_when_pressed_requests_one_toggle() -> void:
	_toggle_count = 0
	_action_count = 0
	var adapter := _create_adapter()
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_M
	key_event.pressed = true
	adapter._unhandled_key_input(key_event)
	_expect(_toggle_count == 1, "Expected M to request one tick toggle")
	_expect(_action_count == 0, "Expected M to avoid match actions")
	adapter.free()


## Ignores held-key repeats and release so each press changes visibility once.
func test_m_repeat_and_release_do_not_toggle_again() -> void:
	_toggle_count = 0
	var adapter := _create_adapter()
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_M
	key_event.pressed = true
	adapter._unhandled_key_input(key_event)
	key_event.echo = true
	adapter._unhandled_key_input(key_event)
	key_event.echo = false
	key_event.pressed = false
	adapter._unhandled_key_input(key_event)
	_expect(_toggle_count == 1, "Expected repeat and release to be ignored")
	adapter.free()


## Connects the adapter signals without adding a live scene or rendering a frame.
func _create_adapter() -> KeyboardPlayerInputAdapter:
	var adapter := KeyboardPlayerInputAdapter.new()
	adapter.meter_ticks_toggle_requested.connect(_record_toggle)
	adapter.action_requested.connect(_record_action)
	adapter.configure("player_a", "player_b")
	return adapter


## Counts requested display changes for the input assertions.
func _record_toggle() -> void:
	_toggle_count += 1


## Counts accidental match commands from the display shortcut.
func _record_action(_action: MatchAction) -> void:
	_action_count += 1


## Collects failed business assertions before exiting the test script.
func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
