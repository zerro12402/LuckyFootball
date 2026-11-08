## Keeps a bounded local history of player prompts and their compiled scripts.
class_name PlayerAIHistory
extends RefCounted

const MAX_ENTRIES := 20
const DEFAULT_PATH := "user://player_ai_history.json"

var _path: String
var _entries: Array[Dictionary] = []
var _loaded := false


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## Returns a detached newest-first copy, loading the file once.
func entries() -> Array[Dictionary]:
	_ensure_loaded()
	return _entries.duplicate(true)


## Saves a successful prompt and its script; identical content moves to the front.
func record(prompt: String, json: String) -> bool:
	_ensure_loaded()
	var trimmed := prompt.strip_edges()
	if trimmed.is_empty() or json.strip_edges().is_empty():
		return false
	for index in range(_entries.size() - 1, -1, -1):
		var entry: Dictionary = _entries[index]
		if entry["prompt"] == trimmed and entry["json"] == json:
			_entries.remove_at(index)
	_entries.push_front({
		"prompt": trimmed,
		"json": json,
		"created_at": Time.get_datetime_string_from_system(false, true),
	})
	if _entries.size() > MAX_ENTRIES:
		_entries.resize(MAX_ENTRIES)
	return _save()


func clear() -> bool:
	_entries.clear()
	_loaded = true
	return _save()


func storage_path() -> String:
	return _path


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_path):
		return
	var text := FileAccess.get_file_as_string(_path)
	if text.strip_edges().is_empty():
		return
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var parsed: Variant = json.data
	if not parsed is Array:
		return
	for item in parsed:
		if _valid(item) and _entries.size() < MAX_ENTRIES:
			_entries.append(item.duplicate(true))


## Requires the three public fields with the expected types.
static func _valid(item: Variant) -> bool:
	if not item is Dictionary:
		return false
	return item.get("prompt") is String and not item["prompt"].strip_edges().is_empty() \
		and item.get("json") is String and not item["json"].strip_edges().is_empty() \
		and item.get("created_at") is String


func _save() -> bool:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_entries))
	file.close()
	return true
