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
}

@export var formal_match_scene: PackedScene
@export var demo_scene: PackedScene

@onready var _mode_host: Node = %ModeHost
@onready var _formal_match_button: Button = %FormalMatchButton
@onready var _touch_dribble_button: Button = %TouchDribbleButton
@onready var _pass_shoot_button: Button = %PassShootButton
@onready var _tackle_test_button: Button = %TackleTestButton
@onready var _knockdown_test_button: Button = %KnockdownTestButton
@onready var _attack_recoil_test_button: Button = %AttackRecoilTestButton
@onready var _aerial_jump_shot_test_button: Button = %AerialJumpShotTestButton

var current_mode: Mode:
	get:
		return _current_mode

var _current_mode: Mode = Mode.PASS_AND_SHOOT
var _active_mode_scene: Node


## Wires all mode buttons to independent scene instances.
func _ready() -> void:
	_formal_match_button.pressed.connect(_show_formal_match)
	_touch_dribble_button.pressed.connect(_show_touch_dribble)
	_pass_shoot_button.pressed.connect(_show_pass_shoot)
	_tackle_test_button.pressed.connect(_show_tackle_test)
	_knockdown_test_button.pressed.connect(_show_knockdown_test)
	_attack_recoil_test_button.pressed.connect(_show_attack_recoil_test)
	_aerial_jump_shot_test_button.pressed.connect(_show_aerial_jump_shot_test)
	show_mode(Mode.PASS_AND_SHOOT)


## Configures a fresh scene before it enters the tree, then updates the active mode.
func show_mode(mode: Mode) -> void:
	var selected_scene := _scene_for_mode(mode)
	assert(selected_scene != null, "Each game mode requires a scene")
	var next_mode_scene := selected_scene.instantiate()
	if mode != Mode.FORMAL_MATCH:
		var demo_bootstrap := next_mode_scene as GameBootstrap
		assert(demo_bootstrap != null, "Demo modes require a GameBootstrap scene")
		_configure_demo_mode(mode, demo_bootstrap)
	if _active_mode_scene != null:
		_mode_host.remove_child(_active_mode_scene)
		_active_mode_scene.queue_free()
	_mode_host.add_child(next_mode_scene)
	_active_mode_scene = next_mode_scene
	_current_mode = mode
	_formal_match_button.set_pressed_no_signal(mode == Mode.FORMAL_MATCH)
	_touch_dribble_button.set_pressed_no_signal(mode == Mode.TOUCH_AND_DRIBBLE)
	_pass_shoot_button.set_pressed_no_signal(mode == Mode.PASS_AND_SHOOT)
	_tackle_test_button.set_pressed_no_signal(mode == Mode.TACKLE_TEST)
	_knockdown_test_button.set_pressed_no_signal(mode == Mode.KNOCKDOWN_TEST)
	_attack_recoil_test_button.set_pressed_no_signal(mode == Mode.ATTACK_RECOIL_TEST)
	_aerial_jump_shot_test_button.set_pressed_no_signal(mode == Mode.AERIAL_JUMP_SHOT_TEST)


## Keeps formal play separate while all interactive demos share one scene resource.
func _scene_for_mode(mode: Mode) -> PackedScene:
	if mode == Mode.FORMAL_MATCH:
		return formal_match_scene
	return demo_scene


## Sets the requested demo preset before GameBootstrap starts its match.
func _configure_demo_mode(mode: Mode, demo_bootstrap: GameBootstrap) -> void:
	match mode:
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
