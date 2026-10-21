## Verifies continuous body/keeper/boundary ordering without rendering or scene nodes.
extends SceneTree

var _failures: PackedStringArray = []

## Exercises first-contact ordering, moving bodies, height clipping and stable ties.
func _init() -> void:
	var repository := DataRepository.new()
	_check(repository.load_all(), "Match data must load")
	var config := repository.get_match_config_by_id("demo_match")
	var field := repository.get_field_by_id("demo_field")
	var rules := MatchRules.new(field, config.ball_radius_m)
	var half := field.length_m * 0.5
	var ball := BallMatchState.new(Vector2(half - 4.0, 0.0))
	ball._launch_shot(ball.position_m, Vector2(40.0, 0.0), 70.0, 0.01)
	var trajectory := BallShotTrajectory.new(ball, 0.3, config)
	var players: Array[BallContactPlayer] = [
		_body("defender", Vector2(half - 1.0, 0.0)),
		_body("keeper", Vector2(half - 0.5, 0.0), true),
		_body("after_line", Vector2(half + 3.0, 0.0)),
	]
	var candidates := BallContactResolver.find_candidates(trajectory, players, config, rules)
	_check(candidates.size() == 4, "Body, keeper, boundary and post-line body must be found")
	if candidates.size() == 4:
		_check(candidates[0].player_id == "defender", "Defender must precede the goal")
		_check(candidates[1].kind == BallContactCandidate.Kind.GOALKEEPER,
			"Keeper must retain its separate route")
		_check(candidates[2].kind == BallContactCandidate.Kind.BOUNDARY,
			"Whole-ball boundary must precede the body beyond the line")
		_check(candidates[3].player_id == "after_line", "Post-line contact must sort last")
	var high := _body("high", Vector2(half - 1.0, 0.0))
	high.start_height_m = 5.0
	high.end_height_m = 5.0
	_check(BallContactResolver.find_candidates(trajectory, [high], config).is_empty(),
		"Planar crossing without overlapping heights must not contact")
	var moving := _body("moving", Vector2(half - 1.0, -3.0))
	moving.end_position_m = Vector2(half - 1.0, 9.0)
	_check(not BallContactResolver.find_candidates(trajectory, [moving], config).is_empty(),
		"A moving body crossing the high-speed shot within one step must be swept")
	var ties: Array[BallContactPlayer] = [_body("z", Vector2(half - 1.0, 0.0)),
		_body("a", Vector2(half - 1.0, 0.0))]
	var sorted := BallContactResolver.find_candidates(trajectory, ties, config)
	_check(sorted.size() == 2 and sorted[0].player_id == "a", "Exact ties use stable IDs")
	var tie_position := Vector2(half + config.ball_radius_m
		+ config.ball_impact_body_radius_m + config.ball_radius_m, 0.0)
	var tied_boundary := BallContactResolver.find_candidates(trajectory,
		[_body("at_line", tie_position)], config, rules)
	_check(tied_boundary.size() == 2
		and tied_boundary[0].kind == BallContactCandidate.Kind.BOUNDARY,
		"Numerically simultaneous whole-ball crossing must have deterministic boundary priority")
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: ball contact candidates")
	quit(0 if _failures.is_empty() else 1)

## Builds a stationary body with explicit goalkeeper routing.
func _body(id: String, position: Vector2, keeper: bool = false) -> BallContactPlayer:
	return BallContactPlayer.new(id, position, position, 0.0, 0.0, keeper)

## Records each independent contact contract violation.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
