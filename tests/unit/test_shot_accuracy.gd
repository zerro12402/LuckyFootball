## Verifies F11 formula, branch sampling, release timing and real contacts without rendering.
extends SceneTree

var _failures: PackedStringArray = []
var _config: MatchConfigDefinition
var _field: FieldDefinition
var _draws: Array[int] = [0, 0, 0, 0]
var _sample: float = 0.0
var _side: int = -1
var _margin: float = 0.2

## Runs pure calculations and production simulations against explicit boundary samples.
func _init() -> void:
	var repository := DataRepository.new()
	_check(repository.load_all(), "production data loads")
	_config = repository.get_match_config_by_id("demo_match")
	_field = repository.get_field_by_id("demo_field")
	_test_formula_and_config()
	_test_targets()
	_test_release_sampling()
	_test_header_and_clearance()
	_test_real_contacts_and_boundary()
	_test_replay()
	for failure in _failures:
		push_error(failure)
	print("F11 accuracy failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Records only the independent accuracy draw, without sharing it with target selection.
func _draw_miss() -> float:
	_draws[0] += 1
	return _sample

## Fixes the post side independently of the accuracy and margin samples.
func _draw_side() -> int:
	_draws[1] += 1
	return _side

## Fixes physical outside-post clearance, not an arbitrary normalized coordinate.
func _draw_margin() -> float:
	_draws[2] += 1
	return _margin

## Counts the existing channel draw, which must be skipped entirely on a miss.
func _draw_lane() -> int:
	_draws[3] += 1
	return ShotAim.Lane.CENTER

## Checks every attribute and invalid endpoint/range configuration without changing production data.
func _test_formula_and_config() -> void:
	var reference := ShotAccuracyResolver.calculate_miss_probability(80, _config)
	for stamina in [1, 100]:
		for goalkeeping in [1, 100]:
			var definition := PlayerDefinition.new("formula", "Formula", "forward", 80, 80,
				50, 50, stamina, 50, goalkeeping, PackedStringArray(), "soccer_player")
			_check(is_equal_approx(ShotAccuracyResolver.calculate_miss_probability(definition.shooting, _config), reference),
				"stamina and keeper values do not enter F11")
	var previous := 1.0
	for shooting in range(1, 101):
		var probability := ShotAccuracyResolver.calculate_miss_probability(shooting, _config)
		_check(probability <= previous, "probability monotonic at %d" % shooting)
		previous = probability
	_check(is_equal_approx(ShotAccuracyResolver.calculate_miss_probability(1, _config), 0.45), "S1 =45%")
	_check(is_equal_approx(previous, 0.05), "S100 =5%")
	var text := FileAccess.get_file_as_string("res://resources/data/match_configs.csv")
	for pair in [["shot_miss_probability_at_1,0.45", "shot_miss_probability_at_1,1.1"],
		["shot_miss_probability_at_100,0.05", "shot_miss_probability_at_100,-0.1"],
		["shot_miss_probability_at_100,0.05", "shot_miss_probability_at_100,0.8"],
		["shot_miss_margin_min_m,0.2", "shot_miss_margin_min_m,0"],
		["shot_miss_margin_max_m,1.0", "shot_miss_margin_max_m,0.1"],
		["shot_miss_probability_at_1,0.45", "shot_miss_probability_at_1,NaN"],
		["shot_miss_margin_max_m,1.0", "shot_miss_margin_max_m,inf"]]:
		var path := "user://f11_invalid.csv"
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text.replace(pair[0], pair[1]))
		file.close()
		_check(not MatchConfigDataRepository.new().load_from_csv(path).is_success, "invalid F11 config rejected: " + pair[1])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://f11_invalid.csv"))

## Tests both attacking goals, both posts and the exact margin endpoints including ball radius.
func _test_targets() -> void:
	for goal_x in [-25.0, 25.0]:
		for side in [-1, 1]:
			for margin in [0.2, 1.0]:
				for radius in [0.1, 0.55]:
					# The fixture varies one physical input; the loaded static definition is never changed.
					var config := _radius_config(radius)
					var aim := ShotAccuracyResolver.create_aim(80, config, Vector2(goal_x, 2),
						4.0, true, 0.0, ShotAim.Lane.CENTER, side, margin)
					_check(aim.is_miss and aim.post_side == side, "immutable miss facts")
					_check(aim.point_m.is_equal_approx(Vector2(goal_x, 2 + side * (2 + radius + margin))), "whole ball outside correct post")
					_check(is_equal_approx(aim.miss_margin_m, margin), "margin endpoint retained")

