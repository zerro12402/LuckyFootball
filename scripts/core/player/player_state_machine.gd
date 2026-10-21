## Owns player movement and timed action transitions without scene-tree state.
class_name PlayerStateMachine
extends RefCounted

const DEFAULT_MOVEMENT_SPEED_MPS := 5.0
const POSSESSION_MOVEMENT_SPEED_MULTIPLIER := 0.9
const INPUT_EPSILON := 0.0001
const PASS_WINDUP_SECONDS := 0.2
const PASS_RECOVERY_SECONDS := 0.3
const PASS_ACTION_DURATION_SECONDS := 0.4
const HEADER_FORWARD_DISTANCE_M := 1.0
const HEADER_JUMP_HEIGHT_M := 0.8
const HEADER_LANDING_DURATION_SECONDS := 0.3

var state: PlayerMatchState:
	get:
		return _state

var movement_speed_mps: float:
	get:
		return _movement_speed_mps

var knockdown_direction: Vector2:
	get:
		return _knockdown_direction

var _state: PlayerMatchState
var _movement_speed_mps: float
var _shot_config: MatchConfigDefinition
var _jump_config: MatchConfigDefinition
var _tackle_config: MatchConfigDefinition
var _tackle_direction: Vector2 = Vector2.ZERO
var _tackle_cooldown_remaining_seconds: float = 0.0
var _hit_stun_duration_seconds: float = 0.0
var _knockdown_config: MatchConfigDefinition
var _knockdown_direction: Vector2 = Vector2.ZERO
var _knockdown_cooldown_remaining_seconds: float = 0.0
var _knockback_direction: Vector2 = Vector2.ZERO
var _knockback_elapsed_seconds: float = 0.0
var _header_direction: Vector2 = Vector2.ZERO
var _header_config: MatchConfigDefinition
var _is_header_landing: bool = false


## Checks the runtime invariants shared by movement and timed actions.
func _init(
	player_state: PlayerMatchState,
	new_movement_speed_mps: float = DEFAULT_MOVEMENT_SPEED_MPS,
) -> void:
	assert(player_state != null, "PlayerStateMachine requires player state")
	assert(new_movement_speed_mps > 0.0, "Movement speed must be positive")
	_state = player_state
	_movement_speed_mps = new_movement_speed_mps


## Advances movement and action phases from the fixed simulation clock.
func advance(fixed_delta_seconds: float) -> void:
	assert(fixed_delta_seconds > 0.0, "Fixed delta must be positive")
	if _state.action_state == PlayerMatchState.ActionState.TACKLING:
		_advance_tackle_motion(fixed_delta_seconds)
	elif _state.action_state == PlayerMatchState.ActionState.HEADING:
		_advance_header_motion(fixed_delta_seconds)
	elif _state.action_state == PlayerMatchState.ActionState.ATTACKING:
		_advance_knockdown_motion(fixed_delta_seconds)
	elif _state.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN:
		_advance_knockback_motion(fixed_delta_seconds)
	elif (
		_state.movement_state == PlayerMatchState.MovementState.MOVING
		and _state.action_state != PlayerMatchState.ActionState.SHOOTING
		and _state.action_state != PlayerMatchState.ActionState.STAGGERED
		and _state.action_state != PlayerMatchState.ActionState.KNOCKED_DOWN
		and _state.action_state != PlayerMatchState.ActionState.GETTING_UP
		and _state.action_state != PlayerMatchState.ActionState.LANDING
		and _state.action_state != PlayerMatchState.ActionState.HEADING
	):
		_state._set_position(
			_state.position_m
			+ _state.movement_input * _get_current_movement_speed_mps() * fixed_delta_seconds
		)
	_knockdown_cooldown_remaining_seconds = maxf(
		_knockdown_cooldown_remaining_seconds - fixed_delta_seconds, 0.0
	)
	_tackle_cooldown_remaining_seconds = maxf(
		_tackle_cooldown_remaining_seconds - fixed_delta_seconds, 0.0
	)
	_state._advance_state_time(fixed_delta_seconds)
	_advance_jump(fixed_delta_seconds)
	if _state.action_state == PlayerMatchState.ActionState.PASSING:
		_advance_pass_action()
	elif _state.action_state == PlayerMatchState.ActionState.SHOOTING:
		_advance_shot_action()
	elif _state.action_state == PlayerMatchState.ActionState.TACKLING:
		_advance_tackle_action()
	elif _state.action_state == PlayerMatchState.ActionState.STAGGERED:
		_advance_hit_stun()
	elif _state.action_state == PlayerMatchState.ActionState.ATTACKING:
		_advance_knockdown_action()
	elif _state.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN:
		_advance_knocked_down()
	elif _state.action_state == PlayerMatchState.ActionState.GETTING_UP:
		_advance_getting_up()
	elif _state.action_state == PlayerMatchState.ActionState.LANDING:
		_advance_landing()
	elif _state.action_state == PlayerMatchState.ActionState.HEADING:
		_advance_header_action()


