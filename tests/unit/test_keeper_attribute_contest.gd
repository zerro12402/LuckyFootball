## Verifies F04 flight accumulation, attribute formulas and contact-time commits without rendering.
extends SceneTree

var _failures: PackedStringArray = []
var _config: MatchConfigDefinition
var _draws: int = 0
var _sample: float = 0.0

## Exercises pure boundaries, validated data and actual fixed-step contact ordering.
func _init() -> void:
	var repository := DataRepository.new()
	_check(repository.load_all(), "production data loads")
	_config = repository.get_match_config_by_id("demo_match")
	_test_formula()
	_test_reach_independent_distance()
	_test_configuration()
	_test_runtime_binding()
	_test_context_lifecycle()
	_test_contact_and_rebound()
	for failure in _failures:
		push_error(failure)
	print("F04 attribute contest failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Counts only physically eligible F04 samples, independently of target and F08 route samples.
func _draw_save() -> float:
	_draws += 1
	return _sample

## Checks exact distance boundaries, fractional effective values and complementary probabilities.
func _test_formula() -> void:
	for distance in [0.0, 5.0, 20.0]:
		var expected := 40.0 if distance == 20.0 else 80.0
		_check(is_equal_approx(GoalkeeperSaveResolver.effective_shooting(80, distance, 0, _config), expected), "0/5/20m boundary")
	var previous := 1.0
	for count in range(3):
		var effective := GoalkeeperSaveResolver.effective_shooting(80, 15, count, _config)
		_check(is_equal_approx(effective, 80.0 / (1.0 + 100.0 / 225.0) * pow(0.85, count)), "n exponent applied once")
		var win := 1.0 - GoalkeeperSaveResolver.save_probability(effective, 70, _config)
		_check(win <= previous, "more successful knockdowns never increase bounded shot threat")
		previous = win
	_check(GoalkeeperSaveResolver.effective_shooting(1, 100, 2, _config) < 1.0, "effective shooting may fall below one")
	_check(is_equal_approx(GoalkeeperSaveResolver.save_probability(70, 70, _config), 0.5), "equal values give 50%")
	_check(GoalkeeperSaveResolver.save_probability(80, 90, _config) > GoalkeeperSaveResolver.save_probability(80, 60, _config), "higher goalkeeping improves save")
	_check(is_equal_approx(GoalkeeperSaveResolver.save_probability(0, 100, _config), 0.9), "upper save bound")
	_check(is_equal_approx(GoalkeeperSaveResolver.save_probability(100, 1, _config), 0.1), "lower save bound")
	var source := BallShotSource.new("shooter", "attack", 80, 1)
	var context := ShotFlightContext.new(source)
	context._advance_distance(15)
	context._record_knockdown("one")
	context._record_knockdown("one")
	context._record_knockdown("two")
	var ids := context.knocked_down_ids
	ids.clear()
	_check(context.knockdown_count == 2, "victim IDs are unique and exported by copy")
	var probability := GoalkeeperSaveResolver.save_probability(GoalkeeperSaveResolver.effective_shooting(80, 15, 2, _config), 70, _config)
	for sample in [probability - 0.00001, probability]:
		var result := GoalkeeperSaveResolver.resolve("keeper", source, 1, Vector2.ZERO, 0.0,
			70, context, _config, func() -> float: return sample,
			Vector2(_config.ball_radius_m, 0), Vector2.RIGHT)
		_check(result.did_catch == (sample < probability), "threshold equality fails")
		_check(result.base_shooting == 80 and result.knockdown_count == 2, "immutable input facts")
		_check(is_equal_approx(result.save_probability + result.shot_win_probability, 1.0), "complementary probabilities")
	_check(source.shooting == 80, "F04 never overwrites locked F08/F11 shooting")

## Changing contact reach changes timing but not the reference distance or its attenuation.
func _test_reach_independent_distance() -> void:
	var origin := Vector2(15.55, 0)
	var center := Vector2(22.55, 0)
	for direction: Vector2 in [Vector2.RIGHT, Vector2(1, 0.1).normalized()]:
		var expected := (center - origin).dot(direction) - _config.ball_radius_m
		for reach: float in [0.4, 2.0]:
			var offset := center - origin
			var along := offset.dot(direction)
			var side_squared := offset.length_squared() - along * along
			var radius := reach + _config.ball_radius_m
			if side_squared > radius * radius:
				continue
			var traveled := along - sqrt(radius * radius - side_squared)
			var point := origin + direction * traveled
			var distance := GoalkeeperSaveResolver.contest_distance(traveled, point, center, direction, _config.ball_radius_m)
			_check(is_equal_approx(distance, expected), "contact radius does not shorten F04 distance")
			_check(is_equal_approx(GoalkeeperSaveResolver.contest_distance(traveled + 3.0, point, center, direction, _config.ball_radius_m), expected + 3.0), "rebound path retained and correction applied once")
	_check(is_equal_approx(GoalkeeperSaveResolver.contest_distance(4.45, Vector2(20, 0), center, Vector2.RIGHT, _config.ball_radius_m), 6.45), "default center distance excludes keeper reach")
	_check(is_equal_approx(GoalkeeperSaveResolver.contest_distance(9.0, Vector2(24, 0), center, Vector2.RIGHT, _config.ball_radius_m), 9.0), "overlapping or passed hand plane never subtracts committed travel")

## Rejects each invalid configured dimension through the production repository.
func _test_configuration() -> void:
	var text := FileAccess.get_file_as_string("res://resources/data/match_configs.csv")
	for pair in [["shot_contest_free_distance_m,5.0", "shot_contest_free_distance_m,-1"],
		["shot_contest_distance_scale_m,15.0", "shot_contest_distance_scale_m,0"],
		["shot_contest_knockdown_retention,0.85", "shot_contest_knockdown_retention,0"],
		["shot_contest_knockdown_retention,0.85", "shot_contest_knockdown_retention,1.01"],
		["keeper_contest_probability_scale,5.0", "keeper_contest_probability_scale,-2"],
		["keeper_contest_shot_win_min,0.1", "keeper_contest_shot_win_min,0.95"],
		["keeper_contest_shot_win_max,0.9", "keeper_contest_shot_win_max,1.01"],
		["shot_contest_free_distance_m,5.0", "shot_contest_free_distance_m,NaN"],
		["keeper_contest_probability_scale,5.0", "keeper_contest_probability_scale,inf"]]:
		var file := FileAccess.open("user://f04_invalid.csv", FileAccess.WRITE)
		file.store_string(text.replace(pair[0], pair[1]))
		file.close()
		_check(not MatchConfigDataRepository.new().load_from_csv("user://f04_invalid.csv").is_success, "invalid config: " + pair[1])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://f04_invalid.csv"))

## Proves the definition route binds real G and the explicit fixture route validates its own input.
func _test_runtime_binding() -> void:
	var repository := DataRepository.new()
	repository.load_all()
	var definition := repository.get_player_by_id("steady_keeper")
	var simulation := MatchSimulation.new(91, _config)
	_check(simulation.register_player_from_definition(definition, Vector2.ZERO, "defend", true), "keeper definition registers")
	_check(simulation._player_runtime_system.get_player(definition.player_id).goalkeeping_attribute == definition.goalkeeping, "real CSV goalkeeping bound")
	_check(not simulation.register_player("invalid", Vector2.ZERO, 5, "defend", 80, 50, 50, true, 0, 50, 0), "invalid G rejected")
	_check(definition.goalkeeping == 94, "static keeper definition unchanged")

## Registers actual bodies before play, with F11 isolated and F08 route explicitly injected.
func _match(bodies: int = 0, rebound: bool = false, keeper: bool = true,
		strength: int = 40, dodge: bool = false) -> MatchSimulation:
	_draws = 0
	var simulation := MatchSimulation.new(91, _config, null,
		MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN,
		func() -> float: return 0.9 if rebound else 0.0,
		func(_id: String) -> bool: return dodge,
		func() -> int: return ShotAim.Lane.CENTER, _draw_save,
		Callable(), Callable(), Callable(), Callable(), 0)
	simulation.register_player("shooter", Vector2.ZERO, 5, "attack", 80)
	simulation.register_team_attacking_goal("attack", Vector2(25, 0))
	if keeper:
		simulation.register_player("keeper", Vector2(-4, 0) if rebound else Vector2(6, 0),
			5, "defend", 70, 50, 50, true, 0, 50, 70)
	for index in range(bodies):
		simulation.register_player("wall_%d" % index, Vector2(2 + index * 1.2, 0), 5, "defend", 50, strength)
	simulation.register_ball(Vector2(0.55, 0))
	simulation.start_match()
	simulation.advance_fixed_step(0.01, [])
	return simulation

## Runs only to release so callers can inspect the initial accumulator and exact origin.
func _release(simulation: MatchSimulation) -> Vector2:
	simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT)])
	for step in range(30):
		var events := simulation.advance_fixed_step(0.01, [])
		for event in events:
			if event.event_type == MatchEvent.Type.BALL_SHOT:
				return Vector2(0.55, 0)
	_check(false, "legal shot releases")
	return Vector2.ZERO

