## Verifies swept net contacts and configured rebound without scenes or rendering.
extends SceneTree

var _field: FieldDefinition
var _config: MatchConfigDefinition
var _failures: PackedStringArray = []


## Loads production geometry and runs deterministic net-contact cases.
func _init() -> void:
	var repository := DataRepository.new()
	_expect(repository.load_all(), "Expected production match data")
	if not _failures.is_empty():
		_finish()
		return
	_field = repository.get_field_by_id("demo_field")
	_config = repository.get_match_config_by_id("demo_match")
	test_left_and_right_back_net_contact()
	test_top_and_bottom_side_net_contact()
	test_high_speed_first_contact_and_tie_order()
	test_slow_contact_stops_ball()
	_finish()


## Both goals stop a full ball radius before the back net and reverse X velocity.
func test_left_and_right_back_net_contact() -> void:
	for side in [MatchBoundaryResult.Side.LEFT, MatchBoundaryResult.Side.RIGHT]:
		var sign_x := -1.0 if side == MatchBoundaryResult.Side.LEFT else 1.0
		var start_m := Vector2(sign_x * (_field.length_m * 0.5 + _config.ball_radius_m), 0.0)
		var system := _create_ball(start_m, Vector2(sign_x * 30.0, 0.0))
		var contacts := system.advance_post_goal_motion(0.1, _field, _config, side)
		_expect(contacts.size() == 1, "Expected exactly one back-net contact")
		if contacts.size() == 1:
			_expect(contacts[0].surface == GoalNetContact.Surface.BACK,
				"Back net reported the wrong surface")
			_expect(absf(contacts[0].contact_position_m.x
				- sign_x * (_field.length_m * 0.5 + _field.goal_depth_m)) < 0.001,
				"Back-net contact position was incorrect")
			_expect(absf(contacts[0].velocity_after_mps.x
				+ sign_x * 30.0 * _config.goal_net_back_restitution) < 0.001,
				"Back-net restitution was incorrect")
		_expect(system.state.position_m.x * sign_x
			<= _field.length_m * 0.5 + _field.goal_depth_m - _config.ball_radius_m + 0.001,
			"Ball escaped through the back net")


## Side contacts use the configured goal width and retain only tangential speed.
func test_top_and_bottom_side_net_contact() -> void:
	for surface in [GoalNetContact.Surface.TOP, GoalNetContact.Surface.BOTTOM]:
		var sign_y := -1.0 if surface == GoalNetContact.Surface.TOP else 1.0
		var start_m := Vector2(_field.length_m * 0.5 + 0.8, 0.0)
		var system := _create_ball(start_m, Vector2(2.0, sign_y * 20.0))
		var contacts := system.advance_post_goal_motion(
			0.1, _field, _config, MatchBoundaryResult.Side.RIGHT)
		_expect(contacts.size() >= 1, "Expected a side-net contact")
		if not contacts.is_empty():
			_expect(contacts[0].surface == surface, "Side net reported the wrong surface")
			_expect(absf(contacts[0].contact_position_m.y
				- sign_y * _field.goal_width_m * 0.5) < 0.001,
				"Side-net contact position was incorrect")
			_expect(absf(contacts[0].velocity_after_mps.y
				+ sign_y * 20.0 * _config.goal_net_side_restitution) < 0.001,
				"Side-net restitution was incorrect")
			_expect(absf(contacts[0].velocity_after_mps.x
				- 2.0 * _config.goal_net_tangent_retention) < 0.001,
				"Side-net tangent retention was incorrect")


## A large step still detects the first surface, with back net winning a corner tie.
func test_high_speed_first_contact_and_tie_order() -> void:
	var start_m := Vector2(_field.length_m * 0.5 + _config.ball_radius_m, 1.0)
	var back_distance := _field.goal_depth_m - 2.0 * _config.ball_radius_m
	var side_distance := _field.goal_width_m * 0.5 - _config.ball_radius_m - start_m.y
	var velocity := Vector2(back_distance * 100.0, side_distance * 100.0)
	var system := _create_ball(start_m, velocity)
	var contacts := system.advance_post_goal_motion(
		0.2, _field, _config, MatchBoundaryResult.Side.RIGHT)
	_expect(not contacts.is_empty(), "High-speed ball skipped the goal net")
	if not contacts.is_empty():
		_expect(contacts[0].surface == GoalNetContact.Surface.BACK,
			"Corner tie did not prefer the back net")
		_expect(absf(contacts[0].contact_position_m.x
			- (_field.length_m * 0.5 + _field.goal_depth_m)) < 0.001,
			"High-speed sweep used the step end instead of first contact")


## A weak contact below the configured threshold stops without extra drift.
func test_slow_contact_stops_ball() -> void:
	var start_m := Vector2(_field.length_m * 0.5 + _config.ball_radius_m, 0.0)
	var system := _create_ball(start_m, Vector2(2.0, 0.0))
	var contacts := system.advance_post_goal_motion(
		0.3, _field, _config, MatchBoundaryResult.Side.RIGHT)
	_expect(contacts.size() == 1, "Slow ball did not contact the back net")
	_expect(system.state.velocity_mps == Vector2.ZERO,
		"Slow net contact did not stop the ball")


## Creates one released ball in the net-motion state.
func _create_ball(position_m: Vector2, velocity_mps: Vector2) -> BallRuntimeSystem:
	var system := BallRuntimeSystem.new()
	_expect(system.register_ball(position_m), "Expected ball registration")
	system.begin_post_goal_motion(position_m, velocity_mps)
	return system


## Collects failures so every collision case runs before the test exits.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Reports failures through Godot's test process exit code.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
