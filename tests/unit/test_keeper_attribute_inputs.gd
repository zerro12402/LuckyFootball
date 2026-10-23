## Verifies manual shot/keeper inputs, real random formulas and validation in the shared mode.
extends SceneTree

var _failures: PackedStringArray = []

## Defers until the ordinary shared scene can be initialized.
func _init() -> void:
	call_deferred("_run")

## Runs all shot sources with explicit attributes and checks immutable release and contact facts.
func _run() -> void:
	var bootstrap := (load("res://scenes/main/game_bootstrap.tscn") as PackedScene).instantiate() as GameBootstrap
	bootstrap.demo_mode = GameBootstrap.DemoMode.GOALKEEPER_TEST
	root.add_child(bootstrap)
	bootstrap.set_process(false)
	var controls := bootstrap.get_node("GoalkeeperControls") as GoalkeeperTestControls
	_check(controls._shooting.text == "84" and controls._goalkeeping.text == "94", "initial inputs reflect current CSV actors")
	var before_csv := FileAccess.get_file_as_string("res://resources/data/players.csv")
	controls._contest.select(1)
	for source in range(3):
		controls._source.select(source)
		for attributes in [Vector2i(80, 70), Vector2i(100, 1), Vector2i(1, 100)]:
			controls._shooting.text = str(attributes.x)
			controls._goalkeeping.text = str(attributes.y)
			controls._shooting.text_submitted.emit(controls._shooting.text)
			bootstrap.set_process(false)
			_check(bootstrap.get_keeper_test_attributes() == attributes, "both inputs bind to actual shot actor and keeper")
			_check(bootstrap.shot_miss_override == -1 and bootstrap.keeper_sample < 0.0, "public inputs never force outcomes")
			var aim: ShotAim
			var save: GoalkeeperSaveResult
			for step in range(160):
				bootstrap._process(bootstrap.fixed_delta_seconds)
				for event in bootstrap.get_event_history():
					if event.shot_aim != null:
						aim = event.shot_aim
					if event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED:
						save = event.goalkeeper_save
			_check(aim != null, "actual source releases with entered shooting")
			if aim != null:
				_check(aim.shooting == attributes.x, "F11 locks entered S for all three sources")
				_check(is_equal_approx(aim.miss_probability, ShotAccuracyResolver.calculate_miss_probability(attributes.x, bootstrap.match_config)), "F11 probability follows input")
				_check(aim.miss_sample >= 0.0 and aim.is_miss == (aim.miss_sample < aim.miss_probability), "F11 uses real sample")
			if save != null:
				_check(save.base_shooting == attributes.x and save.goalkeeping == attributes.y, "F04 receives both entered values")
				_check(save.did_catch == (save.sample < save.save_probability), "F04 uses real sample and computed probability")
			controls._reset()
			bootstrap.set_process(false)
			_check(bootstrap.get_keeper_test_attributes() == attributes, "reset preserves entered values")
	# Invalid input must neither rebuild the match nor partially replace the previous valid pair.
	var previous := bootstrap.get_keeper_test_attributes()
	for invalid in ["", "abc", "0", "101", "80.5", "-1"]:
		var simulation := bootstrap._match_simulation
		controls._shooting.text = invalid
		controls._goalkeeping.text = "70"
		controls._shooting.text_submitted.emit(invalid)
		_check(bootstrap._match_simulation == simulation and bootstrap.get_keeper_test_attributes() == previous, "invalid shooting rejected atomically: " + invalid)
		controls._shooting.text = "80"
		controls._goalkeeping.text = invalid
		controls._goalkeeping.text_submitted.emit(invalid)
		_check(bootstrap._match_simulation == simulation and bootstrap.get_keeper_test_attributes() == previous, "invalid keeping rejected atomically: " + invalid)
	_check(FileAccess.get_file_as_string("res://resources/data/players.csv") == before_csv, "manual inputs never write CSV")
	_check(bootstrap._data_repository.get_player_by_id("steady_keeper").goalkeeping == 94, "repository definitions stay unchanged")
	bootstrap.free()
	for failure in _failures:
		push_error(failure)
	print("Keeper attribute input failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Collects independent failures without relying on rendering or random frequency statistics.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
