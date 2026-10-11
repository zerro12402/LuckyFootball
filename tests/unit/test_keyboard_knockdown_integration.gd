## Reproduces the L-key flow through the knockdown test scene without rendering.
extends SceneTree

var _snapshot: MatchStateSnapshot
var _accepted_count: int = 0
var _impact_count: int = 0
var _failures: PackedStringArray = []


## Enters the real test scene after SceneTree initialization.
func _init() -> void:
	call_deferred("_run_test")


## Presses L on the configured adapter and advances the same demo loop as gameplay.
func _run_test() -> void:
	var packed_scene := load("res://scenes/main/game_modes.tscn") as PackedScene
	_expect(packed_scene != null, "Game mode menu failed to load")
	if packed_scene == null:
		_finish()
		return
	var menu := packed_scene.instantiate() as GameModeController
	root.add_child(menu)
	await process_frame
	var button := menu.get_node(
		"ModeUi/ModePanel/ModeButtons/KnockdownTestButton"
	) as Button
	_expect(button != null, "Knockdown mode button is missing")
	button.pressed.emit()
	await process_frame
	var bootstrap := menu.get_node("ModeHost").get_child(0) as GameBootstrap
	_expect(menu.current_mode == GameModeController.Mode.KNOCKDOWN_TEST,
		"Knockdown button did not select its mode")
	bootstrap.presentation_frame_ready.connect(_record_frame)
	_snapshot = bootstrap.get("_match_simulation").create_snapshot()
	_expect(_snapshot != null, "Knockdown demo did not start")
	var keyboard := bootstrap.get_node("KeyboardPlayerInputAdapter") as KeyboardPlayerInputAdapter
	_expect(keyboard != null, "Knockdown demo is missing keyboard adapter")
	if keyboard != null:
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_L
		key_event.pressed = true
		Input.parse_input_event(key_event)
		await process_frame
		for step_index in range(15):
			bootstrap._process(bootstrap.fixed_delta_seconds)
	_expect(_accepted_count > 0, "L did not produce an accepted action")
	_expect(_impact_count == 1, "L did not knock down the opponent exactly once")
	menu.queue_free()
	_finish()


## Counts structured events from actual bootstrap frames.
func _record_frame(snapshot: MatchStateSnapshot, events: Array[MatchEvent], _alpha: float) -> void:
	_snapshot = snapshot
	for event in events:
		if event.event_type == MatchEvent.Type.ACTION_ACCEPTED:
			_accepted_count += 1
		elif event.event_type == MatchEvent.Type.PLAYER_KNOCKED_DOWN:
			_impact_count += 1


## Accumulates actionable diagnostics.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Exits with failure if key input or contact never becomes visible.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
