## Builds test matches and connects input, fixed simulation, and presentation.
class_name GameBootstrap
extends Node

signal startup_failed(errors: PackedStringArray)
signal game_started(snapshot: MatchStateSnapshot)
signal presentation_frame_ready(
	snapshot: MatchStateSnapshot,
	events: Array[MatchEvent],
	interpolation_alpha: float,
)
signal game_finished(snapshot: MatchStateSnapshot)

enum DemoMode {
	TOUCH_AND_DRIBBLE,
	PASS_AND_SHOOT,
	TACKLE_TEST,
	KNOCKDOWN_TEST,
}

const TEST_PLAYER_MOVEMENT_SPEED_MPS := 5.0
const TEST_TEAMMATE_POSITION_M := Vector2(10.0, -2.0)
const TEST_OPPONENT_POSITION_M := Vector2(6.0, 0.0)
const TEST_KNOCKDOWN_OPPONENT_POSITION_M := Vector2(1.05, 0.0)
const TEST_OPPONENT_TEAM_ID := "opponent_team"
const TEST_BALL_INITIAL_POSITION_M := Vector2(3.0, 0.0)
const TEST_TEAM_ID := "demo_team"

@export_range(0.001, 0.1, 0.001) var fixed_delta_seconds: float = 1.0 / 60.0
@export var random_seed: int = 1
@export var demo_mode: DemoMode = DemoMode.PASS_AND_SHOOT

@onready var _field_environment: FieldEnvironment = (
	get_node_or_null("FieldEnvironment") as FieldEnvironment
)
@onready var _keyboard_input: KeyboardPlayerInputAdapter = (
	get_node_or_null("KeyboardPlayerInputAdapter") as KeyboardPlayerInputAdapter
)
@onready var _result_hud: MatchResultHud = (
	get_node_or_null("MatchResultHud") as MatchResultHud
)

var data_repository: DataRepository:
	get:
		return _data_repository

var _data_repository: DataRepository
var _field_definition: FieldDefinition
var _match_config: MatchConfigDefinition
var _match_simulation: MatchSimulation
var _game_loop: GameLoop
var _queued_actions: Array[MatchAction] = []
var _demo_player_id: String = ""
var _demo_teammate_id: String = ""
var _demo_opponent_id: String = ""


## Loads static data, wires demo controls, and starts a reproducible match.
func _ready() -> void:
	set_process(false)
	_data_repository = DataRepository.new()
	if not _data_repository.load_all():
		startup_failed.emit(_data_repository.last_errors)
		return

	_field_definition = _data_repository.get_field_by_id("demo_field")
	if _field_definition == null:
		startup_failed.emit(PackedStringArray(["Missing demo_field definition"]))
		return
	_match_config = _data_repository.get_match_config_by_id("demo_match")
	if _match_config == null:
		startup_failed.emit(PackedStringArray(["Missing demo_match configuration"]))
		return
	if _field_environment != null:
		_field_environment.configure(_field_definition)
		_field_environment.configure_hit_stun(_match_config.tackle_hit_stun_seconds)
		_field_environment.configure_tackle_duration(_match_config.tackle_action_duration_seconds)
		_field_environment.configure_knockdown(
			_match_config.knockdown_action_duration_seconds,
			_match_config.knockdown_jump_height_m,
			_match_config.knockdown_landing_animation_seconds,
		)

	var player_definitions := _data_repository.player_definitions
	var required_player_count := 1
	if demo_mode != DemoMode.TOUCH_AND_DRIBBLE:
		required_player_count = 2
	if player_definitions.size() < required_player_count:
		startup_failed.emit(PackedStringArray(["Demo players are missing"]))
		return
	_demo_player_id = player_definitions[0].player_id
	_demo_teammate_id = ""
	_demo_opponent_id = ""
	if demo_mode == DemoMode.PASS_AND_SHOOT:
		_demo_teammate_id = player_definitions[1].player_id
	elif demo_mode in [DemoMode.TACKLE_TEST, DemoMode.KNOCKDOWN_TEST]:
		_demo_opponent_id = player_definitions[1].player_id
	if _field_environment != null:
		var second_player_id := _demo_teammate_id
		if not _demo_opponent_id.is_empty():
			second_player_id = _demo_opponent_id
		_field_environment.set_presented_players(
			_demo_player_id,
			second_player_id,
			demo_mode in [DemoMode.TACKLE_TEST, DemoMode.KNOCKDOWN_TEST],
		)
	if _keyboard_input != null:
		_keyboard_input.action_requested.connect(queue_action)
		if _field_environment != null:
			_keyboard_input.meter_ticks_toggle_requested.connect(
				_field_environment.toggle_meter_ticks
			)

	reset_demo()


