## Exercises F05/F06 boundaries, sample accounting, atomic reactions and ownership without rendering.
extends SceneTree

var _config: MatchConfigDefinition
var _failures: PackedStringArray = []
var _u5: float = 0.99
var _u6: float = 0.0
var _dodge_calls: int = 0
var _strength_calls: int = 0

## Runs isolated formulas and real fixed-step attacks against production configuration.
func _init() -> void:
	var repository := DataRepository.new()
	_check(repository.load_all(), "production data loads")
	_config = repository.get_match_config_by_id("demo_match")
	_formula()
	_config_validation()
	_atomic_reactions()
	_sampling_lifecycle()
	_dodge_flip()
	_replay()
	for failure in _failures:
		push_error(failure)
	print("Melee contest failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Counts only actual F05 draws, separately from F06 and other systems.
func _draw_dodge() -> float:
	_dodge_calls += 1
	return _u5

## Counts only threshold-interior F06 draws.
func _draw_strength() -> float:
	_strength_calls += 1
	return _u6

## Resolves a pure contest after resetting instrumentation.
func _resolve(attack: int, defense: int, technique: int = 50) -> MeleeContestResult:
	_dodge_calls = 0
	_strength_calls = 0
	return MeleeContestResolver.resolve(7, "a", "b", attack, defense, technique,
		Vector2(1, 0), Vector2.RIGHT, _config, _draw_dodge, _draw_strength)

## Checks known probability values, both equality branches, all strength gaps and swapped identities.
func _formula() -> void:
	_check(is_equal_approx(MeleeContestResolver.dodge_probability(60, 60, _config), 0.247663801139), "same attribute dodge is 24.766 percent")
	_check(is_equal_approx(MeleeContestResolver.dodge_probability(60, 80, _config), 0.5), "twenty technique advantage is 50 percent")
	_check(is_equal_approx(MeleeContestResolver.dodge_probability(100, 1, _config), 0.1), "dodge lower bound")
	_check(is_equal_approx(MeleeContestResolver.dodge_probability(1, 100, _config), 0.9), "dodge upper bound")
	_u5 = 0.5 - 0.000001
	var result := _resolve(60, 65, 80)
	_check(result.outcome == MeleeContestResult.Outcome.DODGED and not result.has_strength_result, "F05 below threshold dodges with no F06 result")
	_check(_dodge_calls == 1 and _strength_calls == 0 and result.strength_sample == -1, "dodge consumes exactly one sample")
	_u5 = 0.5
	result = _resolve(60, 60, 80)
	_check(result.outcome == MeleeContestResult.Outcome.DRAW and result.did_hit, "F05 threshold equality hits")
	_check(_dodge_calls == 1 and _strength_calls == 0, "equal strength does not sample F06")
	_u5 = 0.99
	for gap: int in [0, 1, 5, 10, 15, 19, 20, 21]:
		for swap: bool in [false, true]:
			var attack := 50 if swap else 50 + gap
			var defense := 50 + gap if swap else 50
			_u6 = 0.0
			result = _resolve(attack, defense)
			var expected := MeleeContestResult.Outcome.DRAW if gap == 0 else (MeleeContestResult.Outcome.TARGET_WIN if swap else MeleeContestResult.Outcome.ATTACKER_WIN)
			_check(result.outcome == expected, "stronger identity wins, weaker never wins: %d/%s" % [gap, swap])
			_check(_dodge_calls == 1 and _strength_calls == (1 if gap > 0 and gap < 20 else 0), "exact phase sample counts")
			_check(is_equal_approx(result.stronger_win_probability, minf(gap / 20.0, 1.0)), "linear conditional win probability")
			if gap > 0 and gap < 20:
				_u6 = gap / 20.0
				result = _resolve(attack, defense)
				_check(result.outcome == MeleeContestResult.Outcome.DRAW, "F06 threshold equality draws")
				_u6 = 0.999
				_check(_resolve(attack, defense).outcome == MeleeContestResult.Outcome.DRAW, "interior failure draws, never weaker wins")

## Rejects nonfinite/range/fractional settings while preserving legacy optional defaults.
func _config_validation() -> void:
	var text := FileAccess.get_file_as_string("res://resources/data/match_configs.csv")
	for pair in [["melee_dodge_attack_advantage,20.0", "melee_dodge_attack_advantage,-1"],
		["melee_dodge_probability_scale,18.0", "melee_dodge_probability_scale,0"],
		["melee_dodge_probability_min,0.1", "melee_dodge_probability_min,-0.1"],
		["melee_dodge_probability_max,0.9", "melee_dodge_probability_max,1.1"],
		["melee_dodge_probability_min,0.1", "melee_dodge_probability_min,0.95"],
		["melee_strength_auto_win_gap,20", "melee_strength_auto_win_gap,0"],
		["melee_strength_auto_win_gap,20", "melee_strength_auto_win_gap,1.5"],
		["melee_strength_auto_win_gap,20", "melee_strength_auto_win_gap,NaN"],
		["melee_dodge_probability_scale,18.0", "melee_dodge_probability_scale,inf"]]:
		var changed := text.replace(pair[0], pair[1])
		_check(changed != text, "config fixture replaces a real key")
		var file := FileAccess.open("user://invalid_melee.csv", FileAccess.WRITE)
		file.store_string(changed)
		file.close()
		_check(not MatchConfigDataRepository.new().load_from_csv("user://invalid_melee.csv").is_success, "invalid melee config rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://invalid_melee.csv"))