## Builds a validated alternate-radius fixture through the same CSV parser as production.
func _radius_config(radius: float) -> MatchConfigDefinition:
	var text := FileAccess.get_file_as_string("res://resources/data/match_configs.csv")
	var file := FileAccess.open("user://f11_radius.csv", FileAccess.WRITE)
	file.store_string(text.replace("ball_radius_m,0.55", "ball_radius_m," + str(radius)))
	file.close()
	var result := MatchConfigDataRepository.new().load_from_csv("user://f11_radius.csv")
	_check(result.is_success, "radius fixture parses")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://f11_radius.csv"))
	return result.configs[0]

## Creates a production-owned carrier with separately counted samples for every target purpose.
func _match(sample: float, field: bool = false, shooting: int = 80, origin: Vector2 = Vector2(15, 0)) -> MatchSimulation:
	_sample = sample
	_draws = [0, 0, 0, 0]
	var simulation := MatchSimulation.new(91, _config, _field if field else null,
		MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN, Callable(), Callable(),
		_draw_lane, func() -> float: return 0.0, Callable(),
		_draw_miss, _draw_side, _draw_margin)
	simulation.register_player("shooter", origin, 5.0, "attack", shooting)
	simulation.register_team_attacking_goal("attack", Vector2(25, 0))
	simulation.register_ball(origin + Vector2(0.55, 0))
	simulation.start_match()
	simulation.advance_fixed_step(0.01, [])
	return simulation

## Waits for the actual release rather than sampling during command admission or windup.
func _release(simulation: MatchSimulation, airborne: bool = false) -> MatchEvent:
	if airborne:
		simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.JUMP)])
		for step in range(20):
			simulation.advance_fixed_step(0.01, [])
	simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT)])
	for step in range(100):
		for event in simulation.advance_fixed_step(0.01, []):
			if event.event_type == MatchEvent.Type.BALL_SHOT:
				return event
	_check(false, "shot must legally release")
	return null

## Covers thresholds, fixed-channel independence, cancellation and snapshot read deduplication.
func _test_release_sampling() -> void:
	var threshold := ShotAccuracyResolver.calculate_miss_probability(80, _config)
	for airborne in [false, true]:
		for sample in [0.0, threshold, 0.99]:
			var simulation := _match(sample)
			var event := _release(simulation, airborne)
			if event == null:
				continue
			var missed: bool = sample < threshold
			_check(event.shot_aim.is_miss == missed, "u equals threshold is on target")
			_check(_draws == ([1, 1, 1, 0] if missed else [1, 0, 0, 1]), "3/2 independent branch draws")
			_check(event.shot_aim.shooting == 80, "locks base shooting")
			var aim := event.shot_aim
			# A deliberate fixture mutation after release must not alter the already locked facts.
			simulation._player_runtime_system.get_player("shooter")._shooting_attribute = 1
			for step in range(5):
				simulation.create_snapshot()
				simulation.advance_fixed_step(0.01, [])
			_check(simulation._ball_runtime_system.current_shot_aim == aim, "flight never reselects target")
			_check(_draws[0] == 1, "no snapshot or flight draws")
	var simulation := _match(0.0)
	simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT)])
	_check(_draws[0] == 0, "windup never samples")
	simulation.advance_fixed_step(0.01, [MatchAction.new("", MatchAction.Type.RESET_ROUND)])
	_check(_draws[0] == 0, "cancelled release never samples")
	# No owner after reset, so an immediate illegal shot must not draw either.
	simulation.advance_fixed_step(0.01, [MatchAction.new("missing", MatchAction.Type.SHOOT)])
	_check(_draws[0] == 0, "illegal command never samples")
	simulation = _match(0.0)
	simulation._shot_miss_override = 0
	_release(simulation)
	_check(_draws == [0, 0, 0, 1], "explicit accurate override skips only its branch draw")

