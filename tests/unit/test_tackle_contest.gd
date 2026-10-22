## Checks F02 probabilities, one-shot sampling, failed-tackle jumps and the real two-AI test mode.
extends SceneTree

var _config: MatchConfigDefinition
var _failures: PackedStringArray = []
var _sample: float = 0.99
var _draws: int = 0

## Defers only the shared-scene integration check; probability and simulation checks use pure data.
func _init() -> void:
	call_deferred("_run")

## Runs independent formula, geometry, state, determinism and mode-wiring contracts.
func _run() -> void:
	_config = MatchConfigDataRepository.new().load_from_csv("res://resources/data/match_configs.csv").configs[0]
	_test_probability_and_sample_boundary()
	_test_failure_keeps_ball_and_jumps_once()
	_test_success_and_invalid_contacts()
	_test_contact_later_in_active_window()
	_test_early_tackle_keeps_contact_radius()
	_test_seeded_replay()
	_test_config_validation()
	_test_two_ai_mode()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: F02 tackle contest and two AI mode")
	quit(0 if _failures.is_empty() else 1)

## Equal values mean 50%; stronger tackling helps without eliminating either outcome.
func _test_probability_and_sample_boundary() -> void:
	_check(is_equal_approx(TackleContestResolver.probability(80, 80, _config), 0.5), "Equal F02 must be 50%")
	_check(is_equal_approx(TackleContestResolver.probability(1, 100, _config), 0.1), "Lower clamp must be 10%")
	_check(is_equal_approx(TackleContestResolver.probability(100, 1, _config), 0.9), "Upper clamp must be 90%")
	var previous := 0.0
	for value in range(1, 101):
		var chance := TackleContestResolver.probability(value, 80, _config)
		_check(chance >= previous, "Higher tackling must never reduce success probability")
		previous = chance
	_sample = 0.5
	_draws = 0
	var result := TackleContestResolver.resolve(80, 80, _config, _draw)
	_check(not result.succeeded and _draws == 1, "u equal to P must fail with exactly one draw")
	_sample = 0.499
	_check(TackleContestResolver.resolve(80, 80, _config, _draw).succeeded, "u below P must succeed")

## A failed contact starts the existing jump, preserves possession and never rerolls that action.
func _test_failure_keeps_ball_and_jumps_once() -> void:
	_sample = 0.99
	var simulation := _match()
	var event := _resolve(simulation)
	_check(event != null and event.event_type == MatchEvent.Type.TACKLE_FAILED, "High sample must fail")
	var carrier := simulation.create_snapshot().get_player("carrier")
	_check(carrier.jump_phase == PlayerMatchState.JumpPhase.TAKEOFF, "Failure must immediately start the dribble jump")
	_check(simulation.create_snapshot().ball.owner_player_id == "carrier", "Failure must preserve the carrier")
	var peak := 0.0
	for step in range(30):
		simulation.advance_fixed_step(0.05, [])
		var snapshot := simulation.create_snapshot()
		carrier = snapshot.get_player("carrier")
		peak = maxf(peak, carrier.height_m)
		_check(is_equal_approx(snapshot.ball.height_m, carrier.height_m), "Carried ball must follow jump height")
	_check(peak > 0.5 and carrier.jump_phase == PlayerMatchState.JumpPhase.NONE, "Jump must rise and finish landing")
	_check(_draws == 1, "One tackle must not reroll after a failed contact")
	_check(simulation._player_runtime_system.get_player("defender").tackling_attribute == 80,
		"Contest must not mutate base tackling")

## Real success transfers once; invalid geometry, airborne targets and expired windows never draw.
func _test_success_and_invalid_contacts() -> void:
	_sample = 0.0
	var simulation := _match()
	var event := _resolve(simulation)
	_check(event != null and event.event_type == MatchEvent.Type.TACKLE_SUCCEEDED, "Low sample must transfer ball")
	_check(_draws == 1 and simulation.create_snapshot().ball.owner_player_id == "defender", "Success must assign one owner")
	_check(simulation.create_snapshot().get_player("carrier").possession_state == PlayerMatchState.PossessionState.NO_BALL,
		"Old carrier must lose possession atomically")
	for scenario in ["far", "airborne", "expired"]:
		simulation = _match()
		if scenario == "far":
			simulation._player_runtime_system.get_player("defender").state._set_position(Vector2(-10.0, 0.0))
		elif scenario == "airborne":
			simulation._player_runtime_system.get_player("carrier").state_machine.try_start_jump(_config)
			simulation.advance_fixed_step(0.2, [])
		simulation.advance_fixed_step(1.1 if scenario == "expired" else 0.05,
			[MatchAction.new("defender", MatchAction.Type.TACKLE, Vector2.ZERO, "carrier")])
		_check(_draws == 0, "Invalid or expired contact must not consume probability randomness")

