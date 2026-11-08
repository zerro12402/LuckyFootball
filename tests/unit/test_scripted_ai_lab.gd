## Runs the public editor, documented scripts and same-seed comparison through the real mode entry.
extends SceneTree

var _failures: PackedStringArray = []


## Defers scene assembly until the nonvisual scene tree is ready.
func _init() -> void:
	call_deferred("_run")


## Validates manual examples, runs a separately authored strategy, and checks binding and replay.
func _run() -> void:
	var scene := load("res://scenes/main/game_modes.tscn") as PackedScene
	var menu := scene.instantiate() as GameModeController
	root.add_child(menu)
	var lab := menu.get_node("%PlayerAIScriptLab") as PlayerAIScriptLab
	var lab_button := menu.get_node("%ScriptLabButton") as Button
	var test_menu := menu.get_node("%ModePanel") as PanelContainer
	_check(lab_button.is_visible_in_tree() and not test_menu.visible, "Lab entry is available with F1 panels hidden")
	lab_button.pressed.emit()
	var editor := lab.get_node("%Editor") as PanelContainer
	var viewport: Vector2 = lab.get_viewport_rect().size
	_check(editor.position.x >= 0.0 and editor.position.y >= 0.0
		and editor.position.x + editor.size.x <= viewport.x
		and editor.position.y + editor.size.y <= viewport.y,
		"The editor stays fully inside the viewport")
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	menu._input(f1)
	menu._input(f1)
	_check(lab.visible and lab_button.is_visible_in_tree() and not test_menu.visible,
		"F1 changes the test menu without closing the public lab")
	var initial := menu._active_mode_scene as FormalMatchBootstrap
	var seed_value := initial.get_snapshot().random_seed
	var commands := lab.get_node("Editor/Scroll/Rows/Commands")
	_check(commands.get_child_count() == 4, "The editor has only four action buttons")
	lab_button.pressed.emit()
	_check(not lab.is_editor_open() and menu._active_mode_scene == initial,
		"The lab entrance closes the editor without replacing the match")
	lab_button.pressed.emit()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	menu._input(escape)
	_check(not lab.is_editor_open() and menu._active_mode_scene == initial,
		"Escape closes the editor without replacing the match")
	lab_button.pressed.emit()
	_validate_examples()
	_test_save_manual(lab)

	# Acceptance strategy authored from the public manual: take a shot inside six metres, otherwise dribble.
	var tactic := """{
		"version": 1,
		"rules": [
			{"when": [["has.shoot", "==", true], ["self.goal_distance_m", "<=", 6]],
			 "then": {"behavior": "shoot", "target": ""}},
			{"when": [["has.dribble", "==", true]], "then": {"behavior": "dribble", "target": ""}}
		],
		"default": {}
	}"""
	lab._source.text = tactic
	_check(lab.submit(tactic), "A strategy written from the manual passes the public submit flow")
	var program := lab._program
	_check(not lab.submit('{"version":3,"rules":[],"default":{}}') and lab._program == program,
		"Invalid submission does not replace the validated program")
	lab._run.pressed.emit()
	var first := menu._active_mode_scene as FormalMatchBootstrap
	_check(first != null and first.get_snapshot().phase == MatchState.Phase.RUNNING,
		"Starting from the lab uses the real formal lifecycle")
	var bound_id := first.scripted_player_id
	_check(not bound_id.is_empty() and first._production_ai._scripted_player_id == bound_id
		and first._production_ai._decision_strategy == program, "Only the selected forward has a bound strategy")
	_check(lab.submit('{"version":1,"rules":[],"default":{}}') and first._production_ai._decision_strategy == program,
		"Editing the accepted program cannot change an already running trial")
	var first_trace := _trace(first)

	lab._source.text = tactic
	lab._run.pressed.emit()
	var replay := menu._active_mode_scene as FormalMatchBootstrap
	_check(_trace(replay) == first_trace, "Same script and seed replay the same decisions and positions")
	menu.show_mode(GameModeController.Mode.FORMAL_MATCH, seed_value)
	var baseline := menu._active_mode_scene as FormalMatchBootstrap
	_check(baseline.get_snapshot().random_seed == seed_value and baseline.scripted_player_id.is_empty()
		and baseline._production_ai._decision_strategy == null, "Baseline uses the last trial seed and built-in AI")
	_check(baseline.get_snapshot().home_team_id == replay.get_snapshot().home_team_id
		and baseline.get_snapshot().away_team_id == replay.get_snapshot().away_team_id,
		"Baseline uses the same teams")
	_test_team_trial(menu, lab, seed_value)
	_test_overlay_trial(menu, lab, seed_value)
	_test_generation_guards(lab)
	_test_history(lab)
	menu.free()
	for failure in _failures:
		push_error(failure)
	print("Scripted AI lab failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)


## Verifies the selected destination receives exactly the bundled UTF-8 bytes.
func _test_save_manual(lab: PlayerAIScriptLab) -> void:
	var destination := "user://script_lab_manual_test_%s.md" % OS.get_process_id()
	var dialog := lab.get_node("%TeamManualSaveDialog") as FileDialog
	dialog.file_selected.emit(ProjectSettings.globalize_path(destination))
	var expected := FileAccess.get_file_as_bytes(PlayerAIScriptLab.TEAM_MANUAL_PATH)
	_check(not expected.is_empty() and FileAccess.get_file_as_bytes(destination) == expected,
		"The save dialog writes a standalone byte-identical v2 manual")
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))


