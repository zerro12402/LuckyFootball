## Verifies the real mode scene routes M into presentation state without drawing pixels.
extends SceneTree

var _failures: PackedStringArray = []


## Runs the live input-routing check after the scene tree starts.
func _init() -> void:
	call_deferred("_run_test")


## Verifies that successive M presses toggle the field overlay through the full scene wiring.
func _run_test() -> void:
	var menu := (load("res://scenes/main/game_modes.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	var bootstrap := menu.get_node("ModeHost").get_child(0) as GameBootstrap
	var keyboard := bootstrap.get_node("KeyboardPlayerInputAdapter") as KeyboardPlayerInputAdapter
	var field := bootstrap.get_node("FieldEnvironment") as FieldEnvironment
	var overlay := field.get_node("DebugOverlay") as FieldDebugOverlay
	_expect(field.field_definition != null, "Expected the demo field to be configured")
	_expect(keyboard.is_processing_unhandled_key_input(), "Expected test input to be enabled")
	_expect(not overlay.are_meter_ticks_enabled, "Expected metre ticks to start hidden")
	_press_m()
	await process_frame
	_expect(overlay.are_meter_ticks_enabled, "Expected first M press to show metre ticks")
	_press_m()
	await process_frame
	_expect(not overlay.are_meter_ticks_enabled, "Expected second M press to hide metre ticks")
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## Sends a keyboard event through the active scene tree instead of calling the adapter directly.
func _press_m() -> void:
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_M
	key_event.physical_keycode = KEY_M
	key_event.pressed = true
	root.push_input(key_event)


## Collects failed routing assertions for a reliable test exit code.
func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
