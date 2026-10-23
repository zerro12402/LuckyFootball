## Checks F11 preset signals and immutable outcomes in the shared scene without rendering tests.
extends SceneTree

var _failures: PackedStringArray = []

## Defers until the shared scene can be attached to the ordinary test tree.
func _init() -> void:
	call_deferred("_run")

## Uses real controls for all three sources and both explicit accuracy branches.
func _run() -> void:
	var bootstrap := (load("res://scenes/main/game_bootstrap.tscn") as PackedScene).instantiate() as GameBootstrap
	bootstrap.demo_mode = GameBootstrap.DemoMode.GOALKEEPER_TEST
	root.add_child(bootstrap)
	bootstrap.set_process(false)
	var controls := bootstrap.get_node("GoalkeeperControls") as GoalkeeperTestControls
	var start := _find_button(controls, "开始 / 固定种子重放")
	_check(start != null, "shared preset button exists")
	_check(bootstrap.shot_miss_override == -1 and bootstrap.keeper_sample < 0, "UI uses attribute sampling")
	for source in range(3):
		for missed in [false, true]:
			controls._source.select(source)
			start.pressed.emit()
			# Internal branch fixtures remain independent of the public attribute inputs.
			bootstrap._match_simulation._shot_miss_override = 1 if missed else 0
			bootstrap._match_simulation._keeper_sampler = func() -> float: return 0.0
			bootstrap.set_process(false)
			var first := _trace(bootstrap)
			_check(not first.is_empty(), "source %d legally releases" % source)
			var aim := _released_aim(bootstrap)
			if aim != null:
				_check(aim.is_miss == missed, "internal branch fixture applies to every source")
				_check(aim.miss_sample == -1.0, "forced branch does not consume accuracy sample")
				_check(not missed or (aim.post_side in [-1, 1] and is_equal_approx(aim.miss_margin_m, 1.0)), "random post with fixed one-meter offset")
				_check(controls._status.text.contains("准确性：射偏" if missed else "准确性：未射偏"), "accuracy shown separately")
				_check(controls._status.text.contains("扑救："), "save has separate status")
			start.pressed.emit()
			# Internal branch fixtures remain independent of the public attribute inputs.
			bootstrap._match_simulation._shot_miss_override = 1 if missed else 0
			bootstrap._match_simulation._keeper_sampler = func() -> float: return 0.0
			bootstrap.set_process(false)
			_check(first == _trace(bootstrap), "same preset seed replays target and contact facts")
	_check(bootstrap.shot_miss_side == 0 and bootstrap.keeper_lane == -1,
		"preset leaves post side and on-target channel random")
	bootstrap.free()
	for failure in _failures:
		push_error(failure)
	print("F11 shared controls failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Reads actual release and save facts; no pixel, animation or rendering assertions are used.
func _trace(bootstrap: GameBootstrap) -> String:
	for step in range(150):
		bootstrap._process(bootstrap.fixed_delta_seconds)
	var trace := ""
	for event in bootstrap.get_event_history():
		if event.shot_aim != null:
			trace += str([event.shot_aim.is_miss, event.shot_aim.point_m, event.shot_aim.miss_probability])
		if event.goalkeeper_save != null:
			trace += str([event.goalkeeper_save.did_catch, event.goalkeeper_save.sample])
	return trace

## Retrieves the first actual foot or headed shot aim from immutable simulation events.
func _released_aim(bootstrap: GameBootstrap) -> ShotAim:
	for event in bootstrap.get_event_history():
		if event.shot_aim != null:
			return event.shot_aim
	return null

## Locates the actual button so tests exercise its signal wiring instead of a private handler.
func _find_button(node: Node, title: String) -> Button:
	if node is Button and (node as Button).text == title:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, title)
		if found != null:
			return found
	return null

## Collects independent rule/control failures for a concise final result.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
