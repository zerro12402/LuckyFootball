## Owns local script editing, validated binding and manual export without writing match state.
class_name PlayerAIScriptLab
extends CanvasLayer

signal trial_requested(binding_id: String, strategy: PlayerAIDecisionStrategy)

const TEAM_MANUAL_PATH := "res://docs/player-ai-script-v2.md"
const STARTER := """{
  "version": 2,
  "rules": [
    {"when": [["self.pressured", "==", true], ["has.pass", "==", true]],
     "then": {"weights": {"pass": 2}}}
  ],
  "default": {}
}"""

@onready var _editor: PanelContainer = %Editor
@onready var _source: TextEdit = %ScriptSource
@onready var _diagnostic: Label = %Diagnostic
@onready var _run: Button = %RunButton
@onready var _summary: Label = %OverlaySummary
@onready var _tactic: LineEdit = %TacticPrompt
@onready var _generate: Button = %GenerateButton
@onready var _cancel: Button = %CancelButton
@onready var _api_key_input: LineEdit = %ApiKeyInput

var _accepted_source := ""
var _program: PlayerAIScript
var _settings := PlayerAISettings.new()
var _transport: DeepSeekTransport
var _generation: PlayerAIScriptGenerator
var _busy := false


## Connects normal controls to the same validation path used by nonvisual tests.
func _ready() -> void:
	_source.text = STARTER
	%ValidateButton.pressed.connect(_validate_editor)
	_run.pressed.connect(_run_script)
	%TeamManualButton.pressed.connect(_copy_team_manual)
	%SaveTeamManualButton.pressed.connect(_open_team_manual_save_dialog)
	%TeamManualSaveDialog.file_selected.connect(_save_team_manual)
	_generate.pressed.connect(_generate_from_text)
	_cancel.pressed.connect(_cancel_generation)
	%SaveKeyButton.pressed.connect(_save_api_key)
	%ClearKeyButton.pressed.connect(_clear_api_key)
	_transport = DeepSeekTransport.new()
	add_child(_transport)
	_refresh_key_hint()


## Toggles only the editor; the match continues underneath it.
func toggle_editor() -> void:
	if is_editor_open():
		close()
	else:
		show()
		_editor.show()


func is_editor_open() -> bool:
	return visible and _editor.visible



## Lets an active file dialog handle Escape before the underlying editor.
func close_editor_from_keyboard() -> bool:
	if not is_editor_open() or %TeamManualSaveDialog.visible:
		return false
	close()
	return true


## Hides the lab without affecting the currently running match.
func close() -> void:
	if _busy:
		_cancel_generation()
	hide()


## Commits a validated document only on success; failed submissions preserve the cached program.
func submit(source: String) -> bool:
	if _program != null and source == _accepted_source:
		_diagnostic.text = "校验通过 · 接口 v%d" % _program.interface_version()
		return true
	var result := PlayerAIScript.compile(source)
	if result.has("error"):
		_diagnostic.text = result["error"]
		return false
	_accepted_source = source
	_program = result["script"]
	_diagnostic.text = "校验通过 · 接口 v%d" % _program.interface_version()
	return true


## Keeps the latest fallback reason visible during live observation.
func report_fallback(reason: String) -> void:
	if not reason.is_empty():
		%LiveStatus.text = "脚本回退：" + reason


## Validates text without binding or starting a new match.
func _validate_editor() -> void:
	submit(_source.text)


## Binds v2 to the blue team and keeps v1 usable with the first blue forward.
func _run_script() -> void:
	if not submit(_source.text):
		return
	var binding_id := "home" if _program.interface_version() >= 2 else _first_blue_forward()
	if binding_id.is_empty():
		return
	_editor.hide()
	%LiveStatus.text = ""
	trial_requested.emit(binding_id, _program)


## Resolves the legacy forward from the roster instead of hard-coding a player ID.
func _first_blue_forward() -> String:
	var data := DataRepository.new()
	if data.load_all():
		var teams := data.load_formal_teams()
		if teams != null:
			for entry in teams.get_roster("home"):
				if entry.default_position.begins_with("forward"):
					return entry.player_id
	_diagnostic.text = "无法读取蓝队前锋阵容"
	return ""



## Shares the versioned manual as plain text without opening a browser.
func _copy_team_manual() -> void:
	var manual := FileAccess.get_file_as_string(TEAM_MANUAL_PATH)
	if manual.is_empty():
		_diagnostic.text = "无法读取脚本手册"
		return
	DisplayServer.clipboard_set(manual)
	_diagnostic.text = "v2 手册已复制"