## Covers pause/read invariance, natural end, catch, reset and a fresh actual release.
func _test_context_lifecycle() -> void:
	var simulation := _match(0, false, false)
	_release(simulation)
	var context := simulation._ball_runtime_system.shot_context
	_check(context != null and context.knockdown_count == 0, "new shot starts with no victims")
	var before := context.distance_m
	var frozen := simulation.create_snapshot().ball
	simulation.pause_match()
	simulation.advance_fixed_step(0.5, [])
	simulation.create_snapshot()
	_check(context.distance_m == before and frozen.shot_distance_m == before, "pause/reads do not advance, snapshots do not alias")
	simulation.resume_match()
	for step in range(20):
		simulation.advance_fixed_step(0.01, [])
	_check(frozen.shot_distance_m == before, "old snapshot remains immutable as flight advances")
	simulation.advance_fixed_step(0.01, [MatchAction.new("", MatchAction.Type.RESET_ROUND)])
	_check(simulation._ball_runtime_system.shot_context == null, "reset clears old context")
	simulation.advance_fixed_step(0.01, [])
	_release(simulation)
	_check(simulation._ball_runtime_system.shot_context != context, "actual new release has fresh context")
	_check(simulation._ball_runtime_system.shot_context.knockdown_count == 0, "new shot does not inherit victims")
	for step in range(400):
		simulation.advance_fixed_step(0.01, [])
	_check(simulation._ball_runtime_system.shot_context == null, "natural stop clears whole-shot context")

