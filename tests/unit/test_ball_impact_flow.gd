## Exercises ordered shot impacts, strict F08, injected draws and free-ball rebounds.
extends SceneTree

var _failures: PackedStringArray = []
var _config: MatchConfigDefinition
var _field: FieldDefinition
var _draw_count: int = 0
var _sample: float = 0.1

## Runs independent contact outcomes and checks end-to-end ordering and replay.
func _init() -> void:
	_test_hit_before_goal_and_frozen_source()
	_test_equal_and_lower_values_rebound_without_draw()
	_test_knockdown_rebound_and_dodge()
	_test_low_speed_and_exact_sample_boundary()
	_test_boundary_before_player_and_keeper_route()
	_test_chain_and_continuous_deduplication()
	_test_seeded_replay()
	_test_airborne_and_header_sources()
	_test_knockback_follows_incoming_ball_and_lands()
	_test_custom_knockback_and_reset()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: ball impact flow")
	quit(0 if _failures.is_empty() else 1)

## Proves a swept hit changes state before a later goal and preserves the release attribute.
func _test_hit_before_goal_and_frozen_source() -> void:
	var simulation := _match_with_defender(60)
	_launch(simulation)
	var source := simulation._ball_runtime_system.shot_source
	_check(source != null and source.shooting == 80, "Shot source must lock the release attribute")
	simulation._player_runtime_system.get_player("shooter")._shooting_attribute = 1
	simulation.advance_fixed_step(0.5, [])
	var history := simulation.get_event_history()
	_check(_index(history, MatchEvent.Type.BALL_CONTACT) < _index(history,
		MatchEvent.Type.PLAYER_KNOCKED_DOWN), "Contact must precede knockdown")
	_check(_index(history, MatchEvent.Type.PLAYER_KNOCKED_DOWN) < _index(history,
		MatchEvent.Type.GOAL_SCORED), "Earlier player hit must precede the goal")
	_check(_count(history, MatchEvent.Type.BALL_HIT) == 1, "Continuous hit must settle once")
	_check(_draw_count == 1, "Successful F08 must consume exactly one route draw")
	_check(simulation.create_snapshot().ball.owner_player_id.is_empty(),
		"Impact must preserve the sole unowned ball")

## Equality launches the victim; weaker shots leave them upright, both rebound without drawing.
func _test_equal_and_lower_values_rebound_without_draw() -> void:
	for strength in [80, 90]:
		var simulation := _match_with_defender(strength)
		_launch(simulation)
		simulation.advance_fixed_step(0.4, [])
		var history := simulation.get_event_history()
		_check(_count(history, MatchEvent.Type.BALL_HIT) == 1, "Equal/lower shot must hit")
		_check(_count(history, MatchEvent.Type.PLAYER_KNOCKED_DOWN) == (1 if strength == 80 else 0),
			"Equal attributes must knock down; weaker shots must not")
		_check(_count(history, MatchEvent.Type.BALL_REBOUNDED) == 1,
			"Equal and weaker shots must rebound")
		_check(_draw_count == 0, "Equal and weaker shots must not draw route randomness")
		_check(_count(history, MatchEvent.Type.GOAL_SCORED) == 0,
			"Blocked shot must not score along the obsolete path")
		for event in history:
			if event.event_type == MatchEvent.Type.BALL_REBOUNDED:
				_check(event.ball_impact.velocity_after_mps.x < 0.0,
					"Rebound must initially travel in the reflected direction before later control")

## Distinguishes knockdown+rebound from independent successful F07 with no F08 draw.
func _test_knockdown_rebound_and_dodge() -> void:
	var rebound := _match_with_defender(60, 0.9)
	_launch(rebound)
	rebound.advance_fixed_step(0.4, [])
	_check(_count(rebound.get_event_history(), MatchEvent.Type.PLAYER_KNOCKED_DOWN) == 1,
		"Knockdown must also be possible when the ball rebounds")
	_check(_count(rebound.get_event_history(), MatchEvent.Type.BALL_REBOUNDED) == 1,
		"Upper half of route samples must rebound")
	var dodge := _match_with_defender(1, 0.1, true)
	_launch(dodge)
	dodge.advance_fixed_step(0.5, [])
	var history := dodge.get_event_history()
	_check(_count(history, MatchEvent.Type.BALL_DODGED) == 1, "F07 dodge must be distinct")
	_check(_count(history, MatchEvent.Type.BALL_HIT) == 0 and _draw_count == 0,
		"Successful dodge must not enter F08 or consume route draws")