## Uses the published team example for one binding, deterministic replay and an unbound baseline.
func _test_team_trial(menu: GameModeController, lab: PlayerAIScriptLab, seed_value: int) -> void:
	var text := FileAccess.get_file_as_string(PlayerAIScriptLab.TEAM_MANUAL_PATH)
	var sections := text.split("```json")
	_check(sections.size() == 2, "The v2 manual includes a runnable four-role script")
	if sections.size() != 2:
		return
	lab._source.text = sections[1].get_slice("```", 0)
	_check(lab.submit(lab._source.text), "The official editor accepts the v2 manual example")
	lab._run.pressed.emit()
	var formal := menu._active_mode_scene as FormalMatchBootstrap
	_check(formal.scripted_team_id == "home" and formal.scripted_player_id.is_empty()
		and formal._production_ai._decision_strategy == lab._program, "v2 binds one compiled program to the selected team")
	var first := _trace(formal)
	lab._run.pressed.emit()
	var replay := menu._active_mode_scene as FormalMatchBootstrap
	_check(_trace(replay) == first, "Team trial replays with identical actions and positions")
	menu.show_mode(GameModeController.Mode.FORMAL_MATCH, seed_value)
	var baseline := menu._active_mode_scene as FormalMatchBootstrap
	_check(baseline.get_snapshot().random_seed == seed_value and baseline.scripted_team_id.is_empty()
		and baseline._production_ai._decision_strategy == null, "Team baseline retains the seed and disables binding")


## Binds a version 3 overlay through the same team path and replays it deterministically.
func _test_overlay_trial(menu: GameModeController, lab: PlayerAIScriptLab, seed_value: int) -> void:
	var overlay := '{"version":3,"mode":"overlay","scope":{"role":"back"},"modifiers":[' \
		+ '{"when":[["phase","==","defend"]],"weights":{"tackle":0,"attack":2}}]}'
	lab._source.text = overlay
	_check(lab.submit(overlay), "A version 3 overlay passes submission")
	lab._run.pressed.emit()
	var formal := menu._active_mode_scene as FormalMatchBootstrap
	_check(formal.scripted_team_id == "home" and formal._production_ai._decision_strategy == lab._program,
		"A version 3 overlay binds the selected team")
	var first := _trace(formal)
	lab._run.pressed.emit()
	var replay := menu._active_mode_scene as FormalMatchBootstrap
	_check(_trace(replay) == first, "A version 3 overlay replays with identical actions and positions")
	menu.show_mode(GameModeController.Mode.FORMAL_MATCH, seed_value)
	var baseline := menu._active_mode_scene as FormalMatchBootstrap
	_check(baseline.get_snapshot().random_seed == seed_value and baseline.scripted_team_id.is_empty(),
		"Baseline clears the overlay binding with the same seed")