## Rebuilds demo runtimes with a field-derived opponent goal and fresh input.
func reset_demo() -> void:
	if _data_repository == null or _demo_player_id.is_empty():
		return
	set_process(false)
	_queued_actions.clear()
	_match_simulation = MatchSimulation.new(random_seed, _match_config, _field_definition)
	var opponent_goal_center_m := Vector2(_field_definition.length_m * 0.5, 0.0)
	var did_register_goal := _match_simulation.register_team_attacking_goal(
		TEST_TEAM_ID,
		opponent_goal_center_m,
	)
	assert(did_register_goal, "Demo team requires an opponent goal before play")
	var demo_player := _data_repository.get_player_by_id(_demo_player_id)
	var did_register_player := _match_simulation.register_player(
		_demo_player_id,
		Vector2.ZERO,
		TEST_PLAYER_MOVEMENT_SPEED_MPS,
		TEST_TEAM_ID,
		demo_player.shooting,
	)
	assert(did_register_player, "Demo player must register before the match starts")
	if not _demo_teammate_id.is_empty():
		var demo_teammate := _data_repository.get_player_by_id(_demo_teammate_id)
		var did_register_teammate := _match_simulation.register_player(
			_demo_teammate_id,
			TEST_TEAMMATE_POSITION_M,
			TEST_PLAYER_MOVEMENT_SPEED_MPS,
			TEST_TEAM_ID,
			demo_teammate.shooting,
		)
		assert(did_register_teammate, "Demo teammate must register before the match starts")
	if not _demo_opponent_id.is_empty():
		var opponent := _data_repository.get_player_by_id(_demo_opponent_id)
		var opponent_position_m := TEST_OPPONENT_POSITION_M
		if demo_mode == DemoMode.KNOCKDOWN_TEST:
			opponent_position_m = TEST_KNOCKDOWN_OPPONENT_POSITION_M
		assert(_match_simulation.register_player(
			_demo_opponent_id, opponent_position_m,
			TEST_PLAYER_MOVEMENT_SPEED_MPS, TEST_OPPONENT_TEAM_ID, opponent.shooting
		))
	var initial_ball_position_m := TEST_BALL_INITIAL_POSITION_M
	if demo_mode == DemoMode.TACKLE_TEST:
		initial_ball_position_m = Vector2(0.5, 0.0)
	elif demo_mode == DemoMode.KNOCKDOWN_TEST:
		initial_ball_position_m = Vector2(1.6, 0.0)
	var did_register_ball := _match_simulation.register_ball(
		initial_ball_position_m,
	)
	assert(did_register_ball, "Demo ball must register before the match starts")
	var tackle_ai: TackleChaseAI
	if not _demo_opponent_id.is_empty():
		var defender_goal_center_m := Vector2(-_field_definition.length_m * 0.5, 0.0)
		assert(_match_simulation.register_team_attacking_goal(
			TEST_OPPONENT_TEAM_ID, defender_goal_center_m
		))
		if demo_mode == DemoMode.TACKLE_TEST:
			tackle_ai = TackleChaseAI.new(
				_demo_opponent_id, _demo_player_id, _match_config, defender_goal_center_m
			)
	_game_loop = GameLoop.new(
		_match_simulation, fixed_delta_seconds,
		GameLoop.DEFAULT_MAX_FRAME_DELTA_SECONDS,
		GameLoop.DEFAULT_MAX_STEPS_PER_FRAME, tackle_ai
	)
	if _keyboard_input != null:
		_keyboard_input.configure(_demo_player_id, _demo_teammate_id, _demo_opponent_id)

	var did_start := _match_simulation.start_match()
	assert(did_start, "A new match must start from the ready phase")
	var initial_snapshot := _match_simulation.create_snapshot()
	game_started.emit(initial_snapshot)
	_publish_frame(0.0)
	set_process(true)

## Advances and presents the match from the display frame clock.
func _process(delta: float) -> void:
	_publish_frame(delta)


## Buffers commands for the next fixed step, including in-match reset requests.
func queue_action(action: MatchAction) -> void:
	assert(action != null, "Cannot queue a null MatchAction")
	if (
		action.action_type == MatchAction.Type.RESTART_TEST
		and _match_simulation != null
		and not _match_simulation.is_running()
	):
		reset_demo()
		return
	_queued_actions.append(action)


## Pauses the active match when one exists.
func pause_match() -> bool:
	if _match_simulation == null:
		return false
	return _match_simulation.pause_match()


## Resumes the match and refreshes movement input.
func resume_match() -> bool:
	if _match_simulation == null:
		return false
	var did_resume := _match_simulation.resume_match()
	if did_resume and _keyboard_input != null:
		_keyboard_input.force_resend()
	return did_resume


## Publishes the final frame before stopping updates.
func finish_match() -> bool:
	if _match_simulation == null or not _match_simulation.finish_match():
		return false
	_publish_frame(0.0)
	set_process(false)
	game_finished.emit(_match_simulation.create_snapshot())
	return true


## Feeds queued actions to the fixed loop and broadcasts the resulting snapshot.
func _publish_frame(frame_delta_seconds: float) -> void:
	var frame_actions: Array[MatchAction] = _queued_actions.duplicate()
	_queued_actions.clear()
	var frame_result := _game_loop.advance_frame(frame_delta_seconds, frame_actions)
	for event in frame_result.events:
		if event.event_type == MatchEvent.Type.RESET_COMPLETED and _keyboard_input != null:
			_keyboard_input.configure(_demo_player_id, _demo_teammate_id, _demo_opponent_id)
			break
	if _field_environment != null:
		_field_environment.present(frame_result.snapshot)
		_field_environment.present_events(frame_result.events)
	if _result_hud != null:
		_result_hud.present(frame_result.snapshot, frame_result.events)
	presentation_frame_ready.emit(
		frame_result.snapshot,
		frame_result.events,
		frame_result.interpolation_alpha,
	)
