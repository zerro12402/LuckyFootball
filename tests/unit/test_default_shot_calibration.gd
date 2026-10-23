## Calibrates the full default-position shot, including F11 misses and real F04/boundary settlement.
extends SceneTree

var _failures: PackedStringArray = []

## Checks exact probabilities, then measures deterministic multi-seed matches as a diagnostic.
func _init() -> void:
	var repository := DataRepository.new()
	_check(repository.load_all(), "production data loads")
	var config := repository.get_match_config_by_id("demo_match")
	var field := repository.get_field_by_id("demo_field")
	var on_target := 1.0 - ShotAccuracyResolver.calculate_miss_probability(84, config)
	var effective := GoalkeeperSaveResolver.effective_shooting(84, 6.45, 0, config)
	var miss_save := 1.0 - GoalkeeperSaveResolver.save_probability(effective, 94, config)
	var expected := on_target * miss_save
	_check(is_equal_approx(config.keeper_contest_probability_scale, 5.0), "F04 tuned scale is five")
	_check(expected > 0.09 and expected < 0.11, "full default chance is about ten percent")
	_check(is_equal_approx(GoalkeeperSaveResolver.save_probability(84, 84, config), 0.5), "equal effective attributes remain 50 percent")
	var bootstrap := GameBootstrap.new()
	bootstrap.demo_mode = GameBootstrap.DemoMode.GOALKEEPER_TEST
	bootstrap._match_config = config
	bootstrap._demo_opponent_id = "keeper"
	var goals := 0
	var trials := 2000
	for seed_value in range(trials):
		var simulation := MatchSimulation.new(seed_value, config, field,
			MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN, Callable(), Callable(),
			Callable(), Callable(), Callable(), Callable(), Callable(), func() -> float: return 1.0)
		simulation.register_player("shooter", Vector2(15, 0), 5, "attack", 84)
		simulation.register_player("keeper", Vector2(23, 0), 5, "defend", 45, 86, 61, true, 0, 50, 94)
		simulation.register_team_attacking_goal("attack", Vector2(25, 0))
		simulation.register_team_attacking_goal("defend", Vector2(-25, 0))
		simulation.register_ball(Vector2(15.55, 0))
		simulation.start_match()
		simulation.advance_fixed_step(0.025, [])
		bootstrap._match_simulation = simulation
		bootstrap._keeper_reaction_requested = false
		var finished := false
		for step in range(100):
			var actions: Array[MatchAction] = []
			if step == 0:
				actions.append(MatchAction.new("shooter", MatchAction.Type.SHOOT))
			bootstrap._queue_keeper_test_actions(actions, 0.025)
			for event in simulation.advance_fixed_step(0.025, actions):
				if event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED:
					var save := event.goalkeeper_save
					if save.lane == ShotAim.Lane.CENTER:
						_check(is_equal_approx(save.distance_m, 6.45), "center contest distance excludes keeper reach")
						_check(save.flight_distance_m < save.distance_m, "early reaction leaves actual travel intact")
					_check(save.did_catch == (save.sample < save.save_probability), "actual sample uses probability")
					if save.did_catch:
						finished = true
				if event.event_type == MatchEvent.Type.GOAL_SCORED:
					goals += 1
					finished = true
				if event.event_type == MatchEvent.Type.BALL_OUT_OF_BOUNDS:
					finished = true
			if finished:
				break
		_check(finished, "default shot reaches physical catch, goal or exit")
	bootstrap.free()
	# Frequency is diagnostic; exact probability assertions above are the non-statistical regression.
	print("Default 84 vs 94: theoretical %.3f%%; seeded goals %d/%d = %.3f%%" % [expected * 100, goals, trials, float(goals) / trials * 100])
	for failure in _failures:
		push_error(failure)
	print("Shot calibration failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Collects formula and physical-settlement failures without flaky frequency assertions.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
