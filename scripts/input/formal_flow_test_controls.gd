## Development-only lifecycle presets in the existing shared demo scene, isolated from formal resources.
class_name FormalFlowTestControls
extends CanvasLayer

const SESSION_SCENE := preload("res://scenes/match/formal_match.tscn")
var _session: FormalMatchBootstrap
var _status: Label

## Defers until the common bootstrap has disabled its legacy player-controlled simulation.
func _ready() -> void:
	visible = (get_parent() as GameBootstrap).demo_mode == GameBootstrap.DemoMode.FORMAL_FLOW_TEST
	if visible:
		call_deferred("_build")

## Adds flow presets beside the production session's normal lifecycle controls.
func _build() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(600, 12)
	panel.custom_minimum_size = Vector2(320, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	for entry in [["准备新比赛", 0], ["进球与重置预设", 1], ["带球出界与重置预设", 2], ["临近终场预设", 3]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(select_preset.bind(entry[1]))
		box.add_child(button)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	select_preset(0)

## Prepares explicit test state before play; real actions, boundaries, settlement and clock produce results.
func select_preset(preset: int) -> void:
	if _session != null:
		_session.cancel_match()
		get_parent().remove_child(_session)
		_session.queue_free()
	_session = SESSION_SCENE.instantiate() as FormalMatchBootstrap
	_session.autonomous_players = false
	_session.name = "FormalSession"
	get_parent().add_child(_session)
	_session.presentation_frame_ready.connect(_present)
	var simulation := _session._simulation
	if simulation == null:
		_status.text = "装配失败：" + str(_session.last_errors)
		return
	if preset in [1, 2]:
		var player := simulation._player_runtime_system.get_player("swift_forward")
		var point := Vector2(22, 0) if preset == 1 else Vector2(0, -_session._data.get_field_by_id("demo_field").width_m * 0.5 + 0.25)
		player.state._set_position(point)
		simulation._ball_runtime_system.reset_ball(point + Vector2(0.55, 0))
		if preset == 1:
			simulation._shot_miss_override = 0
			simulation._shot_aim_sampler = func() -> int: return ShotAim.Lane.CENTER
			for runtime in simulation._player_runtime_system.get_players():
				if runtime.is_goalkeeper and runtime.team_id != player.team_id:
					runtime.state_machine.start_knockdown(_session._config)
		_session.set_action_sources([FormalPresetActionSource.new(player.player_id, preset == 2)])
	if preset > 0:
		_session.start_match()
	if preset == 3:
		while simulation.create_snapshot().remaining_seconds > 0.25:
			var remaining := simulation.create_snapshot().remaining_seconds
			simulation.advance_fixed_step(minf(0.1, remaining - 0.25), [])
	_session._loop.reset_timing()
	_session._process(0.0)
	_status.text = "开发预设：状态、队比分和决策权限见左侧\n开始、暂停/恢复、取消使用正常比赛控制\n完整战术AI不属于此预设"

## Displays only committed ordered phase and boundary facts from the actual session.
func _present(snapshot: MatchStateSnapshot, events: Array[MatchEvent], _alpha: float) -> void:
	for event in events:
		if event.event_type in [MatchEvent.Type.GOAL_SCORED, MatchEvent.Type.BALL_OUT_OF_BOUNDS, MatchEvent.Type.RESET_COMPLETED, MatchEvent.Type.MATCH_FINISHED, MatchEvent.Type.MATCH_CANCELLED]:
			_status.text = "已提交事件：%s\n比赛时间 %.2f秒，回合 %d\n决策权限：%s" % [MatchEvent.Type.keys()[event.event_type], snapshot.elapsed_seconds, snapshot.round_sequence, snapshot.can_decide_player_actions]
