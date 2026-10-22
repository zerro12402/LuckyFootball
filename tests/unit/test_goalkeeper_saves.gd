## Verifies release-time targeting and F04 contact outcomes without presentation or rendering.
extends SceneTree

var _failures: PackedStringArray = []
var _config: MatchConfigDefinition
var _field: FieldDefinition
var _aim_draws: int = 0
var _save_draws: int = 0
var _lane: int = ShotAim.Lane.CENTER
var _sample: float = 0.49

## Exercises deterministic cases against the production fixed-step simulation.
func _init() -> void:
	var repository := DataRepository.new()
	_check(repository.load_all(), "data loads")
	_config = repository.get_match_config_by_id("demo_match")
	_field = repository.get_field_by_id("demo_field")
	for lane in range(3):
		for sample in [0.49, 0.50]:
			_test_outcome(lane, sample)
	_test_release_timing()
	_test_invalid_opportunities()
	_test_pause_reset_replay()
	_test_wrong_lane_and_window()
	_test_catch_release_and_animation_duration()
	_test_seeded_sampling_replay()
	_test_configuration_validation()
	_test_large_step_contact_and_event_time()
	for failure in _failures:
		push_error(failure)
	print("Goalkeeper rules failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Counts injected aim samples so rejected/cancelled commands cannot draw early.
func _draw_aim() -> int:
	_aim_draws += 1
	return _lane

## Fixes the exact success boundary while counting contact-only samples.
func _draw_save() -> float:
	_save_draws += 1
	return _sample

## Registers one shooter, an opposing keeper and only the real field/rule definitions.
func _match(keeper_x: float = 23.0) -> MatchSimulation:
	_aim_draws = 0
	_save_draws = 0
	var simulation := MatchSimulation.new(44, _config, _field,
		MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN, Callable(), Callable(),
		_draw_aim, _draw_save)
	_check(simulation.register_player("shooter", Vector2(15, 0), 5.0, "attack", 80), "shooter")
	_check(simulation.register_player("keeper", Vector2(keeper_x, 0), 5.0, "defend", 80, 50, 50, true), "keeper")
	_check(simulation.register_team_attacking_goal("attack", Vector2(25, 0)), "goal")
	_check(simulation.register_team_attacking_goal("defend", Vector2(-25, 0)), "keeper goal")
	_check(simulation.register_ball(Vector2(15.5, 0)), "ball")
	simulation.start_match()
	simulation.advance_fixed_step(0.01, [])
	return simulation

## Runs each lane through success and failure, including unique ownership and unchanged misses.
func _test_outcome(lane: int, sample: float) -> void:
	_lane = lane
	_sample = sample
	var simulation := _match()
	var actions: Array[MatchAction] = [MatchAction.new("shooter", MatchAction.Type.SHOOT),
		MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2(-1, lane - 1))]
	simulation.advance_fixed_step(0.01, actions)
	_check(_save_draws == 0 and _aim_draws == 0, "no draws before kick/contact")
	var resolved: MatchEvent
	for step in range(100):
		for event in simulation.advance_fixed_step(0.01, []):
			if event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED:
				resolved = event
		if resolved != null:
			break
	_check(resolved != null, "lane %d sample %.2f must reach keeper" % [lane, sample])
	if resolved == null:
		return
	_check(_aim_draws == 1 and _save_draws == 1, "one release and one save sample")
	_check(resolved.goalkeeper_save.did_catch == (sample < 0.5), "0.49 catches, 0.50 misses")
	var snapshot := simulation.create_snapshot()
	if sample < 0.5:
		_check(snapshot.ball.owner_player_id == "keeper", "catch has unique keeper owner")
		_check(snapshot.ball.control_attachment == BallMatchState.ControlAttachment.KEEPER_HANDS, "catch attaches hands")
		_check(snapshot.ball.velocity_mps.is_zero_approx(), "catch cancels velocity")
		for step in range(130):
			simulation.advance_fixed_step(0.01, [])
		_check(simulation.create_snapshot().ball.owner_player_id == "keeper", "ownership survives action end")
		_check(simulation.create_snapshot().get_player("keeper").action_state == PlayerMatchState.ActionState.IDLE, "save finishes")
		var standing := simulation.create_snapshot()
		var keeper := standing.get_player("keeper")
		var expected_foot := (keeper.position_m
			+ keeper.facing_direction * simulation._ball_runtime_system._dribble_offset_m)
		_check(standing.ball.control_attachment == BallMatchState.ControlAttachment.FOOT,
			"finished save changes hand attachment to ordinary dribbling")
		_check(standing.ball.position_m.is_equal_approx(expected_foot),
			"standing keeper uses the ordinary dribble offset")
		_check(is_equal_approx(standing.ball.height_m, keeper.height_m),
			"standing catch puts the ball at foot height")
	else:
		_check(snapshot.ball.owner_player_id.is_empty(), "miss has no owner")
		_check(snapshot.ball.velocity_mps.x > 0.0, "miss never rebounds")
		var expected_state := (PlayerMatchState.ActionState.KNOCKED_DOWN if lane == 1
			else PlayerMatchState.ActionState.SAVING)
		_check(snapshot.get_player("keeper").action_state == expected_state, "lane-specific miss response")
		for step in range(80):
			simulation.advance_fixed_step(0.01, [])
		_check(_save_draws == 1, "one result per keeper/shot")
		_check(simulation.create_snapshot().right_goal_count == 1, "miss scores only on actual crossing, once")

