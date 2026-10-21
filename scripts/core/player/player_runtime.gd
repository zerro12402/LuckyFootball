## Owns one player's state machine and explicit contest attributes.
class_name PlayerRuntime
extends RefCounted

var player_id: String:
	get:
		return _state_machine.state.player_id

var team_id: String:
	get:
		return _team_id

var shooting_attribute: int:
	get:
		return _shooting_attribute

var strength_attribute: int:
	get:
		return _strength_attribute

var technique_attribute: int:
	get:
		return _technique_attribute

var state: PlayerMatchState:
	get:
		return _state_machine.state

var state_machine: PlayerStateMachine:
	get:
		return _state_machine

var is_goalkeeper: bool:
	get: return _is_goalkeeper

var _state_machine: PlayerStateMachine
var _spawn_position_m: Vector2
var _team_id: String
var _shooting_attribute: int
var _strength_attribute: int
var _technique_attribute: int
var _is_goalkeeper: bool


## Reserves attribute zero for tests that do not register a player definition.
func _init(
	new_player_id: String,
	initial_position_m: Vector2,
	movement_speed_mps: float = PlayerStateMachine.DEFAULT_MOVEMENT_SPEED_MPS,
	new_team_id: String = "default_team",
	new_shooting_attribute: int = 0,
	new_strength_attribute: int = 50,
	new_technique_attribute: int = 50,
	new_is_goalkeeper: bool = false,
) -> void:
	assert(not new_team_id.is_empty(), "Player runtime requires a team ID")
	assert(new_shooting_attribute >= 0 and new_shooting_attribute <= 100)
	assert(new_strength_attribute >= 0 and new_strength_attribute <= 100)
	assert(new_technique_attribute >= 0 and new_technique_attribute <= 100)
	var initial_state := PlayerMatchState.new(new_player_id, initial_position_m)
	_state_machine = PlayerStateMachine.new(initial_state, movement_speed_mps)
	_spawn_position_m = initial_position_m
	_team_id = new_team_id
	_shooting_attribute = new_shooting_attribute
	_strength_attribute = new_strength_attribute
	_technique_attribute = new_technique_attribute
	_is_goalkeeper = new_is_goalkeeper


## Returns the runtime to its registered spawn without changing static attributes.
func reset_to_spawn() -> void:
	_state_machine.reset_to_spawn(_spawn_position_m)


## Applies only commands whose player ID matches this runtime.
func apply_action(action: MatchAction) -> bool:
	if action == null or action.player_id != player_id:
		return false
	if action.action_type == MatchAction.Type.MOVE:
		return _state_machine.set_movement_input(action.direction)
	return false


## Advances this player's movement and action state by one fixed step.
func advance(fixed_delta_seconds: float) -> void:
	_state_machine.advance(fixed_delta_seconds)