## Normalizes movement intent while preserving the previous left-right facing on vertical input.
func set_movement_input(new_input: Vector2) -> bool:
	if not new_input.is_finite():
		return false
	if _state.action_state in [
		PlayerMatchState.ActionState.KNOCKED_DOWN,
		PlayerMatchState.ActionState.GETTING_UP,
		PlayerMatchState.ActionState.LANDING,
	]:
		return false
	if _state.action_state in [
		PlayerMatchState.ActionState.TACKLING,
		PlayerMatchState.ActionState.ATTACKING,
	]:
		return false
	var clamped_input := new_input.limit_length(1.0)
	if _state.action_state == PlayerMatchState.ActionState.HEADING:
		_state._set_movement_input(clamped_input)
		return true
	if _state.action_state == PlayerMatchState.ActionState.STAGGERED:
		# Remember the latest intent without allowing motion until recovery.
		_state._set_movement_input(clamped_input)
		return true
	if clamped_input.length() <= INPUT_EPSILON:
		_state._set_movement_input(Vector2.ZERO)
		_set_movement_state_if_changed(PlayerMatchState.MovementState.IDLE)
		return true
	_state._set_movement_input(clamped_input)
	if _state.action_state != PlayerMatchState.ActionState.SHOOTING:
		_update_horizontal_facing(clamped_input)
	_set_movement_state_if_changed(PlayerMatchState.MovementState.MOVING)
	return true


## Allows only valid movement states outside knockdown.
func set_movement_state(new_state: int) -> bool:
	if new_state < 0 or new_state >= PlayerMatchState.MovementState.size():
		return false
	if _state.movement_state == new_state:
		return false
	if _state.action_state in [
		PlayerMatchState.ActionState.KNOCKED_DOWN,
		PlayerMatchState.ActionState.STAGGERED,
		PlayerMatchState.ActionState.TACKLING,
		PlayerMatchState.ActionState.ATTACKING,
		PlayerMatchState.ActionState.GETTING_UP,
		PlayerMatchState.ActionState.LANDING,
		PlayerMatchState.ActionState.HEADING,
	]:
		return false
	_state._set_movement_state(new_state)
	return true


## Keeps possession transitions inside the player's state machine.
func set_possession_state(new_state: int) -> bool:
	if new_state < 0 or new_state >= PlayerMatchState.PossessionState.size():
		return false
	if _state.possession_state == new_state:
		return false
	_state._set_possession_state(new_state)
	return true


## Starts a generic action only when no other action is active.
func try_start_action(new_action_state: int) -> bool:
	if new_action_state <= PlayerMatchState.ActionState.IDLE:
		return false
	if new_action_state >= PlayerMatchState.ActionState.size():
		return false
	if _state.action_state != PlayerMatchState.ActionState.IDLE:
		return false
	_state._set_action_state(new_action_state, PlayerMatchState.ActionPhase.WINDUP)
	if new_action_state == PlayerMatchState.ActionState.KNOCKED_DOWN:
		_state._set_movement_input(Vector2.ZERO)
		_set_movement_state_if_changed(PlayerMatchState.MovementState.IDLE)
	return true


