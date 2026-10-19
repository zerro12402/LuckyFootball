## Verifies aerial presets in the shared GameModes and GameBootstrap scenes.
extends SceneTree

const MENU_SCENE_PATH := "res://scenes/main/game_modes.tscn"

var _menu: GameModeController
var _bootstrap: GameBootstrap
var _events: Array[MatchEvent] = []
var _input_actions: Array[MatchAction] = []
var _snapshot: MatchStateSnapshot
var _failures: PackedStringArray = []


## Waits for the SceneTree root before loading the real test scene without rendering.
func _init() -> void:
	call_deferred("_run_tests")


## Selects the shared mode, then exercises four preset buttons and reset.
func _run_tests() -> void:
	var packed_scene := load(MENU_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "Shared mode scene did not load")
	if packed_scene == null:
		_finish()
		return
	_menu = packed_scene.instantiate() as GameModeController
	_expect(_menu != null, "Mode scene lacks GameModeController")
	if _menu == null:
		_finish()
		return
	root.add_child(_menu)
	var mode_host := _menu.get_node("ModeHost")
	var initial_bootstrap := mode_host.get_child(0) as GameBootstrap
	_expect(initial_bootstrap != null, "Shared demo did not start")
	if initial_bootstrap != null:
		var inactive_controls := initial_bootstrap.get_node("AerialPresetControls") as CanvasLayer
		_expect(not inactive_controls.visible, "Aerial controls appeared in pass mode")
	var mode_button := _menu.get_node(
		"ModeUi/ModePanel/ModeButtons/AerialJumpShotTestButton"
	) as Button
	_expect(mode_button != null, "Aerial mode selection button is missing")
	if mode_button == null:
		_menu.queue_free()
		_finish()
		return
	mode_button.pressed.emit()
	_bootstrap = mode_host.get_child(0) as GameBootstrap
	_expect(_menu.current_mode == GameModeController.Mode.AERIAL_JUMP_SHOT_TEST,
		"Aerial mode button did not select its mode")
	_expect(_menu.demo_scene.resource_path == "res://scenes/main/game_bootstrap.tscn",
		"Aerial mode did not reuse the shared demo scene")
	_expect(_bootstrap != null, "Aerial mode did not instantiate GameBootstrap")
	if _bootstrap == null:
		_menu.queue_free()
		_finish()
		return
	var controls := _bootstrap.get_node("AerialPresetControls") as CanvasLayer
	_expect(controls.visible, "Aerial preset controls are hidden in aerial mode")
	_expect(_bootstrap.demo_mode == GameBootstrap.DemoMode.AERIAL_JUMP_SHOT_TEST,
		"Shared bootstrap has the wrong aerial mode")
	_expect(_bootstrap.random_seed == 44, "Aerial presets need a fixed seed")
	_bootstrap.presentation_frame_ready.connect(_record_frame)
	_snapshot = (_bootstrap.get("_match_simulation") as MatchSimulation).create_snapshot()
	_expect(_snapshot != null, "Aerial demo did not start")
	if _snapshot == null:
		_menu.queue_free()
		_finish()
		return
	_expect(_snapshot.players.size() == 2, "Aerial demo requires two players")
	_expect(not _bootstrap.demo_player_id.is_empty(), "Carrier is missing")
	_expect(not _bootstrap.demo_opponent_id.is_empty(), "Defender is missing")
	_expect(_snapshot.ball.owner_player_id == _bootstrap.demo_player_id,
		"Aerial mode must start with the controlled player holding the ball")
	_test_ground_tackle()
	_test_effective_airborne_clearance()
	_test_tackle_after_landing()
	_test_aerial_shot()
	_test_reset()
	_test_keyboard_jump_and_shot()
	_menu.queue_free()
	_finish()


## A legal ground contact must transfer the one owned ball to the defender.
func _test_ground_tackle() -> void:
	_events.clear()
	_press("GroundTackleButton")
	_expect(_event_count(MatchEvent.Type.TACKLE_SUCCEEDED) == 1,
		"Ground preset did not produce one successful tackle")
	_expect(_snapshot.ball.owner_player_id == _bootstrap.demo_opponent_id,
		"Ground preset did not transfer possession")
	_expect(is_zero_approx(_snapshot.get_player(_bootstrap.demo_player_id).height_m),
		"Ground preset unexpectedly raised the carrier")


## The defender's ground action cannot touch a carrier above the clearance height.
func _test_effective_airborne_clearance() -> void:
	_events.clear()
	_press("AirborneClearanceButton")
	var player := _snapshot.get_player(_bootstrap.demo_player_id)
	var config := _bootstrap.data_repository.get_match_config_by_id("demo_match")
	_expect(_has_accepted_action(_bootstrap.demo_player_id),
		"Airborne preset did not accept the jump")
	_expect(not _has_accepted_action(_bootstrap.demo_opponent_id),
		"Ground tackle was accepted against a high airborne carrier")
	_expect(_event_count(MatchEvent.Type.TACKLE_SUCCEEDED) == 0,
		"Airborne preset allowed ground contact")
	_expect(player.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE,
		"Airborne preset did not reach the airborne phase")
	_expect(player.height_m >= config.ground_tackle_clearance_height_m,
		"Airborne preset did not reach clearance height")
	_expect(_snapshot.ball.owner_player_id == _bootstrap.demo_player_id,
		"Airborne preset lost possession")
	_expect(is_equal_approx(_snapshot.ball.height_m, player.height_m),
		"Owned ball did not follow carrier height")


