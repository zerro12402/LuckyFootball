## Checks swept high-ball contacts without scene or rendering dependencies.
extends SceneTree

var _failures: PackedStringArray = []


## Exercises arrival ordering, moving crossings, and both height limits.
func _init() -> void:
	var ball := BallMatchState.new(Vector2.ZERO)
	ball._launch_pass("receiver", Vector2(10.0, 0.0), 10.0, 1.8)
	var candidates := HeaderContactResolver.find_candidates(ball, Vector2(4.0, 0.0), [
		HeaderPlayerTrajectory.new("late", "red", Vector2(3.0, 0.0), Vector2(3.0, 0.0), 0.0, 0.0, 40, 40),
		HeaderPlayerTrajectory.new("early", "blue", Vector2(2.0, 0.0), Vector2(2.0, 0.0), 0.0, 0.0, 40, 40),
	], 0.4, 0.3, 1.9)
	_check(candidates.size() == 2, "Both high contacts should be detected")
	if candidates.size() == 2:
		_check(candidates[0].player_id == "early", "Earliest contact must sort first")
		_check(candidates[0].contact_fraction < candidates[1].contact_fraction,
			"Contacts must retain first crossing times")
	var simultaneous := HeaderContactResolver.find_candidates(ball, Vector2(4.0, 0.0), [
		HeaderPlayerTrajectory.new("z", "red", Vector2(2.0, 0.0), Vector2(2.0, 0.0), 0.0, 0.0, 40, 40),
		HeaderPlayerTrajectory.new("a", "blue", Vector2(2.0, 0.0), Vector2(2.0, 0.0), 0.0, 0.0, 40, 40),
	], 0.4, 0.3, 1.9)
	_check(simultaneous.size() == 2 and simultaneous[0].player_id == "a",
		"Equal-time opponents must sort by ID")
	var crossing := HeaderContactResolver.find_candidates(ball, Vector2(4.0, 0.0), [
		HeaderPlayerTrajectory.new("runner", "blue", Vector2(2.0, -2.0), Vector2(2.0, 2.0), 0.0, 0.0, 40, 40),
	], 0.4, 0.3, 1.9)
	_check(crossing.size() == 1, "Cross-step moving contact must not be missed")
	var too_high := HeaderContactResolver.find_candidates(ball, Vector2(4.0, 0.0), [
		HeaderPlayerTrajectory.new("short", "blue", Vector2(2.0, 0.0), Vector2(2.0, 0.0), 0.0, 0.0, 40, 40),
	], 0.4, 0.3, 0.4)
	_check(too_high.is_empty(), "Ball above reach must not contact")
	var too_low := HeaderContactResolver.find_candidates(ball, Vector2(0.5, 0.0), [
		HeaderPlayerTrajectory.new("low", "blue", Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, 40, 40),
	], 0.4, 0.3, 1.9)
	_check(too_low.is_empty(), "Ground-height contact must use ordinary rules")
	if _failures.is_empty():
		print("PASS: header contact resolver")
	else:
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


## Collects each independent assertion for a useful headless result.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
