## Verifies public values, single binding, bounded evaluation and unchanged fallback selection.
extends SceneTree

const Fixture = preload("res://tests/support/ai_fixture.gd")
var _failures: PackedStringArray = []


class Probe extends PlayerAIDecisionStrategy:
	var calls := 0
	var view: Dictionary
	var result: Dictionary

	## Captures a detached public view and returns the fixture's configured choice.
	func decide(input: Dictionary) -> Dictionary:
		calls += 1
		view = input
		return result


class TeamProbe extends PlayerAIDecisionStrategy:
	var seen: Dictionary[String, Dictionary] = {}
	var fail_id := ""

	func interface_version() -> int:
		return 2

	## Observes each independently copied view and fails one player on purpose.
	func decide(view: Dictionary) -> Dictionary:
		var id: String = view["self"]["id"]
		seen[id] = view
		if id == fail_id:
			return {"behavior": "chase", "target": ""}
		return {}


## Exercises real candidates and source scheduling without a renderer.
func _init() -> void:
	_test_binding_and_schedule()
	_test_public_contract_and_fallback()
	_test_compiler_and_budget()
	_test_team_binding()
	_test_no_header_contract()
	for failure in _failures:
		push_error(failure)
	print("Scripted AI failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)


## Restricts the strategy to one forward, respecting same-step cache and action phase gates.
func _test_binding_and_schedule() -> void:
	var f := Fixture.new()
	var carrier := f.player("swift_forward", Vector2(12, 0))
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	var defender := f.player("formal_player_04", Vector2(20, 0), "away")
	var ball := BallMatchState.new(carrier.state.position_m)
	ball._set_owner(carrier.player_id)
	var probe := Probe.new()
	probe.result = {"behavior": "dribble", "target": ""}
	var source := MatchPlayerAISource.new(f.formal.teams, f.formal.field, f.rules, f.tuning,
		null, null, 1.0 / 60.0, null, carrier.player_id, probe)
	var snapshot := f.snapshot([carrier, defender], ball)
	source.propose_actions(snapshot)
	_check(probe.calls == 1 and source.get_plan(carrier.player_id).action_type == MatchAction.Type.MOVE,
		"Only the bound forward invokes the strategy")
	_check(source.get_plan(defender.player_id) != null, "The other player still receives a built-in plan")
	source.propose_actions(snapshot)
	source.propose_actions(f.snapshot([carrier, defender], ball, "", 1, false, 1))
	_check(probe.calls == 1, "A repeated snapshot and an active movement plan do not call the strategy again")
	var paused := MatchStateSnapshot.new(MatchState.Phase.PAUSED, 0.0, 2, 42, snapshot.players, snapshot.ball)
	_check(source.propose_actions(paused).is_empty() and probe.calls == 1, "Pause cannot invoke the strategy")
	source.invalidate_control(snapshot)
	source.propose_actions(f.snapshot([carrier, defender], ball, "", 2, false, 3))
	_check(probe.calls == 2, "A cleared plan permits one decision on the next eligible step")
	var invalid := MatchPlayerAISource.new(f.formal.teams, f.formal.field, f.rules, f.tuning,
		null, null, 1.0 / 60.0, null, defender.player_id, probe)
	_check(not invalid.errors.is_empty(), "A defender cannot bind a player script")


## Mirrors both attack directions and verifies that invalid responses consume only the fallback draws.
func _test_public_contract_and_fallback() -> void:
	var f := Fixture.new()
	for side: float in [-1.0, 1.0]:
		var player := f.player("carrier", Vector2(18.0 * side, 0))
		player.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
		var mate := f.player("mate", Vector2(20.0 * side, 2))
		var ball := BallMatchState.new(player.state.position_m)
		ball._set_owner(player.player_id)
		var snapshot := f.snapshot([player, mate], ball)
		var goal := Vector2(side * 25.0, 0)
		var choices := RoleCandidateBuilder.new(f.tuning, f.rules, f.formal.field).build(
			snapshot, player.player_id, "forward", Vector2.ZERO, goal, "", false)
		var built_in := PlayerAI.new(42, player.player_id)
		var expected := built_in.choose(snapshot, player.player_id, choices, f.rules)
		var probe := Probe.new()
		probe.result = {"behavior": "pass", "target": "missing"}
		var scripted := PlayerAI.new(42, player.player_id)
		var actual := scripted.choose(snapshot, player.player_id, choices, f.rules, probe, goal, false)
		_check(actual.action_type == expected.action_type and actual.target_player_id == expected.target_player_id
			and scripted.random_draws == built_in.random_draws and not scripted.strategy_error.is_empty(),
			"Invalid target falls back with exactly the built-in draw sequence")
		_check(probe.view["self"]["x"] == 18.0 and probe.view["self"]["goal_distance_m"] == 7.0
			and probe.view["teammates"][0]["x"] == 20.0, "Public coordinates mirror both directions")
		probe.result = {"behavior": "pass", "target": "first"}
		var draws := scripted.random_draws
		actual = scripted.choose(snapshot, player.player_id, choices, f.rules, probe, goal)
		_check(actual.action_type == MatchAction.Type.PASS and actual.target_player_id == mate.player_id
			and scripted.random_draws == draws, "Direct choice resolves a legal target without sampling")
		probe.result = {"weights": {"dribble": 0, "pass": 0}}
		actual = scripted.choose(snapshot, player.player_id, choices, f.rules, probe, goal)
		_check(actual.action_type == MatchAction.Type.SHOOT, "Weights keep the existing legal category lottery")


## Validates parse, version, static names, memory caps and the separate runtime budget.
func _test_compiler_and_budget() -> void:
	for source: String in ["{", '{"version":3,"rules":[],"default":{}}',
			'{"version":1,"rules":[{"when":[["os.time",">",0]],"then":{}}],"default":{}}',
			'{"version":1,"rules":[],"default":{"weights":{"shoot":-1}}}', " ".repeat(8193),
			"[".repeat(9) + "]".repeat(9)]:
		_check(PlayerAIScript.compile(source).has("error"), "Invalid script is rejected during submission")
	var rules: Array[Dictionary] = []
	for index in range(17):
		var conditions: Array = []
		for item in range(7):
			conditions.append(["self.owns_ball", "==", true])
		conditions.append(["self.owns_ball", "==", false])
		rules.append({"when": conditions, "then": {}})
	var compiled := PlayerAIScript.compile(JSON.stringify({"version": 1, "rules": rules, "default": {}}))
	_check(compiled.has("script"), "Well-formed bounded source compiles before budget evaluation")
	if compiled.has("script"):
		_check(compiled["script"].decide({"version": 1, "self": {"owns_ball": true}}).has("error"),
			"Runtime comparison budget aborts execution")


## Confirms all six players get their own context while a keeper's illegal pursuit falls back safely.
func _test_team_binding() -> void:
	var f := Fixture.new()
	var simulation := f.formal.create(3.0)
	var ball := simulation._ball_runtime_system
	ball.reset_ball(Vector2(-18, 0))
	simulation.start_match()
	var snapshot := simulation.create_snapshot()
	var probe := TeamProbe.new()
	probe.fail_id = "steady_keeper"
	var regions := f.formal.data.load_activity_regions()
	var source := MatchPlayerAISource.new(f.formal.teams, f.formal.field, f.rules, f.tuning,
		null, null, 1.0 / 60.0, regions, "", probe, "home")
	source.propose_actions(snapshot)
	var roles := {}
	for id in probe.seen:
		var view: Dictionary = probe.seen[id]
		roles[view["self"]["role"]] = true
		_check(snapshot.get_player(id).team_id == "home", "Only the selected team runs the shared program")
		_check(view["version"] == 2 and view["ball"]["relation"] == "none"
			and view["ball"]["source"] == "none" and view["phase"] == "loose",
			"Team context reports current role, phase, ownership and source")
	_check(probe.seen.size() == 6 and roles.size() == 4, "All six teammates independently invoke one strategy across four roles")
	var errors := source.get_strategy_errors()
	_check(errors.size() == 1 and errors.has("steady_keeper"), "Illegal keeper choice only marks the keeper's decision")
	var keeper_view: Dictionary = probe.seen.get("steady_keeper", {})
	_check(not keeper_view.is_empty() and not keeper_view["candidates"].has("chase")
		and keeper_view["self"]["duty"] == "goalkeeper", "Keeper context only exposes goal-mouth movement")
	var keeper_plan: PlayerAIPlan = source._plans.get("steady_keeper")
	_check(keeper_plan != null and keeper_plan.behavior != AIActionCandidate.Behavior.CHASE
		and absf(keeper_plan.target_m.x + 24.2) <= 0.25,
		"Fallback never sends the scripted keeper after a loose ball")
	var version_error := PlayerAIScript.compile('{"version":1,"rules":[{"when":[["self.role","==","mid"]],"then":{}}],"default":{}}')
	_check(version_error.has("error"), "v2 fields cannot leak into the v1 contract")
	var target_rule := PlayerAIScript.compile('{"version":2,"rules":[{"when":[["has_target.pass.mate","==",true]],"then":{"behavior":"pass","target":"mate"}}],"default":{}}')
	_check(target_rule.has("script") and target_rule["script"].decide(
		{"version": 2, "candidates": {"pass": {"targets": [{"id": "mate"}]}}}).get("target") == "mate",
		"Exact target availability is evaluated from the current candidate list")


## Confirms the current version keeps headers out of the public v2 contract.
func _test_no_header_contract() -> void:
	var behaviors := ScriptedAIContract.behaviors(2)
	_check(not behaviors.has("header_shot") and not behaviors.has("header_clear"),
		"v2 contract must not expose header behaviors")
	for source in [
		'{"version":2,"rules":[{"when":[["has.header_clear","==",true]],"then":{}}],"default":{}}',
		'{"version":2,"rules":[{"when":[["self.id","==","formal_player_02"]],"then":{"behavior":"header_clear","target":""}}],"default":{}}',
	]:
		_check(PlayerAIScript.compile(source).has("error"),
			"Header conditions and behaviors must be rejected at submission")


## Reports independent contract failures together.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)