## Prompts the player for a destination outside the read-only packaged project.
func _open_team_manual_save_dialog() -> void:
	var dialog: FileDialog = %TeamManualSaveDialog
	dialog.current_file = TEAM_MANUAL_PATH.get_file()
	dialog.popup_centered()


## Writes the bundled Markdown bytes directly so encoding and contents match the public manual.
func _save_team_manual(path: String) -> void:
	var contents := FileAccess.get_file_as_bytes(TEAM_MANUAL_PATH)
	if contents.is_empty():
		_diagnostic.text = "无法读取 v2 手册"
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_diagnostic.text = "无法保存 v2 手册：%s" % error_string(FileAccess.get_open_error())
		return
	var saved := file.store_buffer(contents)
	file.close()
	_diagnostic.text = "v2 手册已保存：%s" % path if saved else "写入 v2 手册失败"


## Generates a patch from the prompt and binds only after the compiler accepts it.
func _generate_from_text() -> void:
	if _busy:
		return
	var description := _tactic_description()
	if description.is_empty():
		return
	var key := _settings.api_key()
	if key.is_empty():
		_diagnostic.text = "请先填写并保存 DeepSeek Key"
		return
	var manual := FileAccess.get_file_as_string(TEAM_MANUAL_PATH)
	if manual.is_empty():
		_diagnostic.text = "无法读取脚本手册"
		return
	_summary.text = ""
	_set_busy(true)
	_diagnostic.text = "生成中…"
	_generation = PlayerAIScriptGenerator.new(PlayerAIPromptBuilder.new(manual))
	var step := _generation.start(description)
	await _request_generation(step["messages"], key)


## Sends one request, applies bounded repairs and finishes exactly once.
func _request_generation(messages: Array, key: String) -> void:
	var current: Array = messages
	while _busy:
		var response: Dictionary = await _transport.post(current, key)
		var result := _generation.accept_transport(response)
		if result.get("retry", false):
			current = result["messages"]
			continue
		_finish_generation(result)
		return


## Applies a successful script and never replaces the program on failure.
func _finish_generation(result: Dictionary) -> void:
	_set_busy(false)
	if not result.get("ok", false):
		if result.get("error_kind") == "CANCELLED":
			_diagnostic.text = "已取消生成"
		else:
			_diagnostic.text = "生成失败（%s）：%s" % [result.get("error_kind", "?"), result.get("error", "")]
		return
	var source: String = result["json"]
	_source.text = source
	if not submit(source):
		return
	_summary.text = PlayerAIScriptGenerator.summarize(source)
	_diagnostic.text = "生成成功 · 尝试 %d 次" % int(result.get("attempts", 1))


## Stops the in-flight request and leaves the current binding untouched.
func _cancel_generation() -> void:
	if not _busy:
		return
	_set_busy(false)
	if _transport != null:
		_transport.cancel()
	if _generation != null:
		_generation.cancel()
	_diagnostic.text = "已取消生成"


func _set_busy(value: bool) -> void:
	_busy = value
	_generate.disabled = value
	%SaveKeyButton.disabled = value
	_cancel.disabled = not value


## Stores the key locally and only echoes a masked confirmation.
func _save_api_key() -> void:
	var typed := _api_key_input.text
	if typed.strip_edges().is_empty():
		_diagnostic.text = "请先输入 Key"
		return
	if _settings.save_key(typed):
		_api_key_input.text = ""
		_refresh_key_hint()
		_diagnostic.text = "Key 已保存到本机"
	else:
		_diagnostic.text = "Key 保存失败"


func _clear_api_key() -> void:
	if _settings.clear_key():
		_api_key_input.text = ""
		_refresh_key_hint()
		_diagnostic.text = "Key 已清除"


## Shows whether a key exists without revealing it.
func _refresh_key_hint() -> void:
	_api_key_input.placeholder_text = "DeepSeek Key（已保存：%s）" % _settings.masked_key() \
		if _settings.has_key() else "DeepSeek Key（仅保存在本机）"


## Reads only the trimmed tactic text so an empty prompt cannot send a request.
func _tactic_description() -> String:
	var description := _tactic.text.strip_edges()
	if description.is_empty():
		_diagnostic.text = "请先描述战术"
	return description