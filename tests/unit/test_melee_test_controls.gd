## Verifies real shared controls, attribute binding and committed melee feedback without rendering.
extends SceneTree

var _failures: PackedStringArray = []

## Waits for the real shared scene to become available.
func _init() -> void:
	call_deferred("_run")

## Exercises formula presets, typed fields, validation, ownership, both directions and replay.
func _run() -> void:
	var packed := load("res://scenes/main/game_bootstrap.tscn") as PackedScene
	var bootstrap := packed.instantiate() as GameBootstrap
	bootstrap.demo_mode = GameBootstrap.DemoMode.KNOCKDOWN_TEST
	root.add_child(bootstrap)
	bootstrap.set_process(false)
	var controls := bootstrap.get_node("MeleeControls") as MeleeTestControls
	_check(controls.visible, "melee controls share the existing scene")
	var values := bootstrap.get_melee_test_attributes()
	_check(controls._attack.text == str(values[0]) and controls._defense.text == str(values[1]) and controls._technique.text == str(values[2]), "initial values reflect actual runtime definitions")
	_check(bootstrap.melee_override == MatchSimulation.MeleeOutcome.FORMULA, "normal mode defaults to real formulas")
	var original := FileAccess.get_file_as_string("res://resources/data/players.csv")
	for reverse: bool in [false, true]:
		for owned: bool in [false, true]:
			controls._reverse.button_pressed = reverse
			controls._owner.button_pressed = owned
			for preset: int in [1, 2, 3, 4]:
				var button := _button(controls, ["预设：进攻者胜", "预设：目标胜", "预设：平局", "预设：闪避"][preset - 1])
				_check(button != null, "actual preset button exists")
				if button == null:
					continue
				button.pressed.emit()
				bootstrap.set_process(false)
				var result := _advance(bootstrap)
				_check(result != null, "preset reaches actual legal contact")
				if result == null:
					continue
				var expected: int = [MeleeContestResult.Outcome.ATTACKER_WIN, MeleeContestResult.Outcome.TARGET_WIN, MeleeContestResult.Outcome.DRAW, MeleeContestResult.Outcome.DODGED][preset - 1]
				_check(result.outcome == expected and not result.is_override, "preset selects attributes/samples, not a forced outcome")
				_check(result.direction == (Vector2.LEFT if reverse else Vector2.RIGHT), "left/right preset direction")
				_check(not controls._status.text.is_empty() and controls._status.text.contains("F05"), "panel displays committed stage facts")
				var snapshot := bootstrap._match_simulation.create_snapshot()
				if preset == 4:
					_check(snapshot.get_player(bootstrap.demo_opponent_id).jump_phase != PlayerMatchState.JumpPhase.NONE, "real dodge preset starts flip for owned/unowned targets")
				var keeps_ball := owned and preset in [2, 4]
				_check(snapshot.ball.owner_player_id == (bootstrap.demo_opponent_id if keeps_ball else ""), "preset respects target possession")
	# Enter submission uses the same typed input path as the real Apply button.
	controls._attack.text = "75"
	controls._defense.text = "80"
	controls._technique.text = "70"
	controls._dodge.text = "0.99"
	controls._strength.text = "0.25"
	controls._override.select(0)
	controls._attack.text_submitted.emit("75")
	bootstrap.set_process(false)
	var result := _advance(bootstrap)
	_check(result != null and result.outcome == MeleeContestResult.Outcome.DRAW and result.has_strength_sample, "independent F06 equality sample draws")
	if result != null:
		_check(result.dodge_sample == 0.99 and result.strength_sample == 0.25, "phase inputs remain distinct")
	var old_simulation := bootstrap._match_simulation
	controls._attack.text = "101"
	_button(controls, "应用并攻击 / 固定种子重放").pressed.emit()
	_check(bootstrap._match_simulation == old_simulation and bootstrap.get_melee_test_attributes() == PackedInt32Array([75, 80, 70]), "invalid attribute does not rebuild or partially update")
	controls._attack.text = "75"
	controls._strength.text = "1"
	_button(controls, "应用并攻击 / 固定种子重放").pressed.emit()
	_check(bootstrap._match_simulation == old_simulation, "invalid sample does not mutate match")
	controls._strength.text = ""
	controls._dodge.text = ""
	controls._override.select(3)
	_button(controls, "应用并攻击 / 固定种子重放").pressed.emit()
	bootstrap.set_process(false)
	result = _advance(bootstrap)
	_check(result != null and result.is_override and result.outcome == MeleeContestResult.Outcome.DRAW and result.dodge_sample == -1.0 and not result.has_strength_sample, "explicit development override is labeled and invents no samples")
	controls._override.select(0)
	var signatures := PackedStringArray()
	for iteration in range(2):
		_button(controls, "应用并攻击 / 固定种子重放").pressed.emit()
		bootstrap.set_process(false)
		result = _advance(bootstrap)
		_check(result != null, "random shared input reaches contact")
		if result != null:
			signatures.append("%d/%s/%s" % [result.outcome, result.dodge_sample, result.strength_sample])
	_check(signatures.size() == 2 and signatures[0] == signatures[1], "same seed shared replay matches both samples")
	_check(FileAccess.get_file_as_string("res://resources/data/players.csv") == original, "typed test inputs never rewrite CSV")
	bootstrap.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("Melee controls failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Advances only the fixed-step simulation and consumes its first result event.
func _advance(bootstrap: GameBootstrap) -> MeleeContestResult:
	for step in range(90):
		bootstrap._process(bootstrap.fixed_delta_seconds)
		for event in bootstrap.get_event_history():
			if event.event_type == MatchEvent.Type.MELEE_CONTEST_RESOLVED:
				return event.melee_contest
	return null

## Locates actual visible controls by their user-facing action label.
func _button(node: Node, title: String) -> Button:
	if node is Button and (node as Button).text == title:
		return node as Button
	for child in node.get_children():
		var found := _button(child, title)
		if found != null:
			return found
	return null

## Collects independent nonvisual integration failures.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
