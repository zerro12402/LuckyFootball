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

var _accepted_source := ""
var _program: PlayerAIScript


## Connects normal controls to the same validation path used by nonvisual tests.
func _ready() -> void:
	_source.text = STARTER
	%ValidateButton.pressed.connect(_validate_editor)
	_run.pressed.connect(_run_script)
	%TeamManualButton.pressed.connect(_copy_team_manual)
	%SaveTeamManualButton.pressed.connect(_open_team_manual_save_dialog)
	%TeamManualSaveDialog.file_selected.connect(_save_team_manual)


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
	var binding_id := "home" if _program.interface_version() == 2 else _first_blue_forward()
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