## Once the jump ends, the same ground tackle can transfer possession again.
func _test_tackle_after_landing() -> void:
	_events.clear()
	_press("AfterLandingButton")
	_expect(_event_count(MatchEvent.Type.TACKLE_SUCCEEDED) == 1,
		"Landing preset did not permit ground tackle")
	_expect(_snapshot.ball.owner_player_id == _bootstrap.demo_opponent_id,
		"Landing preset did not transfer possession")
	_expect(_snapshot.get_player(_bootstrap.demo_player_id).jump_phase
		== PlayerMatchState.JumpPhase.NONE, "Landing preset retained jump phase")


## Aerial kick emits one shot and leaves a free, elevated in-flight ball.
func _test_aerial_shot() -> void:
	_events.clear()
	_press("AerialShotButton")
	_expect(_event_count(MatchEvent.Type.BALL_SHOT) == 1,
		"Shot preset did not release exactly one aerial shot")
	_expect(_snapshot.ball.owner_player_id.is_empty(),
		"Shot preset retained the carrier as owner")
	_expect(_snapshot.ball.motion_state == BallMatchState.MotionState.IN_FLIGHT,
		"Shot preset did not launch the ball")
	_expect(_snapshot.ball.height_m > 0.0, "Shot preset launched at ground height")


## The visible reset button rebuilds a grounded, owned, fixed-seed checkpoint.
func _test_reset() -> void:
	_events.clear()
	_press("ResetPresetButton")
	_expect(_snapshot.random_seed == 44, "Reset changed the preset seed")
	_expect(_snapshot.simulation_step == 1, "Reset did not restart the fixed-step clock")
	_expect(_snapshot.ball.owner_player_id == _bootstrap.demo_player_id,
		"Reset did not restore the carrier")
	_expect(is_zero_approx(_snapshot.ball.height_m), "Reset retained ball height")
	_expect(is_zero_approx(_snapshot.get_player(_bootstrap.demo_player_id).height_m),
		"Reset retained player height")
	_expect(_event_count(MatchEvent.Type.BALL_SHOT) == 0,
		"Reset replayed the previous shot")


## Space then K reaches one aerial shot even when K is pressed during takeoff.
func _test_keyboard_jump_and_shot() -> void:
	_events.clear()
	_input_actions.clear()
	var keyboard := _bootstrap.get_node("KeyboardPlayerInputAdapter") as KeyboardPlayerInputAdapter
	keyboard.action_requested.connect(_record_input_action)
	_press_key(keyboard, KEY_SPACE)
	_bootstrap._process(_bootstrap.fixed_delta_seconds)
	_expect(_snapshot.get_player(_bootstrap.demo_player_id).jump_phase
		== PlayerMatchState.JumpPhase.TAKEOFF, "Space did not start a jump")
	_press_key(keyboard, KEY_K)
	for step_index in range(20):
		_bootstrap._process(_bootstrap.fixed_delta_seconds)
	_expect(_input_actions.size() == 2, "Space and K did not emit two commands")
	if _input_actions.size() == 2:
		_expect(_input_actions[0].action_type == MatchAction.Type.JUMP,
			"Space did not emit JUMP")
		_expect(_input_actions[1].action_type == MatchAction.Type.SHOOT,
			"K did not emit SHOOT")
	_expect(_event_count(MatchEvent.Type.BALL_SHOT) == 1,
		"Space then early K did not produce exactly one aerial shot")
	_expect(_snapshot.ball.owner_player_id.is_empty(),
		"Keyboard aerial shot retained possession")
	_expect(_snapshot.ball.height_m > 0.0,
		"Keyboard aerial shot did not leave from a positive height")


## Invokes the same preset button signal a user activates in the shared scene.
func _press(button_name: String) -> void:
	var button := _bootstrap.get_node(
		"AerialPresetControls/PresetPanel/PresetButtons/" + button_name
	) as Button
	_expect(button != null, "Missing preset button: " + button_name)
	if button != null:
		button.pressed.emit()


## Sends an ordinary key-down event to the configured demo adapter.
func _press_key(adapter: KeyboardPlayerInputAdapter, key_code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key_code
	event.pressed = true
	adapter._unhandled_key_input(event)


## Records only the keyboard intent; simulation still decides whether it is legal.
func _record_input_action(action: MatchAction) -> void:
	_input_actions.append(action)


## Accumulates structured events and snapshots emitted by the real bootstrap.
func _record_frame(
	snapshot: MatchStateSnapshot,
	events: Array[MatchEvent],
	_alpha: float,
) -> void:
	_snapshot = snapshot
	_events.append_array(events)


## Counts only the requested fact, independent of other lifecycle events.
func _event_count(event_type: int) -> int:
	var count := 0
	for event in _events:
		if event.event_type == event_type:
			count += 1
	return count


## Distinguishes jump acceptance from an illegal defender tackle.
func _has_accepted_action(player_id: String) -> bool:
	for event in _events:
		if event.event_type == MatchEvent.Type.ACTION_ACCEPTED and event.subject_id == player_id:
			return true
	return false


## Collects all scenario failures before exiting the non-rendering test process.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Reports a failing exit status so automated checks cannot hide preset errors.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
