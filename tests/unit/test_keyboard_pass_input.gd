## Verifies demo pass and reset keys without rendering or leaking test nodes.
extends SceneTree

var _actions: Array[MatchAction] = []
var _failures: PackedStringArray = []


## Checks one-shot keyboard commands and reports aggregated failures.
func _init() -> void:
	test_j_when_pressed_requests_pass_to_teammate()
	test_space_when_pressed_does_not_request_pass()
	test_tab_when_pressed_switches_pass_direction()
	test_tilde_key_when_pressed_requests_reset()

	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## Routes J to the active player and its teammate.
func test_j_when_pressed_requests_pass_to_teammate() -> void:
	_actions.clear()
	var adapter := _create_adapter()
	_press_key(adapter, KEY_J)
	_expect(_actions.size() == 1, "Expected one pass command")
	if _actions.size() != 1:
		adapter.free()
		return
	_expect(_actions[0].action_type == MatchAction.Type.PASS, "Expected PASS action")
	_expect(_actions[0].player_id == "player_a", "Expected current player as passer")
	_expect(
		_actions[0].target_player_id == "player_b",
		"Expected teammate as pass target",
	)
	adapter.free()


## Keeps Space unbound to passing.
func test_space_when_pressed_does_not_request_pass() -> void:
	_actions.clear()
	var adapter := _create_adapter()
	_press_key(adapter, KEY_SPACE)
	_expect(_actions.is_empty(), "Expected Space to be unbound")
	adapter.free()


## Updates the active player before the next pass.
func test_tab_when_pressed_switches_pass_direction() -> void:
	_actions.clear()
	var adapter := _create_adapter()
	_press_key(adapter, KEY_TAB)
	_press_key(adapter, KEY_J)
	_expect(_actions.size() == 2, "Expected stop and pass commands")
	if _actions.size() != 2:
		adapter.free()
		return
	_expect(
		_actions[0].action_type == MatchAction.Type.MOVE
		and _actions[0].direction == Vector2.ZERO,
		"Expected prior player to stop on control switch",
	)
	_expect(_actions[1].player_id == "player_b", "Expected teammate as new passer")
	_expect(
		_actions[1].target_player_id == "player_a",
		"Expected original player as return-pass target",
	)
	adapter.free()


## Recognizes physical and logical reset keys once per press.
func test_tilde_key_when_pressed_requests_reset() -> void:
	_actions.clear()
	var adapter := _create_adapter()
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_QUOTELEFT
	key_event.shift_pressed = true
	key_event.pressed = true
	adapter._unhandled_key_input(key_event)
	_expect(_actions.size() == 1, "Expected tilde key to submit one reset")
	_expect(_actions[0].action_type == MatchAction.Type.RESET_ROUND,
		"Expected tilde to reset the current round")
	key_event.echo = true
	adapter._unhandled_key_input(key_event)
	key_event.echo = false
	key_event.pressed = false
	adapter._unhandled_key_input(key_event)
	_expect(_actions.size() == 1, "Expected repeat and release events to be ignored")
	key_event.physical_keycode = KEY_NONE
	key_event.keycode = KEY_ASCIITILDE
	key_event.pressed = true
	adapter._unhandled_key_input(key_event)
	_expect(_actions.size() == 2, "Expected logical tilde key to request reset")
	key_event.ctrl_pressed = true
	adapter._unhandled_key_input(key_event)
	_expect(_actions.size() == 3
		and _actions[2].action_type == MatchAction.Type.RESTART_TEST,
		"Expected Ctrl+tilde to restart the test")
	adapter.free()


## Connects a fresh input adapter to test recorders.
func _create_adapter() -> KeyboardPlayerInputAdapter:
	var adapter := KeyboardPlayerInputAdapter.new()
	adapter.action_requested.connect(_record_action)
	adapter.configure("player_a", "player_b")
	return adapter


## Delivers one key-down event directly to the adapter.
func _press_key(adapter: KeyboardPlayerInputAdapter, key_code: int) -> void:
	var key_event := InputEventKey.new()
	key_event.keycode = key_code
	key_event.pressed = true
	adapter._unhandled_key_input(key_event)


## Captures emitted typed match actions.
func _record_action(action: MatchAction) -> void:
	_actions.append(action)


## Collects failures without stopping later keyboard cases.
func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