## Missing contact at window start must not discard a later legal contact in the same action.
func _test_contact_later_in_active_window() -> void:
	_sample = 0.99
	var simulation := _match()
	simulation.advance_fixed_step(0.05, [MatchAction.new(
		"defender", MatchAction.Type.TACKLE, Vector2.ZERO, "carrier")])
	var carrier := simulation._player_runtime_system.get_player("carrier")
	carrier.state._set_position(Vector2(10.0, 0.0))
	simulation.advance_fixed_step(0.1, [])
	_check(_draws == 0, "Window without contact must not draw")
	carrier.state._set_position(simulation.create_snapshot().get_player("defender").position_m + Vector2(0.8, 0.0))
	simulation.advance_fixed_step(0.05, [])
	_check(_draws == 1, "Later legal contact inside the active window must resolve once")


## AI starts before an approaching target reaches contact range, without resolving from afar.
func _test_early_tackle_keeps_contact_radius() -> void:
	_sample = 0.99
	var simulation := _match()
	var defender := simulation._player_runtime_system.get_player("defender")
	defender.state._set_position(Vector2(-1.6, 0.0))
	var ai := TackleChaseAI.new("defender", "carrier", _config, Vector2(25.0, 0.0), 5.0)
	var stationary_actions := ai.propose_actions(simulation.create_snapshot())
	var stationary_tackle := false
	for action in stationary_actions:
		stationary_tackle = stationary_tackle or action.action_type == MatchAction.Type.TACKLE
	_check(not stationary_tackle, "AI must not blindly start too far from a stationary carrier")
	simulation.advance_fixed_step(0.01, [MatchAction.new("carrier", MatchAction.Type.MOVE, Vector2.LEFT)])
	var carrier := simulation._player_runtime_system.get_player("carrier")
	defender.state._set_position(carrier.state.position_m - Vector2(1.6, 0.0))
	var actions := ai.propose_actions(simulation.create_snapshot())
	var proposed := false
	for action in actions:
		proposed = proposed or action.action_type == MatchAction.Type.TACKLE
	_check(proposed, "Approaching carrier must trigger early tackle at 1.6m")
	simulation.advance_fixed_step(0.05, actions)
	_check(defender.state.action_state == PlayerMatchState.ActionState.TACKLING,
		"Simulation must accept an early tackle windup")
	_check(_draws == 0 and simulation.create_snapshot().ball.owner_player_id == "carrier",
		"Early windup outside contact range must neither draw nor transfer possession")
	simulation.advance_fixed_step(0.1, [])
	_check(_draws == 1, "F02 must resolve only after the windup reaches real contact")


## Snapshot/event readers do not affect the shared seeded match random stream.
func _test_seeded_replay() -> void:
	var samples: Array[float] = []
	for replay in range(2):
		var simulation := _match(true)
		if replay == 1:
			simulation.create_snapshot()
			simulation.get_event_history()
		var event := _resolve(simulation)
		_check(event != null, "Seeded tackle must resolve")
		if event != null:
			samples.append(event.tackle_contest.sample)
	_check(samples.size() == 2 and samples[0] == samples[1], "Same seed and actions must replay exactly")

## Rejects invalid curve parameters before they reach a running match.
func _test_config_validation() -> void:
	var original := FileAccess.get_file_as_string("res://resources/data/match_configs.csv")
	var invalid_rows: Array[String] = ["tackle_probability_scale,18.0,|tackle_probability_scale,0,",
		"tackle_probability_min,0.1,|tackle_probability_min,-0.1,",
		"tackle_probability_max,0.9,|tackle_probability_max,1.1,",
		"tackle_probability_min,0.1,|tackle_probability_min,0.95,",
		"tackle_start_range_m,1.8,|tackle_start_range_m,1.0,"]
	var path := "user://f02_invalid.csv"
	for row in invalid_rows:
		var parts := row.split("|")
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(original.replace(parts[0], parts[1]))
		file.close()
		_check(not MatchConfigDataRepository.new().load_from_csv(path).is_success, "Bad F02 config must fail")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## Both real test players move without keyboard input and exchange attack/defense roles.
