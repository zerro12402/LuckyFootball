extends SceneTree

var _failures: PackedStringArray = []


func _init() -> void:
	test_new_runtime_when_created_reads_state_from_state_machine()
	test_runtime_system_when_registering_player_owns_single_runtime()
	test_runtime_system_when_listing_players_uses_stable_id_order()

	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func test_new_runtime_when_created_reads_state_from_state_machine() -> void:
	var runtime := PlayerRuntime.new("test_player", Vector2(3.0, -2.0))
	_expect(
		runtime.state == runtime.state_machine.state,
		"Expected runtime state to come from its state machine",
	)
	_expect(runtime.player_id == "test_player", "Expected runtime player ID")
	_expect(
		runtime.state.position_m == Vector2(3.0, -2.0),
		"Expected state machine to own the initial position",
	)


func test_runtime_system_when_registering_player_owns_single_runtime() -> void:
	var runtime_system := PlayerRuntimeSystem.new()
	_expect(
		runtime_system.register_player("test_player", Vector2.ZERO),
		"Expected first player registration to succeed",
	)
	_expect(
		not runtime_system.register_player("test_player", Vector2.ONE),
		"Expected duplicate player registration to fail",
	)
	var runtime := runtime_system.get_player("test_player")
	_expect(runtime != null, "Expected registered runtime lookup")
	_expect(
		runtime_system.get_players().size() == 1,
		"Expected only one registered runtime",
	)


func test_runtime_system_when_listing_players_uses_stable_id_order() -> void:
	var runtime_system := PlayerRuntimeSystem.new()
	runtime_system.register_player("player_b", Vector2.ZERO)
	runtime_system.register_player("player_a", Vector2.ZERO)
	var players := runtime_system.get_players()
	_expect(players.size() == 2, "Expected two player runtimes")
	if players.size() != 2:
		return
	_expect(players[0].player_id == "player_a", "Expected sorted first player")
	_expect(players[1].player_id == "player_b", "Expected sorted second player")


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