## Locks the head direction and begins a two-frame airborne follow-through.
func try_start_header(config: MatchConfigDefinition, direction: Vector2) -> bool:
	if config == null or not direction.is_finite() or direction.is_zero_approx():
		return false
	if _state.possession_state != PlayerMatchState.PossessionState.NO_BALL:
		return false
	if not try_start_action(PlayerMatchState.ActionState.HEADING):
		return false
	_header_config = config
	_header_direction = direction.normalized()
	_update_horizontal_facing(_header_direction)
	_state._set_jump_state(PlayerMatchState.JumpPhase.AIRBORNE, 0.0, 0.0)
	_state._set_action_phase(PlayerMatchState.ActionPhase.ACTIVE)
	return true


## Captures shot timing and facing at command acceptance, before the kick frame.
func try_start_shot(config: MatchConfigDefinition, direction: Vector2) -> bool:
	if config == null or not direction.is_finite() or direction.is_zero_approx():
		return false
	if _state.jump_phase in [
		PlayerMatchState.JumpPhase.TAKEOFF,
		PlayerMatchState.JumpPhase.LANDING,
	]:
		return false
	if not try_start_action(PlayerMatchState.ActionState.SHOOTING):
		return false
	_shot_config = config
	_update_horizontal_facing(direction)
	return true


## Starts a jump after simulation has authorized either possession or an incoming pass.
func try_start_jump(config: MatchConfigDefinition, allow_without_ball: bool = false) -> bool:
	if config == null or _state.jump_phase != PlayerMatchState.JumpPhase.NONE:
		return false
	if _state.action_state != PlayerMatchState.ActionState.IDLE:
		return false
	if _state.possession_state != PlayerMatchState.PossessionState.POSSESSING and not (
		allow_without_ball
		and _state.possession_state == PlayerMatchState.PossessionState.NO_BALL
	):
		return false
	_jump_config = config
	_state._set_jump_state(PlayerMatchState.JumpPhase.TAKEOFF, 0.0, 0.0)
	return true


## Starts a timed tackle only for an idle defender whose cooldown has ended.
func try_start_tackle(config: MatchConfigDefinition) -> bool:
	if config == null or _tackle_cooldown_remaining_seconds > 0.0:
		return false
	if _state.jump_phase != PlayerMatchState.JumpPhase.NONE:
		return false
	if _state.possession_state != PlayerMatchState.PossessionState.NO_BALL:
		return false
	if not try_start_action(PlayerMatchState.ActionState.TACKLING):
		return false
	_tackle_config = config
	_tackle_direction = _state.movement_input.normalized()
	if _tackle_direction.is_zero_approx():
		_tackle_direction = _state.facing_direction
	_tackle_cooldown_remaining_seconds = (
		config.tackle_action_duration_seconds + config.tackle_cooldown_seconds
	)
	_state._set_movement_input(Vector2.ZERO)
	_set_movement_state_if_changed(PlayerMatchState.MovementState.IDLE)
	return true


## Starts a timed melee lunge and locks its initial direction for deterministic motion.
func try_start_knockdown(config: MatchConfigDefinition) -> bool:
	if config == null or _knockdown_cooldown_remaining_seconds > 0.0:
		return false
	if _state.jump_phase != PlayerMatchState.JumpPhase.NONE:
		return false
	if not try_start_action(PlayerMatchState.ActionState.ATTACKING):
		return false
	_knockdown_config = config
	_knockdown_direction = _state.movement_input.normalized()
	if _knockdown_direction.is_zero_approx():
		_knockdown_direction = _state.facing_direction
	_knockdown_cooldown_remaining_seconds = (
		config.knockdown_action_duration_seconds
		+ config.knockdown_landing_animation_seconds
		+ config.knockdown_crouch_hold_seconds
		+ config.knockdown_cooldown_seconds
	)
	_state._set_movement_input(Vector2.ZERO)
	_set_movement_state_if_changed(PlayerMatchState.MovementState.IDLE)
	return true