func _test_two_ai_mode() -> void:
	var bootstrap := (load("res://scenes/main/game_bootstrap.tscn") as PackedScene).instantiate() as GameBootstrap
	bootstrap.demo_mode = GameBootstrap.DemoMode.TACKLE_TEST
	root.add_child(bootstrap)
	bootstrap.set_process(false)
	_check(not (bootstrap.get_node("KeyboardPlayerInputAdapter") as Node).is_processing(), "Keyboard must not control either AI")
	bootstrap.queue_action(MatchAction.new(bootstrap.demo_player_id, MatchAction.Type.MOVE, Vector2.LEFT))
	_check(bootstrap._queued_actions.is_empty(), "Manual player commands must not override AI")
	var saw_success := false
	var saw_failure_jump := false
	var first_moved := false
	var second_moved := false
	var initial := bootstrap._match_simulation.create_snapshot()
	for step in range(2400):
		bootstrap._process(bootstrap.fixed_delta_seconds)
		var snapshot := bootstrap._match_simulation.create_snapshot()
		first_moved = first_moved or snapshot.get_player(bootstrap.demo_player_id).position_m != initial.get_player(bootstrap.demo_player_id).position_m
		second_moved = second_moved or snapshot.get_player(bootstrap.demo_opponent_id).position_m != initial.get_player(bootstrap.demo_opponent_id).position_m
		for event in bootstrap._match_simulation.get_event_history().slice(-4):
			if event.event_type == MatchEvent.Type.TACKLE_SUCCEEDED:
				saw_success = true
			if event.event_type == MatchEvent.Type.TACKLE_FAILED:
				var carrier := snapshot.get_player(event.target_player_id)
				saw_failure_jump = saw_failure_jump or carrier.jump_phase != PlayerMatchState.JumpPhase.NONE
		if saw_success and saw_failure_jump and first_moved and second_moved:
			break
	_check(first_moved and second_moved, "Both test players must be driven by AI")
	_check(saw_success and saw_failure_jump, "Seeded two-AI mode must visibly exercise success and failed-tackle jump")
	var definitions := bootstrap.data_repository
	_check(bootstrap._match_simulation._player_runtime_system.get_player(bootstrap.demo_opponent_id).tackling_attribute
		== definitions.get_player_by_id(bootstrap.demo_opponent_id).tackling, "AI must use actual CSV tackling")
	bootstrap.free()

## Registers explicit equal-attribute players and acquires the initial carrier's ball.
func _match(seeded: bool = false) -> MatchSimulation:
	_draws = 0
	var sampler := Callable() if seeded else _draw
	var simulation := MatchSimulation.new(44, _config, null,
		MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN, Callable(), Callable(), Callable(), Callable(), sampler)
	simulation.register_player("carrier", Vector2.ZERO, 5.0, "home", 80, 50, 80)
	simulation.register_player("defender", Vector2(-1.0, 0.0), 5.0, "away", 50, 50, 50, false, 0, 80)
	simulation.register_ball(Vector2(0.5, 0.0))
	simulation.start_match()
	simulation.advance_fixed_step(0.05, [])
	return simulation

## Advances only to the one contact result so later phases cannot hide the immediate reaction.
func _resolve(simulation: MatchSimulation) -> MatchEvent:
	for step in range(20):
		var actions: Array[MatchAction] = []
		if step == 0:
			actions.append(MatchAction.new("defender", MatchAction.Type.TACKLE, Vector2.ZERO, "carrier"))
		for event in simulation.advance_fixed_step(0.05, actions):
			if event.tackle_contest != null:
				return event
	return null

## Counts actual sampler consumption separately from reading results or computing probabilities.
func _draw() -> float:
	_draws += 1
	return _sample

## Records a contract mismatch and continues independent cases.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
