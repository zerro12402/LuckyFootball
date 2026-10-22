## Verifies F01 proportional movement, definition binding and shared-mode CSV wiring without rendering.
extends SceneTree

var _config: MatchConfigDefinition
var _failures: PackedStringArray = []

## Defers the shared-mode check until the tree is ready; pure simulation cases use no nodes.
func _init() -> void:
	call_deferred("_run")

## Covers proportional displacement, state modifiers, bad inputs and production assembly.
func _run() -> void:
	_config = MatchConfigDataRepository.new().load_from_csv(
		"res://resources/data/match_configs.csv").configs[0]
	_test_proportional_displacement()
	_test_possession_diagonal_pause_and_reset()
	_test_invalid_definition_and_explicit_fixture()
	_test_config_validation()
	_test_shared_mode_uses_csv_speed()
	_test_touch_mode_speed_input()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: F01 proportional speed")
	quit(0 if _failures.is_empty() else 1)

## Fixed-step distance ratios must equal attribute ratios, with no additive speed offset.
func _test_proportional_displacement() -> void:
	var distances: Dictionary[int, float] = {}
	for speed in [1, 75, 80, 90, 100]:
		var definition := _definition(speed)
		var simulation := MatchSimulation.new(7, _config)
		_check(simulation.register_player_from_definition(definition, Vector2.ZERO, "blue"),
			"Valid speed definition must register")
		simulation.start_match()
		for step in range(60):
			simulation.advance_fixed_step(1.0 / 60.0, [
				MatchAction.new(definition.player_id, MatchAction.Type.MOVE, Vector2.RIGHT)])
		var player := simulation._player_runtime_system.get_player(definition.player_id)
		distances[speed] = player.state.position_m.x
		_check(is_equal_approx(distances[speed], _config.player_speed_at_100_mps * speed / 100.0),
			"One-second displacement must be proportional to speed")
		_check(player.speed_attribute == speed and definition.speed == speed,
			"Movement must preserve both runtime and CSV base attributes")
	_check(is_equal_approx(distances[100] / distances[75], 100.0 / 75.0),
		"Speed 100 versus 75 must retain the exact 4:3 ratio")
	var first := _run_trace(92)
	var second := _run_trace(92)
	_check(first.is_equal_approx(second), "Same speed, seed and commands must replay identically")

## Existing possession and movement rules apply after the base speed, exactly once.
func _test_possession_diagonal_pause_and_reset() -> void:
	var definition := _definition(80)
	var simulation := MatchSimulation.new(7, _config)
	simulation.register_player_from_definition(definition, Vector2.ZERO, "blue")
	simulation.register_ball(Vector2(0.55, 0.0))
	simulation.start_match()
	simulation.advance_fixed_step(0.01, [])
	simulation.advance_fixed_step(1.0, [
		MatchAction.new(definition.player_id, MatchAction.Type.MOVE, Vector2.ONE)])
	var player := simulation._player_runtime_system.get_player(definition.player_id)
	_check(is_equal_approx(player.state.position_m.length(), 4.0 * 0.9),
		"Diagonal dribbling must normalize direction and apply the 0.9 modifier once")
	var before := player.state.position_m
	simulation.pause_match()
	simulation.advance_fixed_step(1.0, [])
	_check(player.state.position_m == before, "Pause must freeze attribute-based movement")
	player.reset_to_spawn()
	_check(player.speed_attribute == 80 and is_equal_approx(player.state_machine.movement_speed_mps, 4.0),
		"Reset must preserve the base attribute and mapped movement speed")

## Formal definition registration rejects missing/invalid speed; explicit meter-speed tests stay usable.
func _test_invalid_definition_and_explicit_fixture() -> void:
	var simulation := MatchSimulation.new(7, _config)
	_check(not simulation.register_player_from_definition(null, Vector2.ZERO, "blue"),
		"Missing definition must be rejected")
	for speed in [0, 101]:
		_check(not simulation.register_player_from_definition(_definition(speed), Vector2.ZERO, "blue"),
			"Out-of-range speed must be rejected")
	_check(not simulation.register_player_from_definition(_definition(75), Vector2(INF, 0), "blue"),
		"Invalid spawn must not register a player")
	_check(simulation.register_player("fixture", Vector2.ZERO, 7.0), "Explicit fixture must register")
	var player := simulation._player_runtime_system.get_player("fixture")
	_check(player.speed_attribute == 0 and player.state_machine.movement_speed_mps == 7.0,
		"Explicit fixture must retain its meter speed without pretending to bind CSV data")
	_check(not MatchSimulation.new(7).register_player_from_definition(_definition(75), Vector2.ZERO, "blue"),
		"Attribute-based registration requires a match configuration")

