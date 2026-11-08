## Covers local prompt history: ordering, de-duplication, cap, reload and damaged files.
extends SceneTree

var _failures: PackedStringArray = []


func _init() -> void:
	var path := "user://test_player_ai_history_%s.json" % OS.get_process_id()
	var history := PlayerAIHistory.new(path)
	_check(history.entries().is_empty(), "A new history starts empty")
	_check(not history.record("", "{}"), "An empty prompt is not recorded")
	var first := '{"version":3,"mode":"overlay","scope":{"role":"back"},' \
		+ '"modifiers":[{"when":[["phase","==","defend"]],"weights":{"tackle":0}}]}'
	_check(history.record("后卫防守不要铲球", first), "A valid entry is recorded")
	history.record("前锋多射门", first.replace("tackle", "shoot"))
	var entries := history.entries()
	_check(entries.size() == 2 and entries[0]["prompt"] == "前锋多射门",
		"Newest entries are listed first")
	history.record("后卫防守不要铲球", first)
	entries = history.entries()
	_check(entries.size() == 2 and entries[0]["prompt"] == "后卫防守不要铲球",
		"Repeating identical content moves it to the front")
	for index in range(25):
		history.record("战术 %d" % index, first)
	_check(history.entries().size() == PlayerAIHistory.MAX_ENTRIES,
		"The history keeps at most twenty entries")
	var reloaded := PlayerAIHistory.new(path)
	_check(reloaded.entries().size() == PlayerAIHistory.MAX_ENTRIES,
		"History survives a new instance")
	reloaded.clear()
	_check(reloaded.entries().is_empty(), "Clearing removes every entry")

	var damaged := "user://test_player_ai_history_damaged_%s.json" % OS.get_process_id()
	var file := FileAccess.open(damaged, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	_check(PlayerAIHistory.new(damaged).entries().is_empty(),
		"An unparsable file yields an empty history")
	var partial := "user://test_player_ai_history_partial_%s.json" % OS.get_process_id()
	file = FileAccess.open(partial, FileAccess.WRITE)
	file.store_string(JSON.stringify([
		{"prompt": 1, "json": first, "created_at": "x"},
		{"prompt": "有效记录", "json": first, "created_at": "2026-01-01 00:00:00"},
	]))
	file.close()
	var partial_history := PlayerAIHistory.new(partial)
	_check(partial_history.entries().size() == 1
		and partial_history.entries()[0]["prompt"] == "有效记录",
		"Malformed entries are skipped without losing valid ones")

	for target in [path, damaged, partial]:
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	for failure in _failures:
		push_error(failure)
	print("AI history failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
