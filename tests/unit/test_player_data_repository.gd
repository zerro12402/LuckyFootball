## Validates typed player data, readonly traits and transactional CSV failure reporting.
extends SceneTree

var _failures: PackedStringArray = []


## Runs all static-data contracts without scene or runtime dependencies.
func _init() -> void:
	test_valid_csv_when_loaded_returns_typed_players()
	test_boundary_values_when_loaded_are_accepted()
	test_loaded_traits_when_modified_do_not_change_definition()
	test_missing_csv_when_loaded_returns_failure()
	test_invalid_header_when_loaded_returns_failure()
	test_duplicate_player_id_when_loaded_returns_failure()
	test_out_of_range_attribute_when_loaded_returns_failure()
	test_too_few_traits_when_loaded_returns_failure()
	test_duplicate_traits_when_loaded_returns_failure()
	test_data_repository_when_loaded_indexes_players_by_id()

	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## Verifies valid csv when loaded returns typed players using explicit CSV input.
func test_valid_csv_when_loaded_returns_typed_players() -> void:
	var result := PlayerDataRepository.new().load_from_csv(
		"res://resources/data/players.csv"
	)
	_expect(result.is_success, "Expected valid players.csv to load")
	_expect(result.errors.is_empty(), "Expected valid players.csv to have no errors")
	_expect(result.players.size() == 12, "Expected twelve roster player definitions")
	if result.players.size() != 12:
		return
	var forward := result.players[0]
	_expect(forward is PlayerDefinition, "Expected a typed PlayerDefinition")
	_expect(forward.player_id == "swift_forward", "Expected the first player_id")
	_expect(forward.display_name == "疾风", "Expected UTF-8 display_name")
	_expect(forward.speed == 92, "Expected the parsed speed")
	_expect(forward.technique == 88, "Expected the parsed technique")
	_expect(forward.trait_ids.size() == 3, "Expected three parsed trait IDs")
	_expect(forward.trait_ids[0] == "speedster", "Expected ordered trait columns")


## Verifies boundary values when loaded are accepted using explicit CSV input.
func test_boundary_values_when_loaded_are_accepted() -> void:
	var result := PlayerDataRepository.new().load_from_csv(
		"res://tests/fixtures/players_boundary_values.csv"
	)
	_expect(result.is_success, "Expected inclusive attribute and trait boundaries to load")
	if not result.is_success or result.players.is_empty():
		return
	var boundary_player := result.players[0]
	_expect(boundary_player.speed == 1, "Expected minimum attribute value 1")
	_expect(boundary_player.shooting == 100, "Expected maximum attribute value 100")
	_expect(boundary_player.technique == 100, "Expected maximum technique value 100")
	_expect(boundary_player.trait_ids.size() == 5, "Expected maximum trait count 5")


## Verifies loaded traits when modified do not change definition using explicit CSV input.
func test_loaded_traits_when_modified_do_not_change_definition() -> void:
	var result := PlayerDataRepository.new().load_from_csv(
		"res://resources/data/players.csv"
	)
	if not result.is_success or result.players.is_empty():
		_expect(false, "Expected a player for the read-only trait test")
		return
	var copied_trait_ids := result.players[0].trait_ids
	copied_trait_ids.append("injected_trait")
	_expect(
		result.players[0].trait_ids.size() == 3,
		"Expected PlayerDefinition trait IDs to be read-only",
	)


## Verifies missing csv when loaded returns failure using explicit CSV input.
func test_missing_csv_when_loaded_returns_failure() -> void:
	var result := PlayerDataRepository.new().load_from_csv(
		"res://tests/fixtures/missing_players.csv"
	)
	_expect(not result.is_success, "Expected a missing CSV to fail")
	_expect(result.players.is_empty(), "Expected no partial data for a missing CSV")


## Verifies invalid header when loaded returns failure using explicit CSV input.
func test_invalid_header_when_loaded_returns_failure() -> void:
	_expect_fixture_failure(
		"players_invalid_header.csv",
		"Expected an invalid header to fail",
	)


## Verifies duplicate player id when loaded returns failure using explicit CSV input.
func test_duplicate_player_id_when_loaded_returns_failure() -> void:
	_expect_fixture_failure(
		"players_duplicate_id.csv",
		"Expected a duplicate player_id to fail",
	)


## Verifies out of range attribute when loaded returns failure using explicit CSV input.
func test_out_of_range_attribute_when_loaded_returns_failure() -> void:
	_expect_fixture_failure(
		"players_invalid_stat.csv",
		"Expected an out-of-range attribute to fail",
	)


## Verifies too few traits when loaded returns failure using explicit CSV input.
func test_too_few_traits_when_loaded_returns_failure() -> void:
	_expect_fixture_failure(
		"players_invalid_traits.csv",
		"Expected an empty required trait column to fail",
	)


## Verifies duplicate traits when loaded returns failure using explicit CSV input.
func test_duplicate_traits_when_loaded_returns_failure() -> void:
	_expect_fixture_failure(
		"players_duplicate_trait.csv",
		"Expected duplicate trait columns to fail",
	)


## Verifies data repository when loaded indexes players by id using explicit CSV input.
func test_data_repository_when_loaded_indexes_players_by_id() -> void:
	var data_repository := DataRepository.new()
	_expect(data_repository.load_all(), "Expected DataRepository to load all tables")
	_expect(
		data_repository.player_definitions.size() == 12,
		"Expected DataRepository to expose twelve players",
	)
	var goalkeeper := data_repository.get_player_by_id("steady_keeper")
	_expect(goalkeeper != null, "Expected player lookup by stable ID")
	if goalkeeper != null:
		_expect(goalkeeper.goalkeeping == 94, "Expected goalkeeper data by stable ID")
	_expect(
		data_repository.get_player_by_id("unknown_player") == null,
		"Expected an unknown player lookup to return null",
	)
	_expect(
		data_repository.field_definitions.size() == 1,
		"Expected DataRepository to expose one field",
	)
	var field := data_repository.get_field_by_id("demo_field")
	_expect(field != null, "Expected field lookup by stable ID")
	if field != null:
		_expect(is_equal_approx(field.length_m, 50.0), "Expected field length")
		_expect(is_equal_approx(field.width_m, 30.0), "Expected field width")


## Requires invalid data to fail without publishing partially parsed players.
func _expect_fixture_failure(file_name: String, failure_message: String) -> void:
	var result := PlayerDataRepository.new().load_from_csv(
		"res://tests/fixtures".path_join(file_name)
	)
	_expect(not result.is_success, failure_message)
	_expect(result.players.is_empty(), "Expected invalid CSV loading to be transactional")
	_expect(not result.errors.is_empty(), "Expected invalid CSV to report errors")


## Collects independent failures rather than aborting on the first invalid CSV case.
func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