## Release cancellation, real lane lock and ordinary shooter's attributes remain intact.
func _test_release_timing() -> void:
	_lane = 0
	var simulation := _match()
	simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT)])
	_check(_aim_draws == 0, "windup does not choose aim")
	simulation.advance_fixed_step(0.01, [MatchAction.new("", MatchAction.Type.RESET_ROUND)])
	_check(_aim_draws == 0 and _save_draws == 0, "cancelled kick consumes no samples")
	for lane in range(3):
		_lane = lane
		simulation = _match()
		simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT)])
		for step in range(30):
			var events := simulation.advance_fixed_step(0.01, [])
			for event in events:
				if event.event_type == MatchEvent.Type.BALL_SHOT:
					_check(event.shot_aim != null and event.shot_aim.lane == lane, "event locks lane")
					_check(is_equal_approx(event.shot_aim.point_m.y, float(lane - 1)), "target quarter points")
		_check(_aim_draws == 1 and _save_draws == 0, "no intent means no F04")

## No intent, post-line keeper and high passes cannot activate or bypass F04.
func _test_invalid_opportunities() -> void:
	_lane = 1
	var simulation := _match(28.0)
	simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT),
		MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2.LEFT)])
	for step in range(90):
		simulation.advance_fixed_step(0.01, [])
	_check(_save_draws == 0, "boundary precedes keeper")
	simulation = _match()
	simulation._player_runtime_system.get_player("keeper").state_machine.start_knockdown(_config)
	simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT),
		MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2.LEFT)])
	for step in range(80):
		simulation.advance_fixed_step(0.01, [])
	_check(_save_draws == 0, "down keeper cannot save")
	simulation = _match()
	simulation._ball_runtime_system.state._launch_pass("keeper", Vector2(20, 0), 20, 1.8)
	simulation.advance_fixed_step(0.01, [MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2.LEFT)])
	for step in range(60):
		simulation.advance_fixed_step(0.01, [])
	_check(_save_draws == 0, "high pass does not use F04")

## Pausing freezes a prepared save and resets remove hand ownership and old intent.
func _test_pause_reset_replay() -> void:
	_lane = 0
	_sample = 0.49
	var simulation := _match()
	simulation.advance_fixed_step(0.01, [MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2(-1, -1))])
	var before := simulation.create_snapshot()
	simulation.pause_match()
	simulation.advance_fixed_step(0.5, [])
	_check(simulation.create_snapshot().elapsed_seconds == before.elapsed_seconds, "pause freezes save timer")
	simulation.resume_match()
	simulation.advance_fixed_step(0.01, [MatchAction.new("", MatchAction.Type.RESET_ROUND)])
	_check(simulation.create_snapshot().get_player("keeper").action_state == PlayerMatchState.ActionState.IDLE, "reset cancels save")
	_check(simulation.create_snapshot().ball.control_attachment == BallMatchState.ControlAttachment.FOOT, "reset clears hand attachment")

## Collects independent assertions before returning a process failure.
func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


## Opposite-lane saves and expired/early windows cannot produce F04 contact samples.
func _test_wrong_lane_and_window() -> void:
	_lane = ShotAim.Lane.UPPER
	var simulation := _match()
	simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT),
		MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2(-1, 1))])
	for step in range(70):
		simulation.advance_fixed_step(0.01, [])
	_check(_save_draws == 0, "opposite lane has no physical save contact")
	_lane = 1
	simulation = _match()
	simulation.advance_fixed_step(0.01, [MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2.LEFT)])
	for step in range(125):
		simulation.advance_fixed_step(0.01, [])
	simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT)])
	for step in range(70):
		simulation.advance_fixed_step(0.01, [])
	_check(_save_draws == 0, "expired action cannot save")
	var old_start := _config.keeper_window_start_seconds
	var old_end := _config.keeper_window_end_seconds
	_config._keeper_window_start_seconds = 0.95
	_config._keeper_window_end_seconds = 1.1
	simulation = _match()
	simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT),
		MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2.LEFT)])
	for step in range(70):
		simulation.advance_fixed_step(0.01, [])
	_check(_save_draws == 0, "pre-window crossing cannot save")
	_config._keeper_window_start_seconds = old_start
	_config._keeper_window_end_seconds = old_end