## Cancels a target's unfinished action and begins the configured down/get-up cycle.
func start_knockdown(config: MatchConfigDefinition) -> bool:
	if config == null or _state.action_state in [
		PlayerMatchState.ActionState.KNOCKED_DOWN,
		PlayerMatchState.ActionState.GETTING_UP,
	]:
		return false
	if _state.action_state != PlayerMatchState.ActionState.IDLE:
		finish_action()
	_cancel_jump()
	_knockdown_config = config
	_knockback_direction = Vector2.ZERO
	_knockback_elapsed_seconds = 0.0
	_state._set_movement_input(Vector2.ZERO)
	_set_movement_state_if_changed(PlayerMatchState.MovementState.IDLE)
	_state._set_action_state(
		PlayerMatchState.ActionState.KNOCKED_DOWN,
		PlayerMatchState.ActionPhase.ACTIVE,
	)
	return true


## Captures one impact direction for deterministic fixed-step knockback.
func start_knockback(direction: Vector2) -> bool:
	if _state.action_state != PlayerMatchState.ActionState.KNOCKED_DOWN:
		return false
	if _knockdown_config == null or not _knockback_direction.is_zero_approx():
		return false
	if not direction.is_finite() or direction.is_zero_approx():
		return false
	_knockback_direction = direction.normalized()
	_knockback_elapsed_seconds = 0.0
	return true


## Locks a tackled carrier in place while preserving their latest movement intent.
func start_hit_stun(duration_seconds: float) -> bool:
	if duration_seconds <= 0.0 or not is_finite(duration_seconds):
		return false
	if _state.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN:
		return false
	if _state.action_state != PlayerMatchState.ActionState.IDLE:
		finish_action()
	_cancel_jump()
	_hit_stun_duration_seconds = duration_seconds
	_state._set_action_state(
		PlayerMatchState.ActionState.STAGGERED,
		PlayerMatchState.ActionPhase.ACTIVE,
	)
	_set_movement_state_if_changed(PlayerMatchState.MovementState.IDLE)
	return true


## Prevents action phases from moving backward.
func set_action_phase(new_phase: int) -> bool:
	if _state.action_state == PlayerMatchState.ActionState.IDLE:
		return false
	if new_phase <= PlayerMatchState.ActionPhase.NONE:
		return false
	if new_phase >= PlayerMatchState.ActionPhase.size():
		return false
	if new_phase <= _state.action_phase:
		return false
	_state._set_action_phase(new_phase)
	return true


## Releases the action lock after its timed recovery.
func finish_action() -> bool:
	if _state.action_state == PlayerMatchState.ActionState.IDLE:
		return false
	var was_shooting := _state.action_state == PlayerMatchState.ActionState.SHOOTING
	var was_staggered := _state.action_state == PlayerMatchState.ActionState.STAGGERED
	var was_heading := _state.action_state == PlayerMatchState.ActionState.HEADING
	var was_header_landing := _is_header_landing
	_state._set_action_state(
		PlayerMatchState.ActionState.IDLE,
		PlayerMatchState.ActionPhase.NONE,
	)
	if was_shooting:
		_shot_config = null
		_update_horizontal_facing(_state.movement_input)
	_tackle_config = null
	_tackle_direction = Vector2.ZERO
	_knockdown_config = null
	_knockdown_direction = Vector2.ZERO
	_knockback_direction = Vector2.ZERO
	_knockback_elapsed_seconds = 0.0
	_hit_stun_duration_seconds = 0.0
	_header_direction = Vector2.ZERO
	_header_config = null
	_is_header_landing = false
	if was_heading or was_header_landing:
		_cancel_jump()
	if was_staggered and _state.movement_input.length() > INPUT_EPSILON:
		_update_horizontal_facing(_state.movement_input)
		_set_movement_state_if_changed(PlayerMatchState.MovementState.MOVING)
	return true



