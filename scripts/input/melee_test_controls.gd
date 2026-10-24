## Configures the existing near-body test modes and displays committed F05/F06 facts only.
class_name MeleeTestControls
extends CanvasLayer

var _bootstrap: GameBootstrap
var _attack: LineEdit
var _defense: LineEdit
var _technique: LineEdit
var _dodge: LineEdit
var _strength: LineEdit
var _owner: CheckButton
var _reverse: CheckButton
var _override: OptionButton
var _status: Label

## Builds a compact shared-scene panel without introducing a separate gameplay or test scene.
func _ready() -> void:
	_bootstrap = get_parent() as GameBootstrap
	visible = _bootstrap.demo_mode in [GameBootstrap.DemoMode.KNOCKDOWN_TEST, GameBootstrap.DemoMode.ATTACK_RECOIL_TEST]
	if not visible:
		return
	var panel := PanelContainer.new()
	panel.position = Vector2(272, 12)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(365, minf(610, get_viewport().get_visible_rect().size.y - 24))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_attack = _text_input(box, "进攻者强壮（1～100）")
	_defense = _text_input(box, "目标强壮（1～100）")
	_technique = _text_input(box, "目标技巧（1～100）")
	_dodge = _text_input(box, "F05样本（留空随机，0≤u<1）")
	_strength = _text_input(box, "F06样本（留空随机，0≤u<1）")
	_owner = CheckButton.new()
	_owner.text = "目标初始持球"
	_owner.button_pressed = true
	box.add_child(_owner)
	_reverse = CheckButton.new()
	_reverse.text = "向左攻击"
	box.add_child(_reverse)
	_override = OptionButton.new()
	for title in ["正常属性公式", "开发强制：目标倒地", "开发强制：攻击者反弹", "开发强制：双方倒地", "开发强制：闪避"]:
		_override.add_item(title)
	box.add_child(_override)
	_button(box, "应用并攻击 / 固定种子重放", _apply.bind(true))
	_button(box, "应用并重置（L攻击，~重置）", _apply.bind(false))
	for entry in [["随机判定", 0], ["预设：进攻者胜", 1], ["预设：目标胜", 2], ["预设：平局", 3], ["预设：闪避", 4]]:
		_button(box, entry[0], _preset.bind(entry[1]))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "按L攻击；首次合法接触才判定"
	box.add_child(_status)
	_bootstrap.game_started.connect(_initialize)
	_bootstrap.presentation_frame_ready.connect(_present)

## Adds a labeled text field; validation remains atomic in the bootstrap adapter.
func _text_input(box: VBoxContainer, title: String) -> LineEdit:
	var label := Label.new()
	label.text = title
	box.add_child(label)
	var input := LineEdit.new()
	input.text_submitted.connect(func(_text: String) -> void: _apply(true))
	box.add_child(input)
	return input

## Connects a test command while keeping keyboard focus out of subsequent gameplay actions.
func _button(box: VBoxContainer, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	box.add_child(button)

## Initializes from real runtime attributes without overwriting a user's in-progress edit on replay.
func _initialize(_snapshot: MatchStateSnapshot) -> void:
	if not _attack.text.is_empty():
		return
	_refresh_inputs()

## Mirrors an explicit preset's bound values and selected independent random inputs.
func _refresh_inputs() -> void:
	var values := _bootstrap.get_melee_test_attributes()
	_attack.text = str(values[0])
	_defense.text = str(values[1])
	_technique.text = str(values[2])
	_dodge.text = "" if _bootstrap.melee_dodge_sample < 0.0 else str(_bootstrap.melee_dodge_sample)
	_strength.text = "" if _bootstrap.melee_strength_sample < 0.0 else str(_bootstrap.melee_strength_sample)

## Rejects invalid fields before any stored values or current match can change.
func _apply(start_attack: bool) -> void:
	for field in [_attack, _defense, _technique]:
		if not field.text.strip_edges().is_valid_int():
			_status.text = "三项属性必须是1～100整数"
			return
	for field in [_dodge, _strength]:
		if not field.text.strip_edges().is_empty() and not field.text.strip_edges().is_valid_float():
			_status.text = "样本须留空或填写0≤u<1"
			return
	var u5 := -1.0 if _dodge.text.strip_edges().is_empty() else _dodge.text.to_float()
	var u6 := -1.0 if _strength.text.strip_edges().is_empty() else _strength.text.to_float()
	var outcomes := [MatchSimulation.MeleeOutcome.FORMULA, MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN,
		MatchSimulation.MeleeOutcome.ATTACKER_RECOILS, MatchSimulation.MeleeOutcome.BOTH_KNOCKED_DOWN, MatchSimulation.MeleeOutcome.DODGED]
	if not _bootstrap.set_melee_test_inputs(_attack.text.to_int(), _defense.text.to_int(),
		_technique.text.to_int(), u5, u6, outcomes[_override.selected]):
		_status.text = "属性须为1～100整数，样本须留空或0≤u<1"
		return
	_bootstrap.melee_target_has_ball = _owner.button_pressed
	_bootstrap.melee_reverse_direction = _reverse.button_pressed
	for field in [_attack, _defense, _technique, _dodge, _strength]:
		field.release_focus()
	_bootstrap.replay_melee_test(start_attack)
	_status.text = "按L攻击；~重置；M刻度"

## Selects reproducible formula branches; forced development results remain a separate labeled choice.
func _preset(preset: int) -> void:
	_bootstrap.melee_target_has_ball = _owner.button_pressed
	_bootstrap.melee_reverse_direction = _reverse.button_pressed
	_bootstrap.select_melee_preset(preset as GameBootstrap.MeleePreset)
	_override.select(0)
	_refresh_inputs()

## Renders immutable probabilities, sampling reasons, directions and ownership from committed events.
func _present(_snapshot: MatchStateSnapshot, events: Array[MatchEvent], _alpha: float) -> void:
	for event in events:
		if event.event_type == MatchEvent.Type.RESET_COMPLETED:
			_status.text = "已重置；L攻击"
		if event.event_type != MatchEvent.Type.MELEE_CONTEST_RESOLVED:
			continue
		var result := event.melee_contest
		var outcomes := ["闪避", "进攻者胜：目标击飞", "目标胜：进攻者反飞", "平局：双方反向击飞"]
		var reasons := ["F05闪避，未执行F06", "等强必平，不抽F06", "差值达阈值，强者必胜，不抽F06", "阈值内独立抽F06", "开发强制结果，不抽样"]
		_status.text = "A=%d / B=%d / T=%d\nF05闪避率 %.1f%%，u5=%s\n%s\n方向(%.2f, %.2f)，球权 %s → %s" % [
			result.attacker_strength, result.target_strength, result.target_technique,
			result.dodge_probability * 100.0, "未抽样" if result.is_override else str(result.dodge_sample),
			outcomes[result.outcome], result.direction.x, result.direction.y, event.previous_owner_id, event.new_owner_id]
		_status.text += "\n" + reasons[result.strength_reason]
		if result.strength_reason != MeleeContestResult.StrengthReason.DODGED:
			_status.text += "\n强者胜率 %.1f%%，u6=%s" % [result.stronger_win_probability * 100.0,
				str(result.strength_sample) if result.has_strength_sample else "未抽样"]
