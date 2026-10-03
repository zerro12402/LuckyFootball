## Translates demo keyboard input into match commands and test control signals.
class_name KeyboardPlayerInputAdapter
extends Node

signal action_requested(action: MatchAction)
signal meter_ticks_toggle_requested

const INPUT_DEADZONE := 0.1

var _player_id: String = ""
var _teammate_id: String = ""
var _last_direction: Vector2 = Vector2.ZERO
var _has_sent_direction: bool = false


## Waits for demo configuration before accepting test controls.
func _ready() -> void:
	set_process(false)
	set_process_unhandled_key_input(false)


## Binds keyboard commands to the current demo players.
func configure(player_id: String, teammate_id: String = "") -> void:
	assert(not player_id.is_empty(), "Keyboard input requires a player ID")
	assert(player_id != teammate_id, "Test players require distinct IDs")
	_player_id = player_id
	_teammate_id = teammate_id
	_last_direction = Vector2.ZERO
	_has_sent_direction = false
	set_process(true)
	set_process_unhandled_key_input(true)


## Resends the current movement direction after control resumes or switches.
func force_resend() -> void:
	_has_sent_direction = false


## Emits a movement command only when the requested direction changes.
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


## Routes one-shot test keys without modifying match state directly.
func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if (
		key_event.physical_keycode == KEY_QUOTELEFT
		or key_event.keycode == KEY_QUOTELEFT
		or key_event.keycode == KEY_ASCIITILDE
	):
		var reset_type := MatchAction.Type.RESET_ROUND
		if key_event.ctrl_pressed:
			reset_type = MatchAction.Type.RESTART_TEST
		action_requested.emit(MatchAction.new("", reset_type))
	elif key_event.keycode == KEY_M or key_event.physical_keycode == KEY_M:
		meter_ticks_toggle_requested.emit()
	elif (
		(key_event.keycode == KEY_K or key_event.physical_keycode == KEY_K)
		and not _teammate_id.is_empty()
	):
		action_requested.emit(MatchAction.new(_player_id, MatchAction.Type.SHOOT))
	elif key_event.keycode == KEY_J and not _teammate_id.is_empty():
		action_requested.emit(
			MatchAction.new(
				_player_id,
				MatchAction.Type.PASS,
				Vector2.ZERO,
				_teammate_id,
			)
		)
	elif key_event.keycode == KEY_TAB and not _teammate_id.is_empty():
		_switch_controlled_player()


## Stops the old player before handing input to the teammate.
func _switch_controlled_player() -> void:
	action_requested.emit(
		MatchAction.new(_player_id, MatchAction.Type.MOVE, Vector2.ZERO)
	)
	var previous_player_id := _player_id
	_player_id = _teammate_id
	_teammate_id = previous_player_id
	force_resend()