## The editable baseline must be positive/finite; old configuration fixtures receive the explicit default.
func _test_config_validation() -> void:
	var original := FileAccess.get_file_as_string("res://resources/data/match_configs.csv")
	var path := "user://f01_config.csv"
	for value in ["0", "-1", "nan", "inf", "8.0"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(original.replace("player_speed_at_100_mps,5.0,",
			"player_speed_at_100_mps," + value + ","))
		file.close()
		var result := MatchConfigDataRepository.new().load_from_csv(path)
		_check(result.is_success == (value == "8.0"), "Invalid F01 baseline must be rejected")
		if result.is_success:
			var simulation := MatchSimulation.new(7, result.configs[0])
			simulation.register_player_from_definition(_definition(75), Vector2.ZERO, "blue")
			simulation.start_match()
			simulation.advance_fixed_step(1.0, [MatchAction.new("runner_75", MatchAction.Type.MOVE, Vector2.RIGHT)])
			_check(is_equal_approx(simulation.create_snapshot().get_player("runner_75").position_m.x, 6.0),
				"Changing the CSV baseline must change actual displacement")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var old := MatchConfigDataRepository.new().load_from_csv("res://tests/fixtures/match_configs_reordered_keys.csv")
	_check(old.is_success and old.configs[0].player_speed_at_100_mps == 5.0,
		"Old explicit fixtures must retain the compatible baseline")

## The production bootstrap must bind every displayed CSV player's speed rather than a fixed 5 m/s.
func _test_shared_mode_uses_csv_speed() -> void:
	var definitions := PlayerDataRepository.new().load_from_csv("res://resources/data/players.csv").players
	var bootstrap := (load("res://scenes/main/game_bootstrap.tscn") as PackedScene).instantiate() as GameBootstrap
	root.add_child(bootstrap)
	bootstrap.set_process(false)
	for definition in definitions:
		_check(definition.speed >= 75 and definition.speed <= 100, "Production speed must stay within 75–100")
		var player := bootstrap._match_simulation._player_runtime_system.get_player(definition.player_id)
		if player == null:
			continue
		_check(player.speed_attribute == definition.speed, "Shared mode must read the actual CSV speed")
		_check(is_equal_approx(player.state_machine.movement_speed_mps,
			_config.player_speed_at_100_mps * definition.speed / 100.0), "Shared mode must apply F01")
	bootstrap.free()


## Drives the real input/button signals and checks temporary overrides across resets and mode switches.
func _test_touch_mode_speed_input() -> void:
	var menu := (load("res://scenes/main/game_modes.tscn") as PackedScene).instantiate() as GameModeController
	root.add_child(menu)
	menu.show_mode(GameModeController.Mode.TOUCH_AND_DRIBBLE)
	var bootstrap := menu.get_node("ModeHost").get_child(0) as GameBootstrap
	bootstrap.set_process(false)
	var input := bootstrap.get_node("%TouchSpeedInput") as LineEdit
	var button := bootstrap.get_node("%TouchSpeedApplyButton") as Button
	var original_speed := bootstrap.data_repository.get_player_by_id(bootstrap.demo_player_id).speed
	_check((bootstrap.get_node("TouchSpeedControls") as CanvasLayer).visible,
		"Touch mode must expose the speed input")
	_check(input.text == str(original_speed), "Input must initially show CSV speed")
	input.text = "75"
	button.pressed.emit()
	bootstrap.set_process(false)
	var player := bootstrap._match_simulation._player_runtime_system.get_player(bootstrap.demo_player_id)
	_check(player.speed_attribute == 75 and is_equal_approx(player.state_machine.movement_speed_mps, 3.75),
		"Apply button must rebuild with the manually entered F01 speed")
	bootstrap._match_simulation.advance_fixed_step(0.1, [MatchAction.new(
		bootstrap.demo_player_id, MatchAction.Type.MOVE, Vector2.RIGHT)])
	_check(is_equal_approx(player.state.position_m.x, 0.375), "Entered speed must affect actual movement")
	for invalid in ["74", "101", "80.5", "", "abc"]:
		var simulation := bootstrap._match_simulation
		input.text = invalid
		button.pressed.emit()
		_check(bootstrap._match_simulation == simulation and player.speed_attribute == 75,
			"Invalid input must not reset the test or change speed")
	input.text = "100"
	input.text_submitted.emit(input.text)
	bootstrap.set_process(false)
	bootstrap.reset_demo()
	bootstrap.set_process(false)
	player = bootstrap._match_simulation._player_runtime_system.get_player(bootstrap.demo_player_id)
	_check(player.speed_attribute == 100 and input.text == "100",
		"Enter must apply; ordinary reset must preserve the entered speed")
	_check(bootstrap.data_repository.get_player_by_id(bootstrap.demo_player_id).speed == original_speed,
		"Test input must never rewrite the repository definition")
	menu.show_mode(GameModeController.Mode.PASS_AND_SHOOT)
	bootstrap = menu.get_node("ModeHost").get_child(0) as GameBootstrap
	bootstrap.set_process(false)
	_check(not (bootstrap.get_node("TouchSpeedControls") as CanvasLayer).visible,
		"Other modes must hide the speed controls")
	_check(not bootstrap.apply_touch_speed_for_test("75"), "Other modes must reject this override")
	menu.show_mode(GameModeController.Mode.TOUCH_AND_DRIBBLE)
	bootstrap = menu.get_node("ModeHost").get_child(0) as GameBootstrap
	bootstrap.set_process(false)
	player = bootstrap._match_simulation._player_runtime_system.get_player(bootstrap.demo_player_id)
	_check(player.speed_attribute == original_speed, "Reentering touch mode must restore the CSV speed")
	menu.free()

## Builds a complete explicit definition while varying only the speed under test.
func _definition(speed: int) -> PlayerDefinition:
	return PlayerDefinition.new("runner_" + str(speed), "测试", "forward", speed,
		50, 50, 50, 50, 50, 50, PackedStringArray(["a", "b", "c"]), "player_blue")

## Replays movement through the same fixed-step command protocol used by input and AI.
func _run_trace(speed: int) -> Vector2:
	var simulation := MatchSimulation.new(7, _config)
	var definition := _definition(speed)
	simulation.register_player_from_definition(definition, Vector2.ZERO, "blue")
	simulation.start_match()
	for step in range(60):
		simulation.advance_fixed_step(1.0 / 60.0, [MatchAction.new(
			definition.player_id, MatchAction.Type.MOVE, Vector2.ONE if step < 30 else Vector2.RIGHT)])
	return simulation.create_snapshot().get_player(definition.player_id).position_m

## Collects independent contract failures without masking later boundary cases.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
