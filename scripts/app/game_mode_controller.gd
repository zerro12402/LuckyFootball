## Switches between isolated demo modes without sharing mutable match state.
class_name GameModeController
extends Node


enum Mode {
	FORMAL_MATCH,
	TOUCH_AND_DRIBBLE,
	PASS_AND_SHOOT,
	TACKLE_TEST,
	KNOCKDOWN_TEST,
}

@export var formal_match_scene: PackedScene
@export var touch_dribble_scene: PackedScene
@export var pass_shoot_scene: PackedScene
@export var tackle_test_scene: PackedScene
@export var knockdown_test_scene: PackedScene

@onready var _mode_host: Node = %ModeHost
@onready var _formal_match_button: Button = %FormalMatchButton
@onready var _touch_dribble_button: Button = %TouchDribbleButton
@onready var _pass_shoot_button: Button = %PassShootButton
@onready var _tackle_test_button: Button = %TackleTestButton
@onready var _knockdown_test_button: Button = %KnockdownTestButton

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
	show_mode(Mode.PASS_AND_SHOOT)


## Replaces the previous mode scene and updates the selected button.
func show_mode(mode: Mode) -> void:
	var selected_scene := _scene_for_mode(mode)
	assert(selected_scene != null, "Each game mode requires a scene")
	var next_mode_scene := selected_scene.instantiate()
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


## Finds the configured scene for a requested mode.
func _scene_for_mode(mode: Mode) -> PackedScene:
	match mode:
		Mode.FORMAL_MATCH:
			return formal_match_scene
		Mode.TOUCH_AND_DRIBBLE:
			return touch_dribble_scene
		Mode.PASS_AND_SHOOT:
			return pass_shoot_scene
		Mode.TACKLE_TEST:
			return tackle_test_scene
		Mode.KNOCKDOWN_TEST:
			return knockdown_test_scene
		_:
			return null


func _show_formal_match() -> void:
	show_mode(Mode.FORMAL_MATCH)


func _show_touch_dribble() -> void:
	show_mode(Mode.TOUCH_AND_DRIBBLE)


func _show_pass_shoot() -> void:
	show_mode(Mode.PASS_AND_SHOOT)


## Opens the opponent chase-and-tackle test scene.
func _show_tackle_test() -> void:
	show_mode(Mode.TACKLE_TEST)


## Opens the stationary-opponent knockdown test scene.
func _show_knockdown_test() -> void:
	show_mode(Mode.KNOCKDOWN_TEST)
