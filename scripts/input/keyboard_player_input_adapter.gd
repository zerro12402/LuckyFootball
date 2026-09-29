class_name KeyboardPlayerInputAdapter
extends Node

signal action_requested(action: MatchAction)

const INPUT_DEADZONE := 0.1

var _player_id: String = ""
var _last_direction: Vector2 = Vector2.ZERO
var _has_sent_direction: bool = false


func _ready() -> void:
	set_process(false)


func configure(player_id: String) -> void:
	assert(not player_id.is_empty(), "Keyboard input requires a player ID")
	_player_id = player_id
	_last_direction = Vector2.ZERO
	_has_sent_direction = false
	set_process(true)


func force_resend() -> void:
	_has_sent_direction = false


func _process(_delta: float) -> void:
	var direction := Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down",
		INPUT_DEADZONE,
	)
	if _has_sent_direction and direction.is_equal_approx(_last_direction):
		return
	_last_direction = direction
	_has_sent_direction = true
	action_requested.emit(
		MatchAction.new(_player_id, MatchAction.Type.MOVE, direction)
	)
