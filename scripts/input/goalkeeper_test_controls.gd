## Offers keeper presets in the existing shared scene; results always come from simulation.
class_name GoalkeeperTestControls
extends CanvasLayer

var _bootstrap: GameBootstrap
var _lane: OptionButton
var _result: OptionButton
var _source: OptionButton
var _down: CheckButton
var _status: Label

## Builds only presentation controls, keeping this feature out of separate test scenes.
func _ready() -> void:
	_bootstrap = get_parent() as GameBootstrap
	visible = _bootstrap.demo_mode == GameBootstrap.DemoMode.GOALKEEPER_TEST
	if not visible:
		return
	var panel := PanelContainer.new()
	panel.position = Vector2(272, 12)
	panel.custom_minimum_size = Vector2(295, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_lane = _options(box, "射门目标", ["随机上中下", "上路", "中路", "下路"])
	_result = _options(box, "扑救结果", ["种子随机（50%）", "固定成功", "固定失败"])
	_source = _options(box, "射门来源", ["普通射门", "空中射门", "头球攻门"])
	_down = CheckButton.new()
	_down.text = "门将初始倒地"
	box.add_child(_down)
	_button(box, "开始 / 固定种子重放", _select)
	_button(box, "重置（K射门）", _reset)
	_status = Label.new()
	_status.text = "选好预设后开始；接触时才判定"
	box.add_child(_status)
	_bootstrap.presentation_frame_ready.connect(_present)

## Keeps labels separate from rule/config values and returns the selected test option.
func _options(box: VBoxContainer, title: String, labels: Array[String]) -> OptionButton:
	var label := Label.new()
	label.text = title
	box.add_child(label)
	var option := OptionButton.new()
	for text in labels:
		option.add_item(text)
	box.add_child(option)
	return option

## Wires a normal UI button to a test preset command.
func _button(box: VBoxContainer, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	box.add_child(button)

## Publishes selected inputs before reconstructing a reproducible test match.
func _configure() -> void:
	_bootstrap.keeper_lane = _lane.selected - 1
	_bootstrap.keeper_sample = [-1.0, 0.0, 0.99][_result.selected]
	_bootstrap.keeper_source = _source.selected as GameBootstrap.KeeperShotSource
	_bootstrap.keeper_starts_down = _down.button_pressed

## Starts or replays the selected setup through the existing action protocol.
func _select() -> void:
	_configure()
	_bootstrap.select_keeper_preset()

## Restores the selected setup without an automatic kick.
func _reset() -> void:
	_configure()
	_bootstrap.select_keeper_preset(false)

## Displays immutable outcomes without sampling or changing ownership.
func _present(_snapshot: MatchStateSnapshot, events: Array[MatchEvent], _alpha: float) -> void:
	for event in events:
		if event.event_type == MatchEvent.Type.BALL_SHOT and event.shot_aim != null:
			_status.text = "射向" + ["上路", "中路", "下路"][event.shot_aim.lane]
		elif event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED:
			_status.text += "：抱球" if event.goalkeeper_save.did_catch else "：漏球"
		elif event.event_type == MatchEvent.Type.GOAL_SCORED:
			_status.text += " → 进球"
