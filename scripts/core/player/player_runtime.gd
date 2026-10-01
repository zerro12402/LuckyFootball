## Owns one player's state machine and validated static shooting attribute.
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

var state: PlayerMatchState:
	get:
		return _state_machine.state

var state_machine: PlayerStateMachine:
	get:
		return _state_machine

var _state_machine: PlayerStateMachine
var _team_id: String
var _shooting_attribute: int


## Reserves attribute zero for tests that do not register a player definition.
func _init(
	new_player_id: String,
	initial_position_m: Vector2,
	movement_speed_mps: float = PlayerStateMachine.DEFAULT_MOVEMENT_SPEED_MPS,
	new_team_id: String = "default_team",
	new_shooting_attribute: int = 0,
) -> void:
	assert(not new_team_id.is_empty(), "Player runtime requires a team ID")
	assert(new_shooting_attribute >= 0 and new_shooting_attribute <= 100)
	var initial_state := PlayerMatchState.new(new_player_id, initial_position_m)
	_state_machine = PlayerStateMachine.new(initial_state, movement_speed_mps)
	_team_id = new_team_id
	_shooting_attribute = new_shooting_attribute


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
