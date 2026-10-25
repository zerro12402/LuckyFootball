## Assembles production AI and observer controls without keyboard or developer-preset dependencies.
class_name FormalMatchBootstrap
extends Node2D

signal startup_failed(errors: PackedStringArray)
signal presentation_frame_ready(snapshot: MatchStateSnapshot, events: Array[MatchEvent], alpha: float)

@export var home_team_id: String = "home"
@export var away_team_id: String = "away"
@export var match_id: String = ""
@export var random_seed: int = 1
@export var autonomous_players: bool = true
@onready var _field: FieldEnvironment = %FieldEnvironment

static var _instance_sequence: int = 0
var _simulation: MatchSimulation
var _loop: GameLoop
var _data: DataRepository
var _teams: TeamDataRepository
var _config: MatchConfigDefinition
var _status: Label
var _pause_button: Button
var _sources: Array[MatchActionSource] = []
var last_errors: PackedStringArray = []

## Validates all data before publishing a READY session, then creates observer lifecycle controls.
func _ready() -> void:
	_data = DataRepository.new()
	if not _data.load_all():
		_fail(_data.last_errors)
		return
	_teams = _data.load_formal_teams()
	if _teams == null:
		_fail(_data.last_errors)
		return
	_config = _data.get_match_config_by_id("demo_match")
	_instance_sequence += 1
	if match_id.is_empty():
		match_id = "formal_%d" % _instance_sequence
	var assembler := FormalMatchAssembler.new()
	_simulation = assembler.create_match(_data, _teams, _data.get_field_by_id("demo_field"), _config, match_id, random_seed, home_team_id, away_team_id)
	if _simulation == null:
		_fail(assembler.errors)
		return
	if autonomous_players and _sources.is_empty():
		var tuning := _data.load_ai_config()
		if tuning == null:
			_fail(_data.last_errors)
			return
		var source := MatchPlayerAISource.new(_teams, _data.get_field_by_id("demo_field"), _config, tuning)
		if not source.errors.is_empty():
			_fail(source.errors)
			return
		_sources.append(source)
	_loop = GameLoop.new(_simulation, GameLoop.DEFAULT_FIXED_DELTA_SECONDS,
		GameLoop.DEFAULT_MAX_FRAME_DELTA_SECONDS, GameLoop.DEFAULT_MAX_STEPS_PER_FRAME, null, [], _sources)
	_field.configure(_data.get_field_by_id("demo_field"))
	_field.set_debug_enabled(false)
	_field.configure_roster(_simulation.create_snapshot(), _config)
	_build_controls()
	_present(_loop.advance_frame(0.0, []))

## Reports setup failure without leaving a partially active match or half-populated field.
func _fail(errors: PackedStringArray) -> void:
	last_errors = errors.duplicate()
	set_process(false)
	_field.visible = false
	startup_failed.emit(last_errors)

## Drives the same fixed-step loop as development matches, with no player keyboard input.
func _process(delta: float) -> void:
	if _loop != null:
		_present(_loop.advance_frame(delta, []))

## Lets a later production AI assembler supply authorized sources without importing its implementation.
func set_action_sources(sources: Array[MatchActionSource]) -> bool:
	if _simulation != null and _simulation.create_snapshot().phase != MatchState.Phase.READY:
		return false
	_sources = sources.duplicate()
	if _simulation != null:
		_loop = GameLoop.new(_simulation, GameLoop.DEFAULT_FIXED_DELTA_SECONDS,
			GameLoop.DEFAULT_MAX_FRAME_DELTA_SECONDS, GameLoop.DEFAULT_MAX_STEPS_PER_FRAME, null, [], _sources)
	return true

## Returns a detached observation, or no observation when transactional setup failed.
func get_snapshot() -> MatchStateSnapshot:
	return _simulation.create_snapshot() if _simulation != null else null

## Starts only through the validated lifecycle controller; repeated requests have no effect.
func start_match() -> bool:
	return _simulation != null and _simulation.start_match()

## Preserves the paused round, invalidates queued intent and refreshes observer control text.
func toggle_pause() -> bool:
	if _simulation == null:
		return false
	if _simulation.create_snapshot().phase == MatchState.Phase.PAUSED:
		return _simulation.resume_match()
	return _simulation.pause_match()

## Cancels observation without creating a normal official result.
func cancel_match() -> bool:
	return _simulation != null and _simulation.cancel_match("observer_cancelled")

## Provides only match lifecycle controls; this interface never creates player commands.
func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MatchControls"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(272, 12)
	panel.custom_minimum_size = Vector2(310, 0)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	for entry in [["开始比赛", start_match], ["暂停 / 恢复", toggle_pause], ["取消比赛", cancel_match]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		box.add_child(button)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

## Displays copied phase/time/team scores and immutable terminal facts without changing match state.
func _present(frame: MatchFrameResult) -> void:
	_field.present(frame.snapshot)
	_field.present_events(frame.events)
	var snapshot := frame.snapshot
	var phases := ["等待开始", "比赛中", "已暂停", "比赛结束", "比赛已取消"]
	var rounds := ["正常比赛", "进球确认", "球网运动", "出界等待", "重置"]
	_status.text = "%s %d : %d %s\n%s · %s\n剩余 %.1f 秒 · 回合 %d\n球员决策：%s" % [
		_teams.get_team(snapshot.home_team_id).display_name, snapshot.home_score, snapshot.away_score,
		_teams.get_team(snapshot.away_team_id).display_name, phases[snapshot.phase], rounds[snapshot.round_phase],
		snapshot.remaining_seconds, snapshot.round_sequence, "允许" if snapshot.can_decide_player_actions else "暂停"]
	if snapshot.result != null:
		_status.text += "\n赛果：" + ["主队获胜", "平局", "客队获胜"][snapshot.result.outcome]
	elif snapshot.phase == MatchState.Phase.CANCELLED:
		_status.text += "\n本场取消，无正式赛果"
	elif _sources.is_empty():
		_status.text += "\n战术AI待接入，当前为空动作来源"
	presentation_frame_ready.emit(snapshot, frame.events, frame.interpolation_alpha)
