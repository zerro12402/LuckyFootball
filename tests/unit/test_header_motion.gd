## Checks the physical header leap and exact two-frame action timing without rendering.
extends SceneTree

var _failures: PackedStringArray = []


## Steps a single state machine through rise, forward motion, landing, and reset.
func _init() -> void:
	var repository := DataRepository.new()
	_check(repository.load_all(), "Match data must load")
	if not _failures.is_empty():
		_finish()
		return
	var config := repository.get_match_config_by_id("demo_match")
	_check(config != null, "Demo match config must exist")
	if config == null:
		_finish()
		return
	_check(is_equal_approx(config.header_first_frame_seconds, 0.3),
		"First header frame must use the configured 0.3 seconds")
	_check(is_equal_approx(config.header_second_frame_seconds, 1.0),
		"Second header frame must use the configured 1.0 seconds")
	var state := PlayerMatchState.new("header", Vector2.ZERO)
	var machine := PlayerStateMachine.new(state)
	_check(machine.try_start_header(config, Vector2.RIGHT), "Header should start for a free player")
	_check(state.action_state == PlayerMatchState.ActionState.HEADING,
		"Header should enter action state immediately")
	machine.advance(0.15)
	_check(state.height_m > 0.0, "Header should leave the ground")
	_check(is_equal_approx(state.position_m.x, 0.5),
		"First image should carry the player halfway forward")
	machine.advance(0.15)
	_check(state.action_state == PlayerMatchState.ActionState.HEADING,
		"First image must remain active through 0.3 seconds")
	_check(is_equal_approx(state.position_m.x, PlayerStateMachine.HEADER_FORWARD_DISTANCE_M),
		"Forward motion should stop at its fixed distance")
	machine.advance(0.99)
	_check(state.action_state == PlayerMatchState.ActionState.HEADING,
		"Second image must remain active before 1.3 seconds")
	_check(is_equal_approx(state.position_m.x, PlayerStateMachine.HEADER_FORWARD_DISTANCE_M),
		"Second image must not add extra forward movement")
	machine.advance(0.01)
	_check(state.action_state == PlayerMatchState.ActionState.LANDING,
		"Header should transition to landing after 1.3 seconds")
	_check(is_zero_approx(state.height_m), "Player should touch ground for landing")
	machine.advance(PlayerStateMachine.HEADER_LANDING_DURATION_SECONDS)
	_check(state.action_state == PlayerMatchState.ActionState.IDLE,
		"Landing should release the action lock")
	_check(not machine.try_start_header(config, Vector2.ZERO), "Zero heading direction must fail")
	_check(machine.try_start_header(config, Vector2.LEFT), "A second header should start")
	machine.advance(0.25)
	machine.reset_to_spawn(Vector2.ZERO)
	_check(state.action_state == PlayerMatchState.ActionState.IDLE
		and state.jump_phase == PlayerMatchState.JumpPhase.NONE
		and is_zero_approx(state.height_m)
		and state.position_m.is_zero_approx(),
		"Reset should clear header motion and airborne state")
	_test_custom_frame_durations()
	_finish()


## Confirms edited CSV values change both the forward phase and landing time.
func _test_custom_frame_durations() -> void:
	var source := FileAccess.get_file_as_string("res://resources/data/match_configs.csv")
	_check(not source.is_empty(), "Match config CSV must be readable")
	if source.is_empty():
		return
	var custom_csv := source.replace(
		"header_first_frame_seconds,0.3,", "header_first_frame_seconds,0.5,")
	custom_csv = custom_csv.replace(
		"header_second_frame_seconds,1.0,", "header_second_frame_seconds,0.7,")
	var custom_path := "user://test_header_custom_timing.csv"
	var file := FileAccess.open(custom_path, FileAccess.WRITE)
	_check(file != null, "Custom match config CSV must be writable")
	if file == null:
		return
	file.store_string(custom_csv)
	file.close()
	var result := MatchConfigDataRepository.new().load_from_csv(custom_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(custom_path))
	_check(result.is_success, "Custom header durations must parse")
	if not result.is_success:
		return
	var custom_config := result.configs[0]
	_check(is_equal_approx(custom_config.header_first_frame_seconds, 0.5)
		and is_equal_approx(custom_config.header_second_frame_seconds, 0.7),
		"Both custom durations must be available to simulation")
	var custom_state := PlayerMatchState.new("custom_header", Vector2.ZERO)
	var custom_machine := PlayerStateMachine.new(custom_state)
	_check(custom_machine.try_start_header(custom_config, Vector2.RIGHT),
		"Header should start with custom timing")
	custom_machine.advance(0.3)
	_check(is_equal_approx(custom_state.position_m.x, 0.6),
		"Custom first-frame duration must control forward speed")
	custom_machine.advance(0.2)
	_check(is_equal_approx(custom_state.position_m.x, 1.0),
		"Forward travel must finish after the custom first frame")
	custom_machine.advance(0.69)
	_check(custom_state.action_state == PlayerMatchState.ActionState.HEADING,
		"Custom second frame must stay active until its deadline")
	custom_machine.advance(0.01)
	_check(custom_state.action_state == PlayerMatchState.ActionState.LANDING,
		"Custom frame sum must start landing")


## Ends this non-rendering timing test with a success or failure code.
func _finish() -> void:
	if _failures.is_empty():
		print("PASS: header motion")
	else:
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


## Records each independent state or distance mismatch.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
