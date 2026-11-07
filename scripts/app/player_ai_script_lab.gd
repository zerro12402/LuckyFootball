## Owns local script editing, validated binding and same-seed trials without writing match state.
class_name PlayerAIScriptLab
extends CanvasLayer

signal trial_requested(player_id: String, strategy: PlayerAIDecisionStrategy, seed_value: int)

const MANUAL_PATH := "res://docs/player-ai-script-v1.md"
const STARTER := """{
  "version": 1,
  "rules": [
    {"when": [["self.pressured", "==", true], ["has.pass", "==", true]],
     "then": {"weights": {"pass": 2}}}
  ],
  "default": {}
}"""

@onready var _editor: PanelContainer = %Editor
@onready var _source: TextEdit = %ScriptSource
@onready var _forward: OptionButton = %ForwardChoice
@onready var _seed: LineEdit = %SeedInput
@onready var _diagnostic: Label = %Diagnostic
@onready var _return_button: Button = %ReturnButton
@onready var _run: Button = %RunButton
@onready var _baseline: Button = %BaselineButton

var _accepted_source := ""
var _program: PlayerAIScript
var _last_seed: int = -1


## Connects normal controls to the same validation path used by nonvisual tests.
func _ready() -> void:
	_source.text = STARTER
	%ValidateButton.pressed.connect(_validate_editor)
	_run.pressed.connect(_run_script)
	_baseline.pressed.connect(_run_baseline)
	%ManualButton.pressed.connect(_copy_manual)
	%CloseButton.pressed.connect(close)
	_return_button.pressed.connect(open)


## Lists only blue-team forwards from the same roster and definitions used by formal play.
func open() -> void:
	show()
	_editor.show()
	_return_button.hide()
	if _forward.item_count > 0:
		return
	var data := DataRepository.new()
	if not data.load_all():
		_diagnostic.text = str(data.last_errors)
		return
	var teams := data.load_formal_teams()
	if teams == null:
		_diagnostic.text = str(data.last_errors)
		return
	for team in teams.teams:
		if team.team_id != "home":
			continue
		for entry in teams.get_roster(team.team_id):
			if not entry.default_position.begins_with("forward"):
				continue
			var player := data.get_player_by_id(entry.player_id)
			_forward.add_item("%s · %s" % [team.display_name, player.display_name])
			_forward.set_item_metadata(_forward.item_count - 1, entry.player_id)
	_run.disabled = _forward.item_count == 0


## Hides the lab without affecting the currently running match.
func close() -> void:
	hide()


## Commits a validated document only on success; failed submissions preserve the cached program.
func submit(source: String) -> bool:
	if _program != null and source == _accepted_source:
		_diagnostic.text = "校验通过 · 接口 v1"
		return true
	var result := PlayerAIScript.compile(source)
	if result.has("error"):
		_diagnostic.text = result["error"]
		return false
	_accepted_source = source
	_program = result["script"]
	_diagnostic.text = "校验通过 · 接口 v1"
	return true


## Keeps the latest fallback reason visible during live observation.
func report_fallback(reason: String) -> void:
	if not reason.is_empty():
		%LiveStatus.text = "脚本回退：" + reason


## Validates text without binding or starting a new match.
func _validate_editor() -> void:
	submit(_source.text)


## Freezes the compiled program and seed before requesting a fresh formal scene.
func _run_script() -> void:
	var value := _seed.text.strip_edges()
	if not value.is_valid_int() or value.to_int() < 0 or value.to_int() > 2147483647:
		_diagnostic.text = "种子须为 0 到 2147483647 的整数"
		return
	if _forward.selected < 0 or not submit(_source.text):
		return
	_last_seed = value.to_int()
	_baseline.disabled = false
	var player_id: String = _forward.get_item_metadata(_forward.selected)
	_begin_trial(player_id, _program, _last_seed)


## Reuses the most recent scripted trial's seed and the same formal match setup.
func _run_baseline() -> void:
	if _last_seed >= 0:
		_begin_trial("", null, _last_seed)


## Keeps diagnostics accessible while removing the editor from the playing area.
func _begin_trial(player_id: String, strategy: PlayerAIDecisionStrategy, seed_value: int) -> void:
	_editor.hide()
	_return_button.show()
	%LiveStatus.text = "种子 %d · %s" % [seed_value, "默认策略" if strategy == null else "脚本试跑"]
	trial_requested.emit(player_id, strategy, seed_value)


## Shares the versioned manual as plain text without opening a browser.
func _copy_manual() -> void:
	var manual := FileAccess.get_file_as_string(MANUAL_PATH)
	if manual.is_empty():
		_diagnostic.text = "无法读取脚本手册"
		return
	DisplayServer.clipboard_set(manual)
	_diagnostic.text = "接口 v1 手册已复制"