## Stops movement for a resolved round, optionally cancelling an unfinished action.
func stop_for_settlement(should_cancel_action: bool) -> void:
	_state._set_movement_input(Vector2.ZERO)
	_set_movement_state_if_changed(PlayerMatchState.MovementState.IDLE)
	if should_cancel_action and _state.action_state != PlayerMatchState.ActionState.IDLE:
		finish_action()
	if should_cancel_action:
		_cancel_jump()


## Restores an actionable player without carrying an old windup or movement intent.
func reset_to_spawn(spawn_position_m: Vector2) -> void:
	_state._set_position(spawn_position_m)
	_state._set_facing_direction(Vector2.RIGHT)
	_state._set_movement_input(Vector2.ZERO)
	_state._set_movement_state(PlayerMatchState.MovementState.IDLE)
	_state._set_possession_state(PlayerMatchState.PossessionState.NO_BALL)
	_state._set_action_state(
		PlayerMatchState.ActionState.IDLE,
		PlayerMatchState.ActionPhase.NONE,
	)
	_cancel_jump()
	_shot_config = null
	_tackle_config = null
	_tackle_direction = Vector2.ZERO
	_tackle_cooldown_remaining_seconds = 0.0
	_knockdown_config = null
	_knockdown_direction = Vector2.ZERO
	_knockdown_cooldown_remaining_seconds = 0.0
	_knockback_direction = Vector2.ZERO
	_knockback_elapsed_seconds = 0.0
	_hit_stun_duration_seconds = 0.0
	_header_direction = Vector2.ZERO
	_header_config = null
	_is_header_landing = false


## Applies the existing dribble speed reduction without changing the base speed.
func _get_current_movement_speed_mps() -> float:
	if _state.possession_state == PlayerMatchState.PossessionState.POSSESSING:
		return _movement_speed_mps * POSSESSION_MOVEMENT_SPEED_MULTIPLIER
	return _movement_speed_mps


## Advances a deterministic height arc independently of the player's other action.
func _advance_jump(fixed_delta_seconds: float) -> void:
	if _state.jump_phase == PlayerMatchState.JumpPhase.NONE:
		return
	if _state.action_state == PlayerMatchState.ActionState.HEADING:
		assert(_header_config != null, "Heading requires match configuration")
		var header_duration := (
			_header_config.header_first_frame_seconds
			+ _header_config.header_second_frame_seconds
		)
		var header_elapsed := minf(
			_state.action_state_elapsed_seconds,
			header_duration,
		)
		var header_progress := header_elapsed / header_duration
		var header_height := (
			4.0 * HEADER_JUMP_HEIGHT_M * header_progress * (1.0 - header_progress)
		)
		_state._set_jump_state(
			PlayerMatchState.JumpPhase.AIRBORNE, header_elapsed, header_height,
		)
		return
	assert(_jump_config != null, "Active jump requires match configuration")
	var elapsed_seconds := _state.jump_elapsed_seconds + fixed_delta_seconds
	if elapsed_seconds >= _jump_config.jump_duration_seconds:
		_cancel_jump()
		return
	var progress := elapsed_seconds / _jump_config.jump_duration_seconds
	var height_m := 4.0 * _jump_config.jump_apex_height_m * progress * (1.0 - progress)
	var phase := PlayerMatchState.JumpPhase.AIRBORNE
	if elapsed_seconds < _jump_config.jump_takeoff_seconds:
		phase = PlayerMatchState.JumpPhase.TAKEOFF
	elif elapsed_seconds >= (
		_jump_config.jump_duration_seconds - _jump_config.jump_landing_seconds
	):
		phase = PlayerMatchState.JumpPhase.LANDING
	_state._set_jump_state(phase, elapsed_seconds, height_m)


## Clears the physical jump when knocked down, settled, or reset.
func _cancel_jump() -> void:
	_jump_config = null
	_state._set_jump_state(PlayerMatchState.JumpPhase.NONE, 0.0, 0.0)


## Avoids resetting elapsed movement time when a state is unchanged.
func _set_movement_state_if_changed(new_state: int) -> void:
	if _state.movement_state != new_state:
		_state._set_movement_state(new_state)