## Covers low-speed physical contact and the exact 0.5 route split with explicit inputs.
func _test_low_speed_and_exact_sample_boundary() -> void:
	_match_with_defender(60)
	var contact := BallContactCandidate.new()
	contact.player_id = "target"
	contact.normal = Vector2.LEFT
	var source := BallShotSource.new("shooter", "attack", 80, 1)
	var slow := BallImpactResolver.resolve(contact, source, 1, Vector2(7.9, 0.0),
		_config, _draw)
	_check(not slow.was_knocked_down and slow.route == BallImpactResult.Route.REBOUND,
		"Low speed may contact but cannot trigger attribute knockdown")
	_check(_draw_count == 0, "Low-speed contact must not draw")
	var threshold := BallImpactResolver.resolve(contact, source, 60, Vector2(8.0, 0.0),
		_config, _draw)
	_check(threshold.was_knocked_down, "The configured high-speed threshold is inclusive")
	_sample = 0.5
	var split := BallImpactResolver.resolve(contact, source, 60, Vector2(20.0, 0.0),
		_config, _draw)
	_check(split.was_knocked_down and split.route == BallImpactResult.Route.REBOUND,
		"Exactly 0.5 must select rebound")
	_check(split.velocity_after_mps.length() <= split.velocity_before_mps.length(),
		"Rebound cannot create speed")

## Prevents post-boundary F08 and keeps goalkeeper contacts on a separate future F04 route.
func _test_boundary_before_player_and_keeper_route() -> void:
	var after := _match_with_defender(1, 0.1, false, 3.0)
	_launch(after)
	after.advance_fixed_step(0.5, [])
	_check(_count(after.get_event_history(), MatchEvent.Type.BALL_CONTACT) == 0,
		"Whole-ball crossing must stop subsequent player contacts")
	_check(_count(after.get_event_history(), MatchEvent.Type.GOAL_SCORED) == 1,
		"The first crossing must score once")
	var keeper := _match_with_defender(1, 0.1, false, -2.0, true)
	_launch(keeper)
	keeper.advance_fixed_step(0.5, [])
	_check(_count(keeper.get_event_history(), MatchEvent.Type.GOALKEEPER_CONTACT) == 1,
		"Goalkeeper must retain a distinct candidate route")
	_check(_count(keeper.get_event_history(), MatchEvent.Type.PLAYER_KNOCKED_DOWN) == 0,
		"F08 must not substitute for goalkeeper saves")
	_check(_draw_count == 0, "Reserved goalkeeper route must not draw F08 randomness")

## Recomputes after each collision and permits reentry only after actual separation.
func _test_chain_and_continuous_deduplication() -> void:
	var simulation := _match_with_defender(60)
	var half := _field.length_m * 0.5
	# Install the second explicit defender before the READY match starts.
	var chain := MatchSimulation.new(7, _config, _field,
		MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN, _draw)
	chain.register_player("shooter", Vector2(half - 8.0, 0.0), 5.0, "attack", 80)
	chain.register_player("a", Vector2(half - 5.0, 0.0), 5.0, "defense", 1, 60)
	chain.register_player("b", Vector2(half - 2.0, 0.0), 5.0, "defense", 1, 60)
	chain.register_team_attacking_goal("attack", Vector2(half, 0.0))
	chain.register_ball(Vector2(half - 7.45, 0.0))
	chain.start_match()
	chain.advance_fixed_step(0.01, [])
	_launch(chain)
	chain.advance_fixed_step(0.6, [])
	_check(_count(chain.get_event_history(), MatchEvent.Type.BALL_HIT) == 2,
		"Continued shot must resolve two defenders in order")
	_check(_draw_count == 2, "Each distinct knockdown must draw once")
	# Use a slow-decay explicit context to bounce between two still-standing targets.
	simulation = _match_with_defender(90)
	# Keep this collision-only case above its control limit so ordinary reception cannot end it.
	simulation._ball_runtime_system._ball_control_max_speed_mps = 0.1
	_config._shot_ground_deceleration_mps2 = 0.2
	var near := simulation._player_runtime_system.get_player("defender")
	near.state._set_position(Vector2(2.0, 0.0))
	var shooter := simulation._player_runtime_system.get_player("shooter")
	shooter.state_machine.reset_to_spawn(Vector2.ZERO)
	simulation._ball_runtime_system.reset_ball(Vector2(0.55, 0.0))
	simulation._player_runtime_system.register_player("back", Vector2(-2.0, 0.0),
		5.0, "defense", 1, 90)
	simulation.advance_fixed_step(0.01, [])
	simulation._attacking_goals_by_team["attack"] = Vector2(half, 0.0)
	_launch(simulation)
	simulation.advance_fixed_step(0.8, [])
	var targets: Array[String] = []
	for event in simulation.get_event_history():
		if event.event_type == MatchEvent.Type.BALL_HIT:
			targets.append(event.target_player_id)
	_check(targets.size() >= 3 and targets[0] == "defender" and targets[1] == "back"
		and targets[2] == "defender", "Fully separated ball must be able to hit the first body again")

