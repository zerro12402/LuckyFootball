## Checks shared-mode impact presets, button wiring and seeded replay without rendering.
extends SceneTree

var _failures: PackedStringArray = []

## Waits only for SceneTree availability before driving production input adapters.
func _init() -> void:
	call_deferred("_run")

## Uses the existing menu/bootstrap scenes and observes committed simulation facts.
func _run() -> void:
	var packed := load("res://scenes/main/game_modes.tscn") as PackedScene
	var menu := packed.instantiate() as GameModeController
	root.add_child(menu)
	menu.get_node("ModeUi/ModePanel/ModeButtons/BallImpactTestButton").pressed.emit()
	_check(menu.current_mode == GameModeController.Mode.BALL_IMPACT_TEST,
		"Menu must enter the new shared impact mode")
	var bootstrap := menu.get_node("ModeHost").get_child(0) as GameBootstrap
	_check(bootstrap.demo_mode == GameBootstrap.DemoMode.BALL_IMPACT_TEST,
		"Impact mode must use the shared GameBootstrap")
	bootstrap.set_process(false)
	var controls := bootstrap.get_node("BallImpactControls") as BallImpactTestControls
	_check(controls.visible, "Impact controls must be available only in their mode")
	var buttons: Array[String] = ["SweptDefendersButton", "BlockReboundButton",
		"ImpactContinueButton", "ImpactReboundButton", "WeakShotReboundButton"]
	for index in range(buttons.size()):
		controls.get_node("Panel/Buttons/" + buttons[index]).pressed.emit()
		bootstrap.set_process(false)
		_run_until_routes(bootstrap, 2 if index == 0 else 1)
		var impacts: Array[MatchEvent] = []
		for event in bootstrap.get_event_history():
			if event.event_type in [MatchEvent.Type.BALL_CONTINUED, MatchEvent.Type.BALL_REBOUNDED]:
				impacts.append(event)
		_check(impacts.size() == (2 if index == 0 else 1), "Preset must produce its intended contacts")
		if impacts.is_empty():
			continue
		var expected := (MatchEvent.Type.BALL_REBOUNDED if index in [1, 3, 4]
			else MatchEvent.Type.BALL_CONTINUED)
		_check(impacts[0].event_type == expected, "Preset seed must select its labeled route")
		_check(impacts[0].ball_impact.was_knocked_down == (index != 4),
			"Only the stronger defender must remain upright")
		_check(bootstrap._match_simulation.create_snapshot().ball.owner_player_id.is_empty(),
			"Impact presets must retain one unowned moving ball")
		var previous := _trace(bootstrap)
		controls.get_node("Panel/Buttons/ImpactReplayButton").pressed.emit()
		bootstrap.set_process(false)
		_run_until_routes(bootstrap, 2 if index == 0 else 1)
		_check(previous == _trace(bootstrap), "Replay button must reproduce the same event facts")
	controls.get_node("Panel/Buttons/ImpactResetButton").pressed.emit()
	bootstrap.set_process(false)
	_check(bootstrap._match_simulation.create_snapshot().ball.owner_player_id
		== bootstrap.demo_player_id, "Reset must restore the shooter's unique possession")
	var key := InputEventKey.new()
	key.keycode = KEY_K
	key.pressed = true
	(bootstrap.get_node("KeyboardPlayerInputAdapter") as KeyboardPlayerInputAdapter
		)._unhandled_key_input(key)
	_run_until_routes(bootstrap, 1)
	_check(_trace(bootstrap).contains(str(MatchEvent.Type.BALL_SHOT) + ":"),
		"K must submit the ordinary shooting action")
	menu.show_mode(GameModeController.Mode.TOUCH_AND_DRIBBLE)
	var touch := menu.get_node("ModeHost").get_child(0) as GameBootstrap
	_check(not (touch.get_node("BallImpactControls") as CanvasLayer).visible,
		"Impact controls must hide after a mode switch")
	menu.free()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: ball impact shared mode")
	quit(0 if _failures.is_empty() else 1)

## Advances exact fixed steps up to the requested number of committed route results.
func _run_until_routes(bootstrap: GameBootstrap, count: int) -> void:
	for step in range(240):
		bootstrap._process(bootstrap.fixed_delta_seconds)
		var routes := 0
		for event in bootstrap.get_event_history():
			if event.event_type in [MatchEvent.Type.BALL_CONTINUED, MatchEvent.Type.BALL_REBOUNDED]:
				routes += 1
		if routes >= count:
			return
	_check(false, "Preset did not produce the expected route count")

## Serializes immutable event data, including actual samples and before/after velocity.
func _trace(bootstrap: GameBootstrap) -> String:
	var trace := ""
	for event in bootstrap.get_event_history():
		trace += "%s:%s:%s:%s;" % [event.event_type, event.subject_id,
			event.target_player_id, event.simulation_step]
		if event.ball_impact != null:
			trace += str(event.ball_impact.route_sample) + str(event.velocity_after_mps)
	return trace

## Records a mode contract mismatch independently of scene visuals.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