## Maintains horizontal sprite facing while allowing vertical movement and kicks.
func _update_horizontal_facing(direction: Vector2) -> void:
	if direction.x < -INPUT_EPSILON:
		_state._set_facing_direction(Vector2.LEFT)
	elif direction.x > INPUT_EPSILON:
		_state._set_facing_direction(Vector2.RIGHT)


## Drives the existing pass animation phases from elapsed simulation time.
func _advance_pass_action() -> void:
	var elapsed_seconds := _state.action_state_elapsed_seconds
	if elapsed_seconds >= PASS_ACTION_DURATION_SECONDS:
		finish_action()
	elif elapsed_seconds >= PASS_RECOVERY_SECONDS:
		set_action_phase(PlayerMatchState.ActionPhase.RECOVERY)
	elif elapsed_seconds >= PASS_WINDUP_SECONDS:
		set_action_phase(PlayerMatchState.ActionPhase.ACTIVE)


## Holds the shooting state through its configured kick frame and recovery.
func _advance_shot_action() -> void:
	assert(_shot_config != null, "Shooting requires a match configuration")
	var elapsed_seconds := _state.action_state_elapsed_seconds
	if elapsed_seconds >= _shot_config.shot_action_duration_seconds:
		finish_action()
	elif elapsed_seconds >= _shot_config.shot_recovery_seconds:
		set_action_phase(PlayerMatchState.ActionPhase.RECOVERY)
	elif elapsed_seconds >= _shot_config.shot_windup_seconds:
		set_action_phase(PlayerMatchState.ActionPhase.ACTIVE)



## Releases the temporary hit lock exactly when configured simulation time expires.
func _advance_hit_stun() -> void:
	if _state.action_state_elapsed_seconds >= _hit_stun_duration_seconds:
		finish_action()


## Advances a fixed-distance tackle along the direction captured at action start.
func _advance_tackle_motion(fixed_delta_seconds: float) -> void:
	assert(_tackle_config != null, "Tackling requires match configuration")
	var remaining_seconds := maxf(
		_tackle_config.tackle_action_duration_seconds - _state.action_state_elapsed_seconds,
		0.0,
	)
	var motion_seconds := minf(fixed_delta_seconds, remaining_seconds)
	if motion_seconds <= 0.0:
		return
	var lunge_speed_mps := (
		_tackle_config.tackle_lunge_distance_m / _tackle_config.tackle_action_duration_seconds
	)
	_state._set_position(_state.position_m + _tackle_direction * lunge_speed_mps * motion_seconds)


## Advances the tackle windup and recovery from configuration without random checks.
func _advance_tackle_action() -> void:
	assert(_tackle_config != null, "Tackling requires match configuration")
	var elapsed_seconds := _state.action_state_elapsed_seconds
	if elapsed_seconds >= _tackle_config.tackle_action_duration_seconds:
		finish_action()
	elif elapsed_seconds >= _tackle_config.tackle_recovery_seconds:
		set_action_phase(PlayerMatchState.ActionPhase.RECOVERY)
	elif elapsed_seconds >= _tackle_config.tackle_windup_seconds:
		set_action_phase(PlayerMatchState.ActionPhase.ACTIVE)


## Spreads the configured push across fixed steps without exceeding its total distance.
func _advance_knockback_motion(fixed_delta_seconds: float) -> void:
	if _knockback_direction.is_zero_approx():
		return
	assert(_knockdown_config != null, "Knockback requires match configuration")
	var remaining_seconds := maxf(
		_knockdown_config.knockdown_knockback_duration_seconds
		- _knockback_elapsed_seconds,
		0.0,
	)
	var motion_seconds := minf(fixed_delta_seconds, remaining_seconds)
	if motion_seconds <= 0.0:
		return
	var knockback_speed_mps := (
		_knockdown_config.knockdown_knockback_distance_m
		/ _knockdown_config.knockdown_knockback_duration_seconds
	)
	_state._set_position(
		_state.position_m + _knockback_direction * knockback_speed_mps * motion_seconds
	)
	_knockback_elapsed_seconds += motion_seconds