## Creates real runtime actors; seeded runs use production RNG, isolated runs inject both stages.
func _match(attack: int = 80, defense: int = 80, technique: int = 60,
		position: Vector2 = Vector2(1.05, 0), carrier: bool = true,
		seed_value: int = 17, injected: bool = true) -> MatchSimulation:
	_dodge_calls = 0
	_strength_calls = 0
	var simulation := MatchSimulation.new(seed_value, _config, null, MatchSimulation.MeleeOutcome.FORMULA,
		Callable(), Callable(), Callable(), Callable(), Callable(), Callable(), Callable(), Callable(), -1,
		_draw_dodge if injected else Callable(), _draw_strength if injected else Callable())
	simulation.register_player("a", Vector2.ZERO, 5, "home", 80, attack)
	simulation.register_player("b", position, 5, "away", 80, defense, technique)
	simulation.register_ball(position if carrier else Vector2(15, 8))
	simulation.start_match()
	simulation.advance_fixed_step(0.01, [])
	return simulation

## Issues the same normal command used by keyboard and AI adapters.
func _attack(simulation: MatchSimulation) -> MeleeContestResult:
	for event in simulation.advance_fixed_step(0.01, [MatchAction.new("a", MatchAction.Type.ATTACK, Vector2.ZERO, "b")]):
		if event.event_type == MatchEvent.Type.MELEE_CONTEST_RESOLVED:
			return event.melee_contest
	return null

## Verifies three outcomes, both directions, ball drop point and absence of automatic possession transfer.
func _atomic_reactions() -> void:
	_u5 = 0.99
	_u6 = 0.0
	for pair in [[80, 60], [60, 80], [80, 80]]:
		for reverse: bool in [false, true]:
			var direction := Vector2.LEFT if reverse else Vector2.RIGHT
			var simulation := _match(pair[0], pair[1], 60, direction * 1.05)
			if reverse:
				simulation.advance_fixed_step(0.01, [MatchAction.new("a", MatchAction.Type.MOVE, Vector2.LEFT), MatchAction.new("a", MatchAction.Type.MOVE, Vector2.ZERO)])
			var a_before := simulation.create_snapshot().get_player("a").position_m
			var result := _attack(simulation)
			_check(result != null, "legal contact resolves")
			if result == null:
				continue
			var snapshot := simulation.create_snapshot()
			var attacker := snapshot.get_player("a")
			var target := snapshot.get_player("b")
			var a_start := a_before
			var b_start := result.contact_position_m
			var a_falls: bool = pair[0] <= pair[1]
			var b_falls: bool = pair[0] >= pair[1]
			_check((attacker.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN) == a_falls, "attacker state commits atomically")
			_check((target.action_state == PlayerMatchState.ActionState.KNOCKED_DOWN) == b_falls, "target state commits atomically")
			_check(snapshot.ball.owner_player_id == ("" if b_falls else "b"), "loser/draw drops; winning target retains possession")
			if b_falls:
				_check(snapshot.ball.position_m.is_equal_approx(result.contact_position_m), "ball drops once at pre-displacement contact point")
			_check(result.direction.is_equal_approx(direction), "contact direction mirrors correctly")
			for step in range(7):
				simulation.advance_fixed_step(0.1, [])
			snapshot = simulation.create_snapshot()
			if a_falls:
				_check(snapshot.get_player("a").position_m.is_equal_approx(a_start - direction * _config.knockdown_knockback_distance_m), "attacker knocked back exactly once opposite attack")
			if b_falls:
				_check(snapshot.get_player("b").position_m.is_equal_approx(b_start + direction * _config.knockdown_knockback_distance_m), "target knocked back exactly once along attack")
			var count := 0
			for event in simulation.get_event_history():
				if event.event_type == MatchEvent.Type.MELEE_CONTEST_RESOLVED:
					count += 1
			_check(count == 1 and _dodge_calls == 1, "no repeated result or sample during contact window")
	var unowned := _match(80, 80, 60, Vector2(1.05, 0), false)
	_check(_attack(unowned) != null and unowned.create_snapshot().ball.owner_player_id.is_empty(), "unowned target produces no ownership")
	# Start exactly one lunge-step away from overlap so contact uses the captured attack direction.
	var overlap := _match(80, 80, 60, Vector2(0.05, 0), false)
	var result := _attack(overlap)
	_check(result != null and result.direction == Vector2.RIGHT, "overlap uses initial attack direction")