## Covers missing keys, secret handling, failed generation and cancellation states.
func _test_generation_guards(lab: PlayerAIScriptLab) -> void:
	var path := "user://test_lab_generation_%s.cfg" % OS.get_process_id()
	OS.set_environment(PlayerAISettings.ENV_NAME, "")
	lab._settings = PlayerAISettings.new(path)
	lab._tactic.text = "后卫防守时用冲撞不要铲球"
	lab._generate_from_text()
	_check(lab._diagnostic.text.contains("DeepSeek Key") and not lab._busy,
		"A missing key stops before any request")
	lab._api_key_input.text = "sk-secret-123456"
	lab._save_api_key()
	_check(not lab._diagnostic.text.contains("sk-secret-123456"), "Saving a key never echoes the secret")
	_check(lab._api_key_input.placeholder_text.contains("sk-s")
		and not lab._api_key_input.placeholder_text.contains("123456"),
		"The saved key is shown masked")
	var before := lab._program
	lab._finish_generation({"ok": false, "error_kind": "COMPILE", "error": "bad"})
	_check(lab._program == before, "A failed generation keeps the validated program")
	lab._busy = true
	lab._cancel_generation()
	_check(not lab._busy and lab._diagnostic.text.contains("取消"),
		"Cancelling clears the busy state without binding")
	lab._settings.clear_key()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Records a successful generation, then restores it from the option list without a request.
func _test_history(lab: PlayerAIScriptLab) -> void:
	var path := "user://test_lab_history_%s.json" % OS.get_process_id()
	lab._history = PlayerAIHistory.new(path)
	lab._refresh_history()
	lab._active_description = "后卫防守不要铲球"
	var json := '{"version":3,"mode":"overlay","scope":{"role":"back"},"modifiers":[' \
		+ '{"when":[["phase","==","defend"]],"weights":{"tackle":0}}]}'
	lab._finish_generation({"ok": true, "json": json, "attempts": 1})
	_check(lab._history.entries().size() == 1 and lab._history_option.item_count == 1,
		"A successful generation appears in the local history")
	lab._tactic.text = ""
	lab._source.text = ""
	lab._history_option.select(0)
	lab._load_selected_history()
	_check(lab._tactic.text == "后卫防守不要铲球" and lab._program != null
		and lab._program.interface_version() == 3,
		"Selecting history restores the prompt and the compiled script")
	lab._history.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Reads each published JSON block through the exact parser used by the editor.
func _validate_examples() -> void:
	var text := FileAccess.get_file_as_string("res://docs/player-ai-script-v1.md")
	var sections := text.split("```json")
	_check(sections.size() >= 3, "The published manual contains runnable examples")
	for index in range(1, sections.size()):
		var source := sections[index].get_slice("```", 0)
		_check(PlayerAIScript.compile(source).has("script"), "A public manual example passes validation")


## Compares committed positions and proposed actions, excluding only the generated match identity.
func _trace(formal: FormalMatchBootstrap) -> Array:
	formal.set_process(false)
	var trace: Array = []
	for step in range(240):
		formal._process(1.0 / 60.0)
		var snapshot := formal.get_snapshot()
		var positions: Array = []
		for player in snapshot.players:
			positions.append(player.position_m)
		var actions: Array = []
		for action in formal._production_ai.get_last_actions():
			actions.append([action.player_id, action.action_type, action.direction, action.target_player_id])
		trace.append([positions, snapshot.ball.position_m, snapshot.ball.owner_player_id, actions])
	return trace


## Collects focused lab and replay failures into the process result.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)