## Switches isolated modes through the shared demo scene without referencing test scenes.
class_name GameModeController
extends Node


enum Mode {
	FORMAL_MATCH,
	TOUCH_AND_DRIBBLE,
	PASS_AND_SHOOT,
	TACKLE_TEST,
	KNOCKDOWN_TEST,
	ATTACK_RECOIL_TEST,
	AERIAL_JUMP_SHOT_TEST,
	LOFTED_RECEIVE_AERIAL_SHOT_TEST,
	BALL_IMPACT_TEST,
	GOALKEEPER_TEST,
	FORMAL_FLOW_TEST,
}

@export var formal_match_scene: PackedScene
@export var demo_scene: PackedScene

@onready var _mode_host: Node = %ModeHost
@onready var _script_lab: PlayerAIScriptLab = %PlayerAIScriptLab
@onready var _mode_panel: PanelContainer = %ModePanel
@onready var _formal_match_button: Button = %FormalMatchButton
@onready var _touch_dribble_button: Button = %TouchDribbleButton
@onready var _pass_shoot_button: Button = %PassShootButton
@onready var _tackle_test_button: Button = %TackleTestButton
@onready var _knockdown_test_button: Button = %KnockdownTestButton
@onready var _attack_recoil_test_button: Button = %AttackRecoilTestButton
@onready var _aerial_jump_shot_test_button: Button = %AerialJumpShotTestButton
@onready var _lofted_receive_aerial_shot_test_button: Button = %LoftedReceiveAerialShotTestButton
@onready var _keeper_test_button: Button = %KeeperTestButton
@onready var _ball_impact_test_button: Button = %BallImpactTestButton

var current_mode: Mode:
	get:
		return _current_mode

var _current_mode: Mode = Mode.FORMAL_MATCH
var _active_mode_scene: Node
var _test_panels_visible := false


## Wires all mode buttons to independent scene instances.
func _ready() -> void:
	%ScriptLabButton.pressed.connect(_script_lab.open)
	_script_lab.trial_requested.connect(_start_script_trial)
	_formal_match_button.pressed.connect(_show_formal_match)
	_touch_dribble_button.pressed.connect(_show_touch_dribble)
	_pass_shoot_button.pressed.connect(_show_pass_shoot)
	_tackle_test_button.pressed.connect(_show_tackle_test)
	_knockdown_test_button.pressed.connect(_show_knockdown_test)
	_attack_recoil_test_button.pressed.connect(_show_attack_recoil_test)
	_aerial_jump_shot_test_button.pressed.connect(_show_aerial_jump_shot_test)
	_lofted_receive_aerial_shot_test_button.pressed.connect(_show_lofted_receive_aerial_shot_test)
	_ball_impact_test_button.pressed.connect(_show_ball_impact_test)
	_keeper_test_button.pressed.connect(_show_keeper_test)
	%FormalFlowTestButton.pressed.connect(func() -> void: show_mode(Mode.FORMAL_FLOW_TEST))
	show_mode(Mode.FORMAL_MATCH)


## Configures a fresh scene before it enters the tree, then updates the active mode.
func show_mode(mode: Mode, trial_seed: int = -1, scripted_id: String = "",
		strategy: PlayerAIDecisionStrategy = null) -> void:
	var selected_scene := _scene_for_mode(mode)
	assert(selected_scene != null, "Each game mode requires a scene")
	var next_mode_scene := selected_scene.instantiate()
	if mode == Mode.FORMAL_MATCH:
		var formal_bootstrap := next_mode_scene as FormalMatchBootstrap
		assert(formal_bootstrap != null, "Formal mode requires a FormalMatchBootstrap scene")
		formal_bootstrap.random_seed = randi() if trial_seed < 0 else trial_seed
		formal_bootstrap.auto_start_delay_seconds = 1.0 if trial_seed < 0 else 0.0
		if strategy != null and strategy.interface_version() == 2:
			formal_bootstrap.scripted_team_id = scripted_id
		else:
			formal_bootstrap.scripted_player_id = scripted_id
		formal_bootstrap.player_strategy = strategy
	else:
		var demo_bootstrap := next_mode_scene as GameBootstrap
		assert(demo_bootstrap != null, "Demo modes require a GameBootstrap scene")
		_configure_demo_mode(mode, demo_bootstrap)
	if _active_mode_scene != null:
		_mode_host.remove_child(_active_mode_scene)
		_active_mode_scene.queue_free()
	if trial_seed < 0:
		_script_lab.close()
	_mode_host.add_child(next_mode_scene)
	_active_mode_scene = next_mode_scene
	_current_mode = mode
	_apply_test_panel_visibility()
	_formal_match_button.set_pressed_no_signal(mode == Mode.FORMAL_MATCH)
	_touch_dribble_button.set_pressed_no_signal(mode == Mode.TOUCH_AND_DRIBBLE)
	_pass_shoot_button.set_pressed_no_signal(mode == Mode.PASS_AND_SHOOT)
	_tackle_test_button.set_pressed_no_signal(mode == Mode.TACKLE_TEST)
	_knockdown_test_button.set_pressed_no_signal(mode == Mode.KNOCKDOWN_TEST)
	_attack_recoil_test_button.set_pressed_no_signal(mode == Mode.ATTACK_RECOIL_TEST)
	_aerial_jump_shot_test_button.set_pressed_no_signal(mode == Mode.AERIAL_JUMP_SHOT_TEST)
	_lofted_receive_aerial_shot_test_button.set_pressed_no_signal(
		mode == Mode.LOFTED_RECEIVE_AERIAL_SHOT_TEST)
	_ball_impact_test_button.set_pressed_no_signal(mode == Mode.BALL_IMPACT_TEST)
	_keeper_test_button.set_pressed_no_signal(mode == Mode.GOALKEEPER_TEST)
	%FormalFlowTestButton.set_pressed_no_signal(mode == Mode.FORMAL_FLOW_TEST)


