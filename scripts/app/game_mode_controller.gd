class_name GameModeController
extends Node


enum Mode {
	FORMAL_MATCH,
	TOUCH_AND_DRIBBLE,
	PASS_AND_SHOOT,
}

@export var formal_match_scene: PackedScene
@export var touch_dribble_scene: PackedScene
@export var pass_shoot_scene: PackedScene

@onready var _mode_host: Node = %ModeHost
@onready var _formal_match_button: Button = %FormalMatchButton
@onready var _touch_dribble_button: Button = %TouchDribbleButton
@onready var _pass_shoot_button: Button = %PassShootButton

var current_mode: Mode:
	get:
		return _current_mode

var _current_mode: Mode = Mode.PASS_AND_SHOOT
var _active_mode_scene: Node


func _ready() -> void:
	_formal_match_button.pressed.connect(_show_formal_match)
	_touch_dribble_button.pressed.connect(_show_touch_dribble)
	_pass_shoot_button.pressed.connect(_show_pass_shoot)
	show_mode(Mode.PASS_AND_SHOOT)


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


func _scene_for_mode(mode: Mode) -> PackedScene:
	match mode:
		Mode.FORMAL_MATCH:
			return formal_match_scene
		Mode.TOUCH_AND_DRIBBLE:
			return touch_dribble_scene
		Mode.PASS_AND_SHOOT:
			return pass_shoot_scene
		_:
			return null


func _show_formal_match() -> void:
	show_mode(Mode.FORMAL_MATCH)


func _show_touch_dribble() -> void:
	show_mode(Mode.TOUCH_AND_DRIBBLE)


func _show_pass_shoot() -> void:
	show_mode(Mode.PASS_AND_SHOOT)
