## Reproduces oblique twelve-meter shots against the widened keeper response, without rendering.
extends SceneTree

var _failures: PackedStringArray = []

## Defers until the existing shared match can receive test commands.
func _init() -> void:
	call_deferred("_run")

## Checks both diagonal approaches and all three channels, with independent catch/miss samples.
func _run() -> void:
	for side in [-1.0, 1.0]:
		for lane in range(3):
			for sample in [0.0, 0.999]:
				var bootstrap := (load("res://scenes/main/game_bootstrap.tscn") as PackedScene).instantiate() as GameBootstrap
				bootstrap.demo_mode = GameBootstrap.DemoMode.GOALKEEPER_TEST
				root.add_child(bootstrap)
				bootstrap.set_process(false)
				_check(is_equal_approx(bootstrap.match_config.keeper_contact_radius_m, 2.0), "production keeper radius is two meters")
				bootstrap.set_keeper_test_attributes(80, 70)
				bootstrap.select_keeper_preset(false)
				bootstrap.set_process(false)
				var simulation := bootstrap._match_simulation
				# Arrange only the starting position; subsequent release and response use real commands.
				var shooter := simulation._player_runtime_system.get_player(bootstrap.demo_player_id)
				shooter.state._set_position(Vector2(25.0 - 12.0 / sqrt(2.0), side * 12.0 / sqrt(2.0)))
				bootstrap._process(bootstrap.fixed_delta_seconds)
				simulation._shot_miss_override = 0
				simulation._shot_aim_sampler = func() -> int: return lane
				simulation._keeper_sampler = func() -> float: return sample
				bootstrap.queue_action(MatchAction.new(shooter.player_id, MatchAction.Type.SHOOT))
				var started := false
				var result: GoalkeeperSaveResult
				for step in range(180):
					bootstrap._process(bootstrap.fixed_delta_seconds)
					for event in bootstrap.get_event_history():
						started = started or event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_STARTED
						if event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED:
							result = event.goalkeeper_save
					if result != null:
						break
				_check(started and result != null, "45-degree 12m lane %d side %.0f triggers actual response" % [lane, side])
				if result != null:
					_check(result.did_catch == (sample < result.save_probability), "wide contact still uses attributes, never guaranteed catch")
					_check(result.base_shooting == 80 and result.goalkeeping == 70, "entered S/G still reach resolver")
				bootstrap.free()
	for failure in _failures:
		push_error(failure)
	print("Wide keeper contact failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Aggregates deterministic contact and result failures before exit.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