## Runs scripted and baseline trials through the same formal entry and lifecycle.
func _start_script_trial(player_id: String, strategy: PlayerAIDecisionStrategy, seed_value: int) -> void:
	show_mode(Mode.FORMAL_MATCH, seed_value, player_id, strategy)
	var formal := _active_mode_scene as FormalMatchBootstrap
	formal.presentation_frame_ready.connect(
		func(_snapshot: MatchStateSnapshot, _events: Array[MatchEvent], _alpha: float) -> void:
			_script_lab.report_fallback(formal.get_strategy_error()))
	formal.start_match()


## Handles F1 even when a test field or the script editor has keyboard focus.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_F1:
		return
	_test_panels_visible = not _test_panels_visible
	_apply_test_panel_visibility()
	get_viewport().set_input_as_handled()


## Shares the debug toggle across mode changes without touching match state or HUD layers.
func _apply_test_panel_visibility() -> void:
	_mode_panel.visible = _test_panels_visible
	if _active_mode_scene is FormalMatchBootstrap:
		_active_mode_scene.set_test_panels_visible(_test_panels_visible)
	elif _active_mode_scene is GameBootstrap:
		_active_mode_scene.set_test_panels_visible(_test_panels_visible)


## Keeps formal play separate while all interactive demos share one scene resource.
func _scene_for_mode(mode: Mode) -> PackedScene:
	if mode == Mode.FORMAL_MATCH:
		return formal_match_scene
	return demo_scene


## Sets the requested demo preset before GameBootstrap starts its match.
func _configure_demo_mode(mode: Mode, demo_bootstrap: GameBootstrap) -> void:
	match mode:
		Mode.FORMAL_FLOW_TEST:
			demo_bootstrap.demo_mode = GameBootstrap.DemoMode.FORMAL_FLOW_TEST
		Mode.TOUCH_AND_DRIBBLE:
			demo_bootstrap.demo_mode = GameBootstrap.DemoMode.TOUCH_AND_DRIBBLE
		Mode.PASS_AND_SHOOT:
			demo_bootstrap.demo_mode = GameBootstrap.DemoMode.PASS_AND_SHOOT
		Mode.TACKLE_TEST:
			demo_bootstrap.demo_mode = GameBootstrap.DemoMode.TACKLE_TEST
		Mode.KNOCKDOWN_TEST:
			demo_bootstrap.demo_mode = GameBootstrap.DemoMode.KNOCKDOWN_TEST
		Mode.ATTACK_RECOIL_TEST:
			demo_bootstrap.demo_mode = GameBootstrap.DemoMode.ATTACK_RECOIL_TEST
		Mode.AERIAL_JUMP_SHOT_TEST:
			demo_bootstrap.demo_mode = GameBootstrap.DemoMode.AERIAL_JUMP_SHOT_TEST
			demo_bootstrap.random_seed = 44
		Mode.LOFTED_RECEIVE_AERIAL_SHOT_TEST:
			demo_bootstrap.demo_mode = GameBootstrap.DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST
			demo_bootstrap.random_seed = 47
		Mode.GOALKEEPER_TEST:
			demo_bootstrap.demo_mode = GameBootstrap.DemoMode.GOALKEEPER_TEST
		Mode.BALL_IMPACT_TEST:
			demo_bootstrap.demo_mode = GameBootstrap.DemoMode.BALL_IMPACT_TEST
		_:
			assert(false, "Unsupported demo mode")


func _show_formal_match() -> void:
	show_mode(Mode.FORMAL_MATCH)


func _show_touch_dribble() -> void:
	show_mode(Mode.TOUCH_AND_DRIBBLE)


func _show_pass_shoot() -> void:
	show_mode(Mode.PASS_AND_SHOOT)


## Opens the opponent chase-and-tackle demo preset.
func _show_tackle_test() -> void:
	show_mode(Mode.TACKLE_TEST)


## Opens the stationary-opponent knockdown demo preset.
func _show_knockdown_test() -> void:
	show_mode(Mode.KNOCKDOWN_TEST)


## Opens the fixed-result demo where a melee attack rebounds from the ball carrier.
func _show_attack_recoil_test() -> void:
	show_mode(Mode.ATTACK_RECOIL_TEST)


## Opens the aerial presets in the same shared bootstrap scene as other demos.
func _show_aerial_jump_shot_test() -> void:
	show_mode(Mode.AERIAL_JUMP_SHOT_TEST)


## Opens the high-pass reception and teammate aerial-shot test in the shared scene.
func _show_lofted_receive_aerial_shot_test() -> void:
	show_mode(Mode.LOFTED_RECEIVE_AERIAL_SHOT_TEST)


## Opens ball impact presets in the existing shared demo scene.
func _show_ball_impact_test() -> void:
	show_mode(Mode.BALL_IMPACT_TEST)


## Opens the keeper presets through the same shared demo scene.
func _show_keeper_test() -> void:
	show_mode(Mode.GOALKEEPER_TEST)