## Confirms snapshots and event readers do not consume the seeded route stream.
func _test_seeded_replay() -> void:
	var traces: Array[String] = []
	for replay in range(2):
		var base := _match_with_defender(60)
		base._ball_route_sampler = base._sample_ball_route
		_launch(base)
		var trace := ""
		for step in range(120):
			if replay == 1:
				base.create_snapshot()
				base.get_event_history()
			for event in base.advance_fixed_step(1.0 / 60.0, []):
				trace += "%s:%s;" % [event.event_type, event.subject_id]
				if event.ball_impact != null:
					trace += str(event.ball_impact.route_sample)
		traces.append(trace)
	_check(traces[0] == traces[1], "Same seed and commands must replay identical impact facts")

## Confirms airborne kicks and direct headers enter the same locked-source impact pipeline.
func _test_airborne_and_header_sources() -> void:
	var airborne := _match_with_defender(60)
	airborne.advance_fixed_step(0.2, [MatchAction.new("shooter", MatchAction.Type.JUMP)])
	_launch(airborne)
	airborne.advance_fixed_step(0.3, [])
	var hit_above_ground := false
	for event in airborne.get_event_history():
		if event.event_type == MatchEvent.Type.BALL_HIT:
			hit_above_ground = event.ball_impact.height_m > 0.0
	_check(hit_above_ground, "Airborne shots must enter the same height-aware impact path")
	var header := MatchSimulation.new(47, _config, null,
		MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN, _draw)
	header.register_player("passer", Vector2.ZERO, 5.0, "blue", 50)
	header.register_player("receiver", Vector2(10.0, 0.0), 5.0, "blue", 50)
	header.register_player("header", Vector2(3.8, 0.0), 5.0, "red", 80)
	header.register_player("target", Vector2(7.0, 0.0), 5.0, "blue", 1, 60)
	header.register_team_attacking_goal("red", Vector2(25.0, 0.0))
	header.register_ball(Vector2(0.55, 0.0))
	header.start_match()
	header.advance_fixed_step(0.01, [])
	header.advance_fixed_step(0.19, [MatchAction.new("passer", MatchAction.Type.PASS,
		Vector2.ZERO, "receiver")])
	header.advance_fixed_step(0.01, [])
	header.advance_fixed_step(0.05, [MatchAction.new("header", MatchAction.Type.HEADER_SHOT)])
	for step in range(30):
		header.advance_fixed_step(0.02, [])
	var header_hit := false
	for event in header.get_event_history():
		if event.event_type == MatchEvent.Type.BALL_HIT:
			header_hit = (event.ball_impact.source.player_id == "header"
				and event.ball_impact.source.shooting == 80)
	_check(header_hit, "Header attack must lock the header player's source, not the passer")


## Checks that both ball responses push the victim forward through one bounded hop.
func _test_knockback_follows_incoming_ball_and_lands() -> void:
	for scenario in [Vector2(60, 0.1), Vector2(60, 0.9), Vector2(80, 0.9)]:
		var simulation := _match_with_defender(int(scenario.x), scenario.y)
		simulation._match_rules = null # Isolate the hop duration from automatic goal resets.
		_launch(simulation)
		for step in range(60):
			simulation.advance_fixed_step(1.0 / 60.0, [])
			if _count(simulation.get_event_history(), MatchEvent.Type.PLAYER_KNOCKED_DOWN) > 0:
				break
		var initial := simulation.create_snapshot().get_player("defender").position_m
		simulation.advance_fixed_step(_config.ball_impact_knockback_duration_seconds * 0.5, [])
		var raised := simulation.create_snapshot().get_player("defender")
		_check(is_equal_approx(raised.height_m, _config.ball_impact_knockback_apex_height_m),
			"Victim must reach the configured hop apex halfway through the response")
		_check(is_equal_approx(raised.position_m.x - initial.x,
			_config.ball_impact_knockback_distance_m * 0.5),
			"Victim must move along the incoming direction even when the ball rebounds")
		_check(raised.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN
			and raised.jump_phase == PlayerMatchState.JumpPhase.NONE,
			"Forced hop must not grant deliberate jump or action eligibility")
		simulation.advance_fixed_step(_config.ball_impact_knockback_duration_seconds * 0.5, [])
		var landed := simulation.create_snapshot().get_player("defender")
		_check(is_zero_approx(landed.height_m), "Forced hop must finish exactly on the ground")
		_check(is_equal_approx(landed.position_m.x - initial.x,
			_config.ball_impact_knockback_distance_m), "Knockback must finish at its configured distance")
		simulation.advance_fixed_step(0.1, [])
		_check(simulation.create_snapshot().get_player("defender").position_m
			.is_equal_approx(landed.position_m), "Finished knockback must stop without drifting")


