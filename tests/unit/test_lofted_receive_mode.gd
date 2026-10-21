## Checks the playable high-pass mode and J input without inspecting rendered pixels.
extends SceneTree

var _failures: PackedStringArray = []


## Opens the replacement menu mode and drives its keyboard pass to a teammate shot.
func _init() -> void:
	call_deferred("_run")


## Uses the production scene and input adapter while observing only match facts.
func _run() -> void:
	var packed := load("res://scenes/main/game_modes.tscn") as PackedScene
	_check(packed != null, "Game mode scene must load")
	if packed == null:
		_finish()
		return
	var menu := packed.instantiate() as GameModeController
	root.add_child(menu)
	var button := menu.get_node(
		"ModeUi/ModePanel/ModeButtons/LoftedReceiveAerialShotTestButton") as Button
	_check(button != null, "Replacement mode button must exist")
	if button != null:
		button.pressed.emit()
	_check(menu.current_mode == GameModeController.Mode.LOFTED_RECEIVE_AERIAL_SHOT_TEST,
		"Replacement mode must become active")
	var bootstrap := menu.get_node("ModeHost").get_child(0) as GameBootstrap
	_check(bootstrap != null, "Replacement mode must use GameBootstrap")
	if bootstrap != null:
		var keyboard := bootstrap.get_node("KeyboardPlayerInputAdapter") as KeyboardPlayerInputAdapter
		var press := InputEventKey.new()
		press.keycode = KEY_J
		press.pressed = true
		keyboard._unhandled_key_input(press)
		for step in range(360):
			bootstrap._process(bootstrap.fixed_delta_seconds * 0.5)
			if _has_teammate_shot(bootstrap):
				break
		_check(_has_teammate_shot(bootstrap),
			"J must lead to the teammate's aerial shot")
		if _has_teammate_shot(bootstrap):
			var shot_ball := bootstrap._match_simulation.create_snapshot().ball
			var shot_x := shot_ball.position_m.x
			_check(shot_ball.motion_state == BallMatchState.MotionState.IN_FLIGHT,
				"The playable scene must release the shot ball")
			for step in range(12):
				bootstrap._process(bootstrap.fixed_delta_seconds * 0.5)
			_check(bootstrap._match_simulation.create_snapshot().ball.position_m.x
				> shot_x + 0.5, "The playable scene's shot ball must keep moving")
		for event in bootstrap.get_event_history():
			_check(event.event_type != MatchEvent.Type.BALL_HEADED,
				"Playable replacement mode must not perform a header")
	menu.queue_free()
	await process_frame
	_finish()


## Detects the committed teammate shot rather than relying on an animation frame.
func _has_teammate_shot(bootstrap: GameBootstrap) -> bool:
	for event in bootstrap.get_event_history():
		if event.event_type == MatchEvent.Type.BALL_SHOT and (
			event.subject_id == bootstrap.demo_teammate_id
		):
			return true
	return false


## Records an independent mode or event mismatch.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Completes the non-rendering integration check.
func _finish() -> void:
	if _failures.is_empty():
		print("PASS: lofted receive mode")
	else:
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)
