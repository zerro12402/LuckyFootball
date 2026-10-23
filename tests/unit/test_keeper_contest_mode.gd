## Exercises real near/far/chain keeper presets and result labels without rendering assertions.
extends SceneTree

var _failures: PackedStringArray = []

## Waits for the existing shared scene to enter the test tree.
func _init() -> void:
	call_deferred("_run")

## Uses real UI signals for all shot sources; neither travel nor hit counters are injected.
func _run() -> void:
	var bootstrap := (load("res://scenes/main/game_bootstrap.tscn") as PackedScene).instantiate() as GameBootstrap
	bootstrap.demo_mode = GameBootstrap.DemoMode.GOALKEEPER_TEST
	root.add_child(bootstrap)
	bootstrap.set_process(false)
	var controls := bootstrap.get_node("GoalkeeperControls") as GoalkeeperTestControls
	var start := _find_button(controls, "开始 / 固定种子重放")
	for source in range(3):
		controls._source.select(source)
		var near: GoalkeeperSaveResult
		for preset in range(1, 5):
			controls._contest.select(preset)
			start.pressed.emit()
			# Isolate contact/decay cases through internal test sampling, never public controls.
			bootstrap._match_simulation._shot_miss_override = 0
			bootstrap._match_simulation._keeper_sampler = func() -> float: return 0.0
			bootstrap.set_process(false)
			var result := _advance_to_save(bootstrap)
			_check(result != null, "source %d preset %d physically reaches keeper" % [source, preset])
			if result == null:
				continue
			_check(result.did_catch and result.sample == 0.0, "fixed catch sample remains a normal legal F04 draw")
			_check(result.knockdown_count == (preset - 2 if preset >= 3 else 0), "real committed victims match layout")
			_check(result.goalkeeping == bootstrap._data_repository.get_player_by_id(bootstrap.demo_opponent_id).goalkeeping, "real CSV G in result")
			_check(controls._status.text.contains("S0=") and controls._status.text.contains("守住="), "immutable formula facts reach status")
			if preset == 1:
				near = result
			elif preset == 2 and near != null:
				_check(result.distance_m > near.distance_m and result.effective_shooting < near.effective_shooting and result.save_probability >= near.save_probability, "far shot decays more than near shot")
			if source == GameBootstrap.KeeperShotSource.HEADER:
				var saw_header := false
				for fact in bootstrap.get_event_history():
					saw_header = saw_header or fact.event_type == MatchEvent.Type.BALL_HEADED
				_check(saw_header, "header preset really touches the high pass")
			var first := _trace(bootstrap)
			start.pressed.emit()
			# Isolate contact/decay cases through internal test sampling, never public controls.
			bootstrap._match_simulation._shot_miss_override = 0
			bootstrap._match_simulation._keeper_sampler = func() -> float: return 0.0
			bootstrap.set_process(false)
			_advance_to_save(bootstrap)
			_check(first == _trace(bootstrap), "same seed and layout replay exact F04 facts")
	# Force a physical leak: its label is not a goal; only the later true crossing counts.
	controls._source.select(0)
	controls._contest.select(1)
	start.pressed.emit()
	bootstrap._match_simulation._shot_miss_override = 0
	bootstrap._match_simulation._keeper_sampler = func() -> float: return 0.999
	bootstrap.set_process(false)
	var miss := _advance_to_save(bootstrap)
	_check(miss != null and not miss.did_catch, "forced high sample leaks at contact")
	_check(bootstrap._match_simulation.create_snapshot().right_goal_count == 0, "leak itself is not a goal")
	for step in range(80):
		bootstrap._process(bootstrap.fixed_delta_seconds)
	_check(bootstrap._match_simulation.create_snapshot().right_goal_count == 1, "actual crossing scores once")
	bootstrap.free()
	for failure in _failures:
		push_error(failure)
	print("F04 shared contest mode failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Stops at the true contact result, before any remaining ball motion could be confused with it.
func _advance_to_save(bootstrap: GameBootstrap) -> GoalkeeperSaveResult:
	for step in range(240):
		bootstrap._process(bootstrap.fixed_delta_seconds)
		for event in bootstrap.get_event_history():
			if event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED:
				return event.goalkeeper_save
	return null

## Captures immutable numeric inputs and samples rather than reconstructing facts from pixels.
func _trace(bootstrap: GameBootstrap) -> String:
	var trace := ""
	for event in bootstrap.get_event_history():
		if event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED:
			var result := event.goalkeeper_save
			trace += str([result.base_shooting, result.goalkeeping, result.distance_m,
				result.knockdown_count, result.save_probability, result.sample, result.did_catch])
	return trace

## Finds the actual button so the test also verifies production signal wiring.
func _find_button(node: Node, title: String) -> Button:
	if node is Button and (node as Button).text == title:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, title)
		if found != null:
			return found
	return null

## Collects independent assertions before exiting the non-rendering test.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
