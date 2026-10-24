## Exercises the L-key recoil test scene through its real input and fixed-step loop.
extends SceneTree

var _snapshot: MatchStateSnapshot
var _recoil_count: int = 0
var _knockdown_count: int = 0
var _failures: PackedStringArray = []


## Enters the scene after the tree becomes available.
func _init() -> void:
	call_deferred("_run_test")


## Confirms that a test-mode melee contact rebounds from the ball carrier.
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
		"ModeUi/ModePanel/ModeButtons/AttackRecoilTestButton"
	) as Button
	_expect(button != null, "Recoil test button is missing")
	if button == null:
		menu.queue_free()
		_finish()
		return
	button.pressed.emit()
	await process_frame
	var bootstrap := menu.get_node("ModeHost").get_child(0) as GameBootstrap
	_expect(menu.current_mode == GameModeController.Mode.ATTACK_RECOIL_TEST,
		"Recoil button did not select its mode")
	bootstrap.melee_override = MatchSimulation.MeleeOutcome.ATTACKER_RECOILS
	bootstrap.reset_demo()
	bootstrap.presentation_frame_ready.connect(_record_frame)
	bootstrap._process(bootstrap.fixed_delta_seconds)
	var attacker_id: String = bootstrap.get("_demo_player_id")
	var carrier_id: String = bootstrap.get("_demo_opponent_id")
	var match_config: MatchConfigDefinition = bootstrap.get("_match_config")
	_expect(_snapshot.ball.owner_player_id == carrier_id,
		"Opponent did not carry the ball before the attack")
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_L
	key_event.pressed = true
	Input.parse_input_event(key_event)
	await process_frame
	for step_index in range(20):
		bootstrap._process(bootstrap.fixed_delta_seconds)
	_expect(_recoil_count == 1, "L did not produce exactly one recoil event")
	_expect(_knockdown_count == 0, "Recoil test knocked down the ball carrier")
	_expect(_snapshot.get_player(attacker_id).position_m.distance_to(
		Vector2.LEFT * match_config.knockdown_knockback_distance_m
	) < 0.0001, "Attacker did not retreat two metres")
	_expect(_snapshot.ball.owner_player_id == carrier_id,
		"Opponent lost possession during recoil")
	menu.queue_free()
	_finish()


## Records only facts needed to verify the visible demo outcome.
func _record_frame(snapshot: MatchStateSnapshot, events: Array[MatchEvent], _alpha: float) -> void:
	_snapshot = snapshot
	for event in events:
		if event.event_type == MatchEvent.Type.ATTACK_RECOILED:
			_recoil_count += 1
		elif event.event_type == MatchEvent.Type.PLAYER_KNOCKED_DOWN:
			_knockdown_count += 1


## Accumulates independent integration assertions.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Exits with a failure code when any scene behavior differs from the expected result.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