## Same-step chain hits affect F04 immediately; a rebound keeps prior travel and victim facts.
func _test_contact_and_rebound() -> void:
	for count in range(3):
		_sample = 0.0
		var simulation := _match(count)
		var origin := _release(simulation)
		_check(_draws == 0, "no F04 draw before physical contact")
		simulation.advance_fixed_step(0.35, [MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2.LEFT)])
		var save := _save_result(simulation)
		_check(save != null, "same large step reaches keeper after chain")
		if save == null:
			continue
		_check(save.knockdown_count == count, "same-step prior victims visible at save")
		_check(is_equal_approx(save.flight_distance_m, origin.distance_to(save.position_m)), "partial step ends at contact, not future endpoint")
		_check(save.distance_m > save.flight_distance_m, "formula distance excludes early reach without faking flight")
		_check(_draws == 1, "one F04 sample per physical shot/keeper")
		_check(simulation._ball_runtime_system.shot_context == null, "catch clears live context but result retains facts")
	# A central keeper miss is not an F08 defender knockdown and the same shot keeps travelling.
	_sample = 0.999
	var leak := _match()
	_release(leak)
	leak.advance_fixed_step(0.25, [MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2.LEFT)])
	var leaked := _save_result(leak)
	var leak_context := leak._ball_runtime_system.shot_context
	_check(leaked != null and not leaked.did_catch, "physical miss resolved independently")
	_check(leak_context != null and leak_context.knockdown_count == 0
		and leak_context.distance_m > leaked.flight_distance_m, "keeper's failure knockback adds no n and leak keeps path")
	leak.advance_fixed_step(0.05, [])
	_check(_draws == 1, "miss cannot repeatedly sample F04 during the crossing")
	# After one strict-greater hit, an equal-strength second target still uses S0, not the decayed value.
	_sample = 0.0
	var equal := _match(2, false, false)
	equal._player_runtime_system.get_player("wall_1")._strength_attribute = 80
	_release(equal)
	var second: BallImpactResult
	for step in range(15):
		for fact in equal.advance_fixed_step(0.01, []):
			if fact.event_type == MatchEvent.Type.BALL_REBOUNDED and fact.ball_impact.target_player_id == "wall_1":
				second = fact.ball_impact
		if second != null:
			break
	_check(second != null and second.was_knocked_down and second.source.shooting == 80
		and second.route_sample == -1.0, "F08 equality still knocks down with fixed rebound after prior attenuation")
	_check(equal._ball_runtime_system.shot_context.knockdown_count == 2, "equal-value committed victim included once")
	var simulation := _match(1, true)
	_release(simulation)
	for step in range(100):
		var actions: Array[MatchAction] = []
		if step == 0:
			actions.append(MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2.RIGHT))
		simulation.advance_fixed_step(0.01, actions)
		if _save_result(simulation) != null:
			break
	var bounced := _save_result(simulation)
	_check(bounced != null, "returning rebound physically reaches keeper")
	if bounced != null:
		_check(bounced.knockdown_count == 1 and bounced.flight_distance_m > 1.0, "rebound retains prior victim and path")
		_check(bounced.flight_distance_m > Vector2(0.55, 0).distance_to(bounced.position_m), "path length is not straight-line displacement")
	for dodged in [false, true]:
		simulation = _match(1, false, false, 90, dodged)
		_release(simulation)
		for step in range(5):
			simulation.advance_fixed_step(0.01, [])
		var context := simulation._ball_runtime_system.shot_context
		_check(context != null and context.knockdown_count == 0, "dodge or hit without knockdown adds no victim")

## Reads only the resolved F04 event so later ownership cleanup cannot alter the observation.
func _save_result(simulation: MatchSimulation) -> GoalkeeperSaveResult:
	for event in simulation.get_event_history():
		if event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED:
			return event.goalkeeper_save
	return null

## Collects independent failures while preserving deterministic termination.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
