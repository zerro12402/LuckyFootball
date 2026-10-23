## Offers keeper presets in the existing shared scene; results always come from simulation.
class_name GoalkeeperTestControls
extends CanvasLayer

var _bootstrap: GameBootstrap
var _contest: OptionButton
var _shooting: LineEdit
var _goalkeeping: LineEdit
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
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(335.0, minf(500.0, get_viewport().get_visible_rect().size.y - 24.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_contest = _options(box, "射门对抗预设", ["原有站位", "近射", "远射", "先击飞1人", "先击飞2人"])
	_shooting = _attribute_input(box, "射门球员射门值（1～100）")
	_goalkeeping = _attribute_input(box, "防守员守门值（1～100）")
	_bootstrap.game_started.connect(_initialize_attributes)
	_source = _options(box, "射门来源", ["普通射门", "空中射门", "头球攻门"])
	_down = CheckButton.new()
	_down.text = "门将初始倒地"
	box.add_child(_down)
	_button(box, "开始 / 固定种子重放", _select)
	_button(box, "重置（K射门）", _reset)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
func _configure() -> bool:
	var shooting_text := _shooting.text.strip_edges()
	var goalkeeping_text := _goalkeeping.text.strip_edges()
	if not shooting_text.is_valid_int() or not goalkeeping_text.is_valid_int():
		_status.text = "射门值和守门值均须为1～100的整数"
		return false
	if not _bootstrap.set_keeper_test_attributes(shooting_text.to_int(), goalkeeping_text.to_int()):
		_status.text = "射门值和守门值均须为1～100的整数"
		return false
	_bootstrap.keeper_contest_preset = _contest.selected as GameBootstrap.KeeperContestPreset
	_bootstrap.shot_miss_override = -1
	_bootstrap.shot_miss_side = 0
	_bootstrap.shot_miss_margin_m = 1.0
	_bootstrap.keeper_lane = -1
	_bootstrap.keeper_sample = -1.0
	_bootstrap.keeper_source = _source.selected as GameBootstrap.KeeperShotSource
	_bootstrap.keeper_starts_down = _down.button_pressed
	return true

## Starts or replays the selected setup through the existing action protocol.
func _select() -> void:
	if _configure():
		_bootstrap.select_keeper_preset()

## Restores the selected setup without an automatic kick.
func _reset() -> void:
	if _configure():
		_bootstrap.select_keeper_preset(false)

## Displays immutable outcomes without sampling or changing ownership.
func _present(_snapshot: MatchStateSnapshot, events: Array[MatchEvent], _alpha: float) -> void:
	for event in events:
		if event.event_type in [MatchEvent.Type.BALL_SHOT, MatchEvent.Type.BALL_HEADED] and event.shot_aim != null:
			var aim := event.shot_aim
			_status.text = ("准确性：射偏（%s，%.2fm）" % ["上侧" if aim.post_side < 0 else "下侧", aim.miss_margin_m]
				if aim.is_miss else "准确性：未射偏（%s）" % ["上路", "中路", "下路"][aim.lane])
			_status.text += "\n射偏率：%.1f%%；扑救：未判定" % (aim.miss_probability * 100.0)
		elif event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED:
			var save := event.goalkeeper_save
			_status.text += " → 扑救：抱球" if save.did_catch else " → 扑救：漏球"
			_status.text += "\nS0=%d  G=%d  d=%.2fm  n=%d" % [save.base_shooting, save.goalkeeping, save.distance_m, save.knockdown_count]
			_status.text += "\n距离倍率=%.3f  击飞倍率=%.3f\n有效射门=%.2f" % [save.distance_multiplier, save.knockdown_multiplier, save.effective_shooting]
			_status.text += "\n射门胜出=%.1f%%  守住=%.1f%%\n样本u=%.4f" % [save.shot_win_probability * 100.0, save.save_probability * 100.0, save.sample]
		elif event.event_type == MatchEvent.Type.GOAL_SCORED:
			_status.text += " → 进球"


## Creates a plain numeric text input; validation happens atomically before starting the next match.
func _attribute_input(box: VBoxContainer, title: String) -> LineEdit:
	var label := Label.new()
	label.text = title
	box.add_child(label)
	var input := LineEdit.new()
	input.placeholder_text = "1～100的整数"
	input.text_submitted.connect(_submit_attributes)
	box.add_child(input)
	return input

## Allows Enter to apply the same validated settings as the start button.
func _submit_attributes(_text: String) -> void:
	_select()

## Fills initial values from the real runtime once, preserving edits during reset and replay.
func _initialize_attributes(_snapshot: MatchStateSnapshot) -> void:
	var attributes := _bootstrap.get_keeper_test_attributes()
	if _shooting.text.is_empty():
		_shooting.text = str(attributes.x)
	if _goalkeeping.text.is_empty():
		_goalkeeping.text = str(attributes.y)
