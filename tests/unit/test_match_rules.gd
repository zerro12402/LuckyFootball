## Verifies deterministic whole-ball boundary geometry without scenes or rendering.
extends SceneTree

const TOLERANCE := MatchRules.LINE_EPSILON_M

var _rules: MatchRules
var _failures: PackedStringArray = []


## Loads the production field and radius before running isolated boundary cases.
func _init() -> void:
	var repository := DataRepository.new()
	_expect(repository.load_all(), "Expected production field and ball radius")
	if not _failures.is_empty():
		_finish()
		return
	var field := repository.get_field_by_id("demo_field")
	var config := repository.get_match_config_by_id("demo_match")
	_rules = MatchRules.new(field, config.ball_radius_m)
	test_touching_lines_does_not_resolve()
	test_both_goals_resolve_at_center()
	test_post_edge_is_out()
	test_high_speed_uses_goal_plane_intersection()
	test_inward_motion_does_not_score()
	test_first_of_two_crossings_wins()
	test_corner_tie_has_stable_side()
	_finish()


## A touching ball and a sub-tolerance excess both remain in play.
func test_touching_lines_does_not_resolve() -> void:
	_expect(_rules.resolve_ball_boundary(Vector2.ZERO, Vector2(25.55, 0.0)) == null,
		"Right goal line touch was resolved")
	_expect(_rules.resolve_ball_boundary(Vector2.ZERO, Vector2(0.0, -15.55)) == null,
		"Top touch was resolved")
	_expect(_rules.resolve_ball_boundary(
		Vector2.ZERO, Vector2(25.55 + TOLERANCE * 0.5, 0.0)) == null,
		"Sub-tolerance excess was resolved")
	_expect(_rules.resolve_ball_boundary(
		Vector2.ZERO, Vector2(0.0, 15.55 + TOLERANCE * 2.0)) != null,
		"Clear whole-ball sideline crossing was missed")
	_expect(_rules.resolve_ball_boundary(
		Vector2(25.55 + TOLERANCE * 0.5, 0.0),
		Vector2(25.55 + TOLERANCE * 2.0, 0.0)) != null,
		"Crossing through the tolerance band was missed")


## Left and right score only after the complete ball crosses the base line.
func test_both_goals_resolve_at_center() -> void:
	var right := _rules.resolve_ball_boundary(Vector2.ZERO, Vector2(26.0, 0.0))
	var left := _rules.resolve_ball_boundary(Vector2.ZERO, Vector2(-26.0, 0.0))
	_expect(right != null and right.outcome == MatchBoundaryResult.Outcome.GOAL
		and right.side == MatchBoundaryResult.Side.RIGHT, "Right goal was missed")
	_expect(left != null and left.outcome == MatchBoundaryResult.Outcome.GOAL
		and left.side == MatchBoundaryResult.Side.LEFT, "Left goal was missed")


## A ball that touches the post opening is a goal-line out.
func test_post_edge_is_out() -> void:
	var post := _rules.resolve_ball_boundary(
		Vector2(0.0, 1.45), Vector2(26.0, 1.45))
	_expect(post != null and post.outcome == MatchBoundaryResult.Outcome.OUT
		and post.side == MatchBoundaryResult.Side.RIGHT, "Post-edge shot was scored")
	var inside := _rules.resolve_ball_boundary(
		Vector2(0.0, 1.44), Vector2(26.0, 1.44))
	_expect(inside != null and inside.outcome == MatchBoundaryResult.Outcome.GOAL,
		"Clearly inside-post shot was marked out")


## Goal placement uses the actual base-line intersection, not the step endpoint.
func test_high_speed_uses_goal_plane_intersection() -> void:
	var result := _rules.resolve_ball_boundary(
		Vector2(24.0, 0.5), Vector2(28.0, 3.5))
	_expect(result != null and result.outcome == MatchBoundaryResult.Outcome.GOAL,
		"Fast diagonal ball used its endpoint instead of the goal plane")
	if result != null:
		_expect(absf(result.ball_position_m.y - 1.25) < 0.0001,
			"Goal crossing Y was calculated incorrectly")


## Entering from beyond the line never generates an outward goal event.
func test_inward_motion_does_not_score() -> void:
	_expect(_rules.resolve_ball_boundary(Vector2(26.0, 0.0), Vector2(24.0, 0.0))
		== null, "Outside-to-inside motion scored")


## The first fully crossed boundary wins even when the endpoint crosses two.
func test_first_of_two_crossings_wins() -> void:
	var result := _rules.resolve_ball_boundary(
		Vector2(24.0, 14.9), Vector2(30.0, 18.0))
	_expect(result != null and result.outcome == MatchBoundaryResult.Outcome.OUT
		and result.side == MatchBoundaryResult.Side.BOTTOM,
		"Earlier sideline crossing lost to a later base-line crossing")


## Equal-time corner crossings resolve as out with fixed edge priority.
func test_corner_tie_has_stable_side() -> void:
	var result := _rules.resolve_ball_boundary(
		Vector2(24.0, 14.0), Vector2(30.0, 20.0))
	_expect(result != null and result.outcome == MatchBoundaryResult.Outcome.OUT
		and result.side == MatchBoundaryResult.Side.BOTTOM
		and result.is_corner, "Corner tie did not resolve deterministically")


## Stores failures so every geometry case can run independently.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Reports one process status after the rules have been exercised.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