## A catch can legally release; misses finish their full pose before automatic settlement reset.
func _test_catch_release_and_animation_duration() -> void:
	_lane = 0
	_sample = 0.49
	var simulation := _match()
	simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT),
		MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2(-1, -1))])
	for step in range(130):
		simulation.advance_fixed_step(0.01, [])
	_check(simulation.create_snapshot().ball.owner_player_id == "keeper", "catch persists to release test")
	simulation.advance_fixed_step(0.01, [MatchAction.new("keeper", MatchAction.Type.SHOOT)])
	for step in range(25):
		simulation.advance_fixed_step(0.01, [])
	_check(simulation.create_snapshot().ball.owner_player_id.is_empty(), "keeper legally releases held ball")
	_check(simulation.create_snapshot().ball.control_attachment == BallMatchState.ControlAttachment.FOOT, "release clears hand attachment")
	_sample = 0.5
	simulation = _match()
	simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT),
		MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2(-1, -1))])
	var reset_seen := false
	for step in range(200):
		for event in simulation.advance_fixed_step(0.01, []):
			if event.event_type == MatchEvent.Type.RESET_COMPLETED:
				_check(event.match_time_seconds >= _config.keeper_action_duration_seconds, "miss dive finishes before auto reset")
				reset_seen = true
		if reset_seen:
			break
	_check(reset_seen, "miss eventually resets")

## Production seeded aim/F04 sampling and extra snapshot reads reproduce the same facts.
func _test_seeded_sampling_replay() -> void:
	var traces: Array[String] = []
	for replay in range(2):
		var simulation := _match()
		simulation._shot_aim_sampler = Callable()
		simulation._keeper_sampler = simulation._sample_ball_route
		simulation.advance_fixed_step(0.01, [MatchAction.new("shooter", MatchAction.Type.SHOOT)])
		var has_prepared := false
		var trace := ""
		for step in range(100):
			var actions: Array[MatchAction] = []
			var aim := simulation._ball_runtime_system.current_shot_aim
			if aim != null and not has_prepared:
				actions.append(MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2(-1, aim.lane - 1)))
				has_prepared = true
			if replay == 1:
				simulation.create_snapshot()
				simulation.get_event_history()
			for event in simulation.advance_fixed_step(0.01, actions):
				if event.shot_aim != null:
					trace += str(event.shot_aim.lane)
				if event.goalkeeper_save != null:
					trace += str(event.goalkeeper_save.sample)
		traces.append(trace)
	_check(traces[0] == traces[1] and not traces[0].is_empty(), "production seed replays without view draws")

## Invalid CSV rule values fail atomically while older fixtures retain optional defaults.
func _test_configuration_validation() -> void:
	var text := FileAccess.get_file_as_string("res://resources/data/match_configs.csv")
	for key in ["keeper_save_probability", "keeper_contact_radius_m", "keeper_action_duration_seconds", "shot_aim_width_fraction"]:
		var lines := text.split("\n")
		for index in range(lines.size()):
			if lines[index].begins_with(key + ","):
				lines[index] = key + ",-1,invalid"
		var path := "user://keeper_invalid_config.csv"
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("\n".join(lines))
		file.close()
		var result := MatchConfigDataRepository.new().load_from_csv(path)
		_check(not result.is_success and result.configs.is_empty(), "invalid keeper CSV rejected: " + key)
		DirAccess.remove_absolute(path)


## Swept contact must win before a later goal even when both fit in one large step.
func _test_large_step_contact_and_event_time() -> void:
	_lane = 1
	_sample = 0.49
	var simulation := _match()
	simulation.advance_fixed_step(0.2, [MatchAction.new("shooter", MatchAction.Type.SHOOT),
		MatchAction.new("keeper", MatchAction.Type.SAVE, Vector2.LEFT)])
	var events := simulation.advance_fixed_step(0.5, [])
	_check(_save_draws == 1, "large step finds exact keeper contact")
	_check(simulation.create_snapshot().ball.owner_player_id == "keeper", "earlier catch cancels later boundary")
	_check(simulation.create_snapshot().right_goal_count == 0, "obsolete shot cannot score after catch")
	var last_time := 0.0
	for event in events:
		_check(event.match_time_seconds >= last_time, "contact facts have ordered timestamps")
		last_time = event.match_time_seconds
