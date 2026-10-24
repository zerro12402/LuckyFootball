## Checks twelve actor bindings, normal lifecycle controls, shared presets and production dependency isolation.
extends SceneTree
const Fixture = preload("res://tests/support/formal_match_fixture.gd")
var _failures: PackedStringArray = []

## Defers node assembly without requesting screenshots or rendering validation.
func _init() -> void:
	call_deferred("_run")

## Uses real controls and scene resources while asserting only logical assembly and snapshot contracts.
func _run() -> void:
	var packed := load("res://scenes/match/formal_match.tscn") as PackedScene
	var formal := packed.instantiate() as FormalMatchBootstrap
	root.add_child(formal)
	formal.set_process(false)
	_check(formal.last_errors.is_empty() and formal.get_snapshot() != null, "production formal scene loads complete data")
	if formal.get_snapshot() == null:
		_finish()
		return
	var snapshot := formal.get_snapshot()
	var field := formal.get_node("FieldEnvironment") as FieldEnvironment
	_check(snapshot.phase == MatchState.Phase.READY and field.get_presented_player_ids().size() == 12, "formal READY binds twelve stable actors")
	_check(formal._sources.is_empty() and not _has_keyboard(formal), "production formal scene has no keyboard or fake tactical source")
	var ids := field.get_presented_player_ids()
	var actor_ids: Dictionary[String, int] = {}
	for id in ids:
		actor_ids[id] = field._roster_actors[id].get_instance_id()
	_button(formal, "开始比赛").pressed.emit()
	formal._process(0.05)
	_check(formal.get_snapshot().phase == MatchState.Phase.RUNNING and formal.get_snapshot().elapsed_seconds > 0, "start control enters running")
	_button(formal, "暂停 / 恢复").pressed.emit()
	var before := formal.get_snapshot()
	formal._process(0.2)
	_check(formal.get_snapshot().phase == MatchState.Phase.PAUSED and formal.get_snapshot().elapsed_seconds == before.elapsed_seconds, "pause control freezes time")
	_button(formal, "暂停 / 恢复").pressed.emit()
	var fixture := Fixture.new()
	fixture.launch_boundary(formal._simulation, 0.01)
	formal._process(0.05)
	for step in range(45):
		formal._process(0.1)
		if formal.get_snapshot().round_sequence == 2:
			break
	_check(formal.get_snapshot().round_sequence == 2 and formal.get_snapshot().home_score == 1, "formal scene uses real goal/net/reset rules")
	_check(field.get_presented_player_ids() == ids, "actor mapping survives reset")
	for id in ids:
		_check(field._roster_actors[id].get_instance_id() == actor_ids[id], "actor reused by stable ID after reset")
	_button(formal, "取消比赛").pressed.emit()
	formal._process(0.0)
	_check(formal.get_snapshot().phase == MatchState.Phase.CANCELLED and formal.get_snapshot().result == null, "cancel control publishes no official outcome")
	formal.queue_free()
	await process_frame
	# All developer presets stay in the existing shared demo resource.
	var demo := (load("res://scenes/main/game_bootstrap.tscn") as PackedScene).instantiate() as GameBootstrap
	demo.demo_mode = GameBootstrap.DemoMode.FORMAL_FLOW_TEST
	root.add_child(demo)
	await process_frame
	var controls := demo.get_node("FormalFlowControls") as FormalFlowTestControls
	_check(controls.visible and controls._session != null, "shared flow controls create a production-rule session")
	for preset: int in [1, 2, 3]:
		var button := _button(controls, ["进球与重置预设", "带球出界与重置预设", "临近终场预设"][preset - 1])
		_check(button != null, "flow preset button exists")
		button.pressed.emit()
		controls._session.set_process(false)
		for step in range(80):
			controls._session._process(0.05)
			var state := controls._session.get_snapshot()
			if state.round_sequence == 2 or state.phase == MatchState.Phase.FINISHED:
				break
		var state := controls._session.get_snapshot()
		_check((preset == 3 and state.phase == MatchState.Phase.FINISHED) or (preset != 3 and state.round_sequence == 2), "preset reaches real reset or finish")
		if preset == 1:
			_check(state.home_score == 1, "preset shot really scores")
		if preset == 2:
			_check(state.home_score == 0 and state.away_score == 0, "carried exit does not score")
	demo.queue_free()
	await process_frame
	# The formal resource's complete transitive dependency graph must remain free of test adapters.
	var visited: Dictionary[String, bool] = {}
	_dependencies("res://scenes/match/formal_match.tscn", visited)
	for path in visited:
		_check(not path.contains("scenes/test/") and not path.contains("tests/") and not path.contains("game_bootstrap.gd") and not path.contains("keyboard_player_input_adapter") and not path.contains("test_controls") and not path.contains("preset_action_source"), "formal dependency isolation: " + path)
	_finish()

## Traverses actual script/resource references, not only visible child node names.
func _dependencies(path: String, visited: Dictionary[String, bool]) -> void:
	if visited.has(path):
		return
	visited[path] = true
	for dependency in ResourceLoader.get_dependencies(path):
		var parts := dependency.split("::")
		var file := parts[parts.size() - 1]
		if file.begins_with("res://"):
			_dependencies(file, visited)
	if path.ends_with(".gd"):
		var source := FileAccess.get_file_as_string(path)
		var regex := RegEx.new()
		regex.compile('(?:preload|load)\\(\\s*["\'](res://[^"\']+)')
		for found in regex.search_all(source):
			_dependencies(found.get_string(1), visited)

## Locates normal controls by label, independent of layout or rendering.
func _button(node: Node, title: String) -> Button:
	if node is Button and (node as Button).text == title:
		return node as Button
	for child in node.get_children():
		var found := _button(child, title)
		if found != null:
			return found
	return null

## Checks typed child nodes without relying on a resource's name alone.
func _has_keyboard(node: Node) -> bool:
	if node is KeyboardPlayerInputAdapter:
		return true
	for child in node.get_children():
		if _has_keyboard(child):
			return true
	return false

## Collects logical UI and assembly failures only.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

## Reports all production and shared-mode assembly checks.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print("Formal scene failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)