## Moves the attacker along its captured direction for exactly the configured lunge.
func _advance_knockdown_motion(fixed_delta_seconds: float) -> void:
	assert(_knockdown_config != null, "Knockdown attack requires match configuration")
	var remaining_seconds := maxf(
		_knockdown_config.knockdown_action_duration_seconds - _state.action_state_elapsed_seconds,
		0.0,
	)
	var motion_seconds := minf(fixed_delta_seconds, remaining_seconds)
	if motion_seconds <= 0.0:
		return
	var lunge_speed_mps := (
		_knockdown_config.knockdown_lunge_distance_m
		/ _knockdown_config.knockdown_action_duration_seconds
	)
	_state._set_position(
		_state.position_m + _knockdown_direction * lunge_speed_mps * motion_seconds
	)


## Advances the attack through windup, contact, recovery, and completion.
func _advance_knockdown_action() -> void:
	assert(_knockdown_config != null, "Knockdown attack requires match configuration")
	var elapsed_seconds := _state.action_state_elapsed_seconds
	if elapsed_seconds >= _knockdown_config.knockdown_action_duration_seconds:
		_state._set_action_state(
			PlayerMatchState.ActionState.LANDING,
			PlayerMatchState.ActionPhase.ACTIVE,
		)
	elif elapsed_seconds >= _knockdown_config.knockdown_recovery_seconds:
		set_action_phase(PlayerMatchState.ActionPhase.RECOVERY)
	elif elapsed_seconds >= _knockdown_config.knockdown_windup_seconds:
		set_action_phase(PlayerMatchState.ActionPhase.ACTIVE)


## Moves forward during the first header image and stops at a fixed total distance.
func _advance_header_motion(fixed_delta_seconds: float) -> void:
	assert(_header_config != null, "Heading requires match configuration")
	var first_frame_seconds := _header_config.header_first_frame_seconds
	var remaining_seconds := maxf(
		first_frame_seconds - _state.action_state_elapsed_seconds, 0.0,
	)
	var motion_seconds := minf(fixed_delta_seconds, remaining_seconds)
	if motion_seconds <= 0.0:
		return
	_state._set_position(_state.position_m + _header_direction * (
		HEADER_FORWARD_DISTANCE_M / first_frame_seconds
	) * motion_seconds)


## Keeps both header frames for their full duration before starting the landing pose.
func _advance_header_action() -> void:
	assert(_header_config != null, "Heading requires match configuration")
	var header_duration := (
		_header_config.header_first_frame_seconds
		+ _header_config.header_second_frame_seconds
	)
	if _state.action_state_elapsed_seconds + INPUT_EPSILON < header_duration:
		return
	_cancel_jump()
	_is_header_landing = true
	_state._set_action_state(
		PlayerMatchState.ActionState.LANDING,
		PlayerMatchState.ActionPhase.ACTIVE,
	)


## Holds the attacker in its final landing pose before releasing the action lock.
func _advance_landing() -> void:
	var landing_duration_seconds := HEADER_LANDING_DURATION_SECONDS
	if not _is_header_landing:
		assert(_knockdown_config != null, "Landing requires match configuration")
		landing_duration_seconds = (
			_knockdown_config.knockdown_landing_animation_seconds
			+ _knockdown_config.knockdown_crouch_hold_seconds
		)
	if _state.action_state_elapsed_seconds >= landing_duration_seconds:
		finish_action()


## Leaves the target on the ground until its fixed-step down timer expires.
func _advance_knocked_down() -> void:
	assert(_knockdown_config != null, "Knockdown target requires match configuration")
	if _state.action_state_elapsed_seconds >= _knockdown_config.knockdown_down_seconds:
		_state._set_action_state(
			PlayerMatchState.ActionState.GETTING_UP,
			PlayerMatchState.ActionPhase.RECOVERY,
		)


## Restores action eligibility only after the configured get-up interval.
func _advance_getting_up() -> void:
	assert(_knockdown_config != null, "Getting up requires match configuration")
	if _state.action_state_elapsed_seconds >= _knockdown_config.knockdown_get_up_seconds:
		finish_action()