## Verifies configurable diagonal motion, bounded large steps and reset during the hop.
func _test_custom_knockback_and_reset() -> void:
	_match_with_defender(60)
	var state := PlayerMatchState.new("victim", Vector2.ZERO)
	var machine := PlayerStateMachine.new(state)
	_check(machine.start_knockdown(_config), "Victim must enter knockdown")
	_check(machine.start_knockback(Vector2(1.0, 1.0), 1.5, 0.4, 0.4),
		"Explicit football response parameters must be accepted")
	machine.advance(0.2)
	_check(is_equal_approx(state.height_m, 0.4), "Custom height must be used")
	_check(state.position_m.is_equal_approx(Vector2.ONE.normalized() * 0.75),
		"Diagonal knockback must use the normalized incoming direction")
	_check(not machine.set_movement_input(Vector2.LEFT), "Knocked-down victim cannot move voluntarily")
	machine.reset_to_spawn(Vector2.ZERO)
	machine.advance(0.3)
	_check(state.position_m.is_zero_approx() and is_zero_approx(state.height_m),
		"Reset during a hop must clear all residual height and knockback")
	machine.start_knockdown(_config)
	machine.start_knockback(Vector2.RIGHT, 1.5, 0.4, 0.4)
	machine.advance(0.6)
	_check(is_equal_approx(state.position_m.x, 1.5) and is_zero_approx(state.height_m),
		"A large step must finish the response without overshooting or leaving the victim floating")


## Builds a legal owned-ball match with one configurable defender and injected F07/route results.
func _match_with_defender(strength: int, sample: float = 0.1, dodge: bool = false,
		x_from_goal: float = -2.0, keeper: bool = false) -> MatchSimulation:
	var repository := DataRepository.new()
	_check(repository.load_all(), "Fixture data must load")
	_config = repository.get_match_config_by_id("demo_match")
	_field = repository.get_field_by_id("demo_field")
	_draw_count = 0
	_sample = sample
	var simulation := MatchSimulation.new(73, _config, _field,
		MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN, _draw,
		func(_id: String) -> bool: return dodge)
	var half := _field.length_m * 0.5
	simulation.register_player("shooter", Vector2(half - 6.0, 0.0), 5.0, "attack", 80)
	simulation.register_player("defender", Vector2(half + x_from_goal, 0.0),
		5.0, "defense", 1, strength, 50, keeper)
	simulation.register_team_attacking_goal("attack", Vector2(half, 0.0))
	simulation.register_ball(Vector2(half - 5.45, 0.0))
	simulation.start_match()
	simulation.advance_fixed_step(0.01, [])
	return simulation

## Releases through the ordinary action protocol and configured kick frame.
func _launch(simulation: MatchSimulation) -> void:
	simulation.advance_fixed_step(0.19, [MatchAction.new("shooter", MatchAction.Type.SHOOT)])
	simulation.advance_fixed_step(0.01, [])

## Counts only route draws actually requested by F08.
func _draw() -> float:
	_draw_count += 1
	return _sample

## Finds the first event index, using a large missing sentinel for useful ordering failures.
func _index(events: Array[MatchEvent], type: int) -> int:
	for index in range(events.size()):
		if events[index].event_type == type:
			return index
	return 1000000

## Counts committed facts without reading or advancing the random source.
func _count(events: Array[MatchEvent], type: int) -> int:
	var count := 0
	for event in events:
		if event.event_type == type:
			count += 1
	return count

## Collects independent failures without depending on rendered output.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