## Covers no contact, invalid attributes/targets, pause, reset, dodge retention and carrier attack release.
func _sampling_lifecycle() -> void:
	_u5 = 0.0
	var dodged := _match(60, 80, 80)
	_check(_attack(dodged).outcome == MeleeContestResult.Outcome.DODGED, "legal dodge")
	_check(dodged.create_snapshot().ball.owner_player_id == "b" and _strength_calls == 0, "dodge retains ball and skips F06")
	for step in range(30):
		dodged.advance_fixed_step(0.02, [])
	_check(_dodge_calls == 1, "dodge intent consumed once")
	var distant := _match(80, 80, 60, Vector2(10, 0))
	_attack(distant)
	distant.pause_match()
	distant.advance_fixed_step(1.0, [])
	_check(_dodge_calls == 0 and _strength_calls == 0, "no contact and paused steps consume no samples")
	distant.resume_match()
	distant.advance_fixed_step(0.01, [MatchAction.new("", MatchAction.Type.RESET_ROUND)])
	for step in range(50):
		distant.advance_fixed_step(0.02, [])
	_check(_dodge_calls == 0 and distant._pending_knockdown_targets.is_empty() and distant._pending_melee_sequences.is_empty(), "reset cancels pending intent and sample sequence")
	var expired := _match(80, 80, 60, Vector2(10, 0))
	_attack(expired)
	for step in range(60):
		expired.advance_fixed_step(0.02, [])
	_check(_dodge_calls == 0 and _strength_calls == 0 and expired._pending_melee_sequences.is_empty(), "expired window misses without drawing")
	var blocked := _match()
	blocked._player_runtime_system.get_player("b").state_machine.start_knockdown(_config)
	_check(_attack(blocked) == null and _dodge_calls == 0, "ineligible target never draws")
	var base_config := _config
	var delayed := MatchConfigDataRepository.new().load_from_csv("res://tests/fixtures/match_configs_hit_window_delayed.csv")
	_check(delayed.is_success, "delayed-window fixture loads")
	if delayed.is_success:
		_config = delayed.configs[0]
		var early := _match()
		_check(_attack(early) == null and _dodge_calls == 0, "early contact before active window draws nothing")
		_config = base_config
	var invalid := _match(0, 80, 60)
	_check(_attack(invalid) == null and _dodge_calls == 0, "unbound base attribute rejected before sampling")
	var carrier := _match(80, 80, 60, Vector2(2, 0), false)
	carrier._ball_runtime_system.reset_ball(Vector2.ZERO)
	carrier.advance_fixed_step(0.01, [])
	_check(carrier.create_snapshot().ball.owner_player_id == "a", "carrier fixture acquired ball")
	_attack(carrier)
	_check(carrier.create_snapshot().ball.owner_player_id.is_empty(), "carrier still drops ball when initiating attack")

## A successful F05 uses the existing flip for owned and unowned targets without redrawing or restarting.
func _dodge_flip() -> void:
	_u5 = 0.0
	for owned: bool in [false, true]:
		var simulation := _match(60, 80, 80, Vector2(1.05, 0), owned)
		var result := _attack(simulation)
		_check(result != null and result.outcome == MeleeContestResult.Outcome.DODGED, "F05 flip fixture actually dodges")
		var snapshot := simulation.create_snapshot()
		_check(snapshot.get_player("b").jump_phase == PlayerMatchState.JumpPhase.TAKEOFF, "successful dodge starts the existing flip")
		_check(snapshot.ball.owner_player_id == ("b" if owned else ""), "flip preserves possession including unowned targets")
		simulation.advance_fixed_step(_config.jump_takeoff_seconds, [])
		snapshot = simulation.create_snapshot()
		_check(snapshot.get_player("b").jump_phase == PlayerMatchState.JumpPhase.AIRBORNE and snapshot.get_player("b").height_m > 0.0, "flip advances into actual airborne state")
		for step in range(150):
			simulation.advance_fixed_step(0.01, [])
		_check(_dodge_calls == 1 and _strength_calls == 0, "flip never redraws F05 or enters F06")
		_check(simulation.create_snapshot().get_player("b").jump_phase == PlayerMatchState.JumpPhase.NONE, "flip returns to ground without restarting")
	var busy := _match(60, 80, 80)
	busy._player_runtime_system.get_player("b").state_machine.start_hit_stun(1.0)
	_check(_attack(busy).outcome == MeleeContestResult.Outcome.DODGED, "busy target may still win F05")
	_check(busy.create_snapshot().get_player("b").jump_phase == PlayerMatchState.JumpPhase.NONE, "flip preserves existing action locks like tackle avoidance")

## Compares complete contest facts from same-seed real-RNG runs while snapshots remain read-only.
func _replay() -> void:
	var previous := PackedStringArray()
	for iteration in range(2):
		var simulation := _match(75, 80, 70, Vector2(1.05, 0), true, 123, false)
		var result := _attack(simulation)
		_check(result != null, "seeded contact resolves")
		if result == null:
			continue
		var signature := PackedStringArray([str(result.outcome), str(result.dodge_sample), str(result.strength_sample), str(result.strength_reason)])
		for read in range(5):
			simulation.create_snapshot()
		if iteration == 1:
			_check(signature == previous, "same seed reproduces both phases")
		previous = signature

## Accumulates independent failures for one deterministic test exit.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
