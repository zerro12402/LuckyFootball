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

@export_range(0.001, 0.1, 0.001) var fixed_delta_seconds: float = 1.0 / 60.0
@export var random_seed: int = 1

@onready var _field_environment: FieldEnvironment = (
	get_node_or_null("FieldEnvironment") as FieldEnvironment
)

var data_repository: DataRepository:
	get:
		return _data_repository

var _data_repository: DataRepository
var _match_controller: MatchController
var _game_loop: GameLoop
var _queued_actions: Array[MatchAction] = []


func _ready() -> void:
	set_process(false)
	_data_repository = DataRepository.new()
	if not _data_repository.load_all():
		startup_failed.emit(_data_repository.last_errors)
		return

	var field_definition := _data_repository.get_field_by_id("demo_field")
	if field_definition == null:
		startup_failed.emit(PackedStringArray(["Missing demo_field definition"]))
		return
	if _field_environment != null:
		_field_environment.configure(field_definition)

	var player_definitions := _data_repository.player_definitions
	if player_definitions.is_empty():
		startup_failed.emit(PackedStringArray(["At least one player is required"]))
		return
	var demo_player := player_definitions[0]

	_match_controller = MatchController.new(random_seed)
	var did_register_player := _match_controller.register_player(
		demo_player.player_id,
		Vector2.ZERO,
	)
	assert(did_register_player, "Demo player must register before the match starts")
	if _field_environment != null:
		_field_environment.set_presented_player(demo_player.player_id)

	_game_loop = GameLoop.new(_match_controller, fixed_delta_seconds)
	var did_start := _match_controller.start_match()
	assert(did_start, "A new match must start from the ready phase")
	var initial_snapshot := _match_controller.create_snapshot()
	game_started.emit(initial_snapshot)
	_publish_frame(0.0)
	set_process(true)


func _process(delta: float) -> void:
	_publish_frame(delta)


func queue_action(action: MatchAction) -> void:
	assert(action != null, "Cannot queue a null MatchAction")
	_queued_actions.append(action)


func pause_match() -> bool:
	if _match_controller == null:
		return false
	return _match_controller.pause_match()


func resume_match() -> bool:
	if _match_controller == null:
		return false
	return _match_controller.resume_match()


func finish_match() -> bool:
	if _match_controller == null or not _match_controller.finish_match():
		return false
	_publish_frame(0.0)
	set_process(false)
	game_finished.emit(_match_controller.create_snapshot())
	return true


func _publish_frame(frame_delta_seconds: float) -> void:
	var frame_actions: Array[MatchAction] = _queued_actions.duplicate()
	_queued_actions.clear()
	var frame_result := _game_loop.advance_frame(frame_delta_seconds, frame_actions)
	if _field_environment != null:
		_field_environment.present(frame_result.snapshot)
	presentation_frame_ready.emit(
		frame_result.snapshot,
		frame_result.events,
		frame_result.interpolation_alpha,
	)