## Uses real high passes so header releases and clearances cannot bypass the shared F11 path.
func _test_header_and_clearance() -> void:
	for clear in [false, true]:
		for missed in [false, true]:
			_sample = 0.0 if missed else 0.99
			_draws = [0, 0, 0, 0]
			var simulation := MatchSimulation.new(47, _config, null,
				MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN, Callable(), Callable(),
				_draw_lane, Callable(), Callable(), _draw_miss, _draw_side, _draw_margin)
			simulation.register_team_attacking_goal("blue", Vector2(25, 0))
			simulation.register_team_attacking_goal("red", Vector2(25, 0))
			simulation.register_player("passer", Vector2.ZERO, 5.0, "blue", 50)
			simulation.register_player("receiver", Vector2(10, 0), 5.0, "blue", 50)
			simulation.register_player("header", Vector2(3.8, 0), 5.0, "red", 80)
			simulation.register_ball(Vector2(0.55, 0))
			simulation.start_match()
			simulation.advance_fixed_step(0.05, [])
			simulation.advance_fixed_step(0.05, [MatchAction.new("passer", MatchAction.Type.PASS, Vector2.ZERO, "receiver")])
			for step in range(15):
				if simulation.create_snapshot().ball.flight_kind == BallMatchState.FlightKind.PASS:
					break
				simulation.advance_fixed_step(0.05, [])
			_check(_draws == [0, 0, 0, 0], "PASS excludes F11")
			simulation.advance_fixed_step(0.01, [MatchAction.new("header",
				MatchAction.Type.HEADER_CLEAR if clear else MatchAction.Type.HEADER_SHOT, Vector2.UP)])
			for step in range(100):
				simulation.advance_fixed_step(0.01, [])
				if simulation.create_snapshot().ball.flight_kind != BallMatchState.FlightKind.PASS:
					break
			var aim := simulation._ball_runtime_system.current_shot_aim
			_check(_draws == ([0, 0, 0, 0] if clear else ([1, 1, 1, 0] if missed else [1, 0, 0, 1])), "header shot/clear branch draws")
			_check(clear or (aim != null and aim.is_miss == missed), "header locks shared F11 result")

## A miss label does not settle early or bypass a keeper/body contact along the real path.
func _test_real_contacts_and_boundary() -> void:
	var simulation := _match(0.0, true)
	_release(simulation)
	_check(simulation.create_snapshot().right_goal_count == 0, "selection is not a goal or out")
	var out_count := 0
	for step in range(180):
		for event in simulation.advance_fixed_step(0.01, []):
			if event.event_type == MatchEvent.Type.BALL_OUT_OF_BOUNDS:
				out_count += 1
	_check(out_count == 1, "miss exits only on actual whole-ball crossing")
	_check(simulation.create_snapshot().right_goal_count == 0, "unobstructed outside-post shot does not score")
	var weak := _match(0.0, true, 1, Vector2.ZERO)
	_release(weak)
	var weak_outs := 0
	for step in range(500):
		for fact in weak.advance_fixed_step(0.01, []):
			if fact.event_type == MatchEvent.Type.BALL_OUT_OF_BOUNDS:
				weak_outs += 1
	_check(weak_outs == 0 and weak.create_snapshot().ball.velocity_mps.is_zero_approx(),
		"weak miss may stop in field without an out event")
	for keeper in [false, true]:
		simulation = _match(0.0, true)
		# This test installs an explicit early intercepting player before commands are released.
		var id := "keeper" if keeper else "body"
		simulation._player_runtime_system.register_player(id, Vector2(20, -1.5), 5.0,
			"defend", 60, 40, 50, keeper)
		var event := _release(simulation)
		if event == null:
			continue
		if keeper:
			simulation.advance_fixed_step(0.01, [MatchAction.new(id, MatchAction.Type.SAVE, Vector2.LEFT)])
		var contact_seen := false
		for step in range(100):
			for fact in simulation.advance_fixed_step(0.01, []):
				contact_seen = contact_seen or fact.event_type == (MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED if keeper else MatchEvent.Type.BALL_HIT)
		_check(contact_seen, "miss trajectory still resolves actual keeper/body contact")

## Production random selection repeats with identical seed despite additional read-only observations.
func _test_replay() -> void:
	var traces: Array[String] = []
	for replay in range(2):
		var simulation := _match(0.0)
		simulation._shot_miss_sampler = Callable()
		simulation._shot_miss_side_sampler = Callable()
		simulation._shot_miss_margin_sampler = Callable()
		simulation._shot_aim_sampler = Callable()
		var event := _release(simulation)
		var aim := event.shot_aim
		if replay == 1:
			simulation.create_snapshot()
			simulation.get_event_history()
		traces.append(str([aim.is_miss, aim.miss_sample, aim.point_m]))
	_check(traces[0] == traces[1], "same new-version seed reproduces target")

## Aggregates independent failures so one boundary case cannot hide another.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
