## Verifies jump height, ground-tackle eligibility, and one-time aerial shot release.
extends SceneTree

const CARRIER_ID := "carrier"
const DEFENDER_ID := "defender"

var _config: MatchConfigDefinition
var _failures: PackedStringArray = []


## Loads the real CSV preset and exercises fixed-step aerial behavior without scenes.
func _init() -> void:
	var repository := DataRepository.new()
	_expect(repository.load_all(), "Expected valid match data")
	if not _failures.is_empty():
		_finish()
		return
	_config = repository.get_match_config_by_id("demo_match")
	test_jump_requires_possession_and_does_not_release_ball()
	test_jump_height_and_ball_follow_until_reset()
	test_ground_tackle_before_takeoff_and_after_landing()
	test_ground_tackle_cannot_touch_effective_airborne_carrier()
	test_tackle_started_before_clearance_rechecks_contact_height()
	test_aerial_shot_releases_once_from_carried_height()
	test_aerial_shot_arc_starts_at_release_height()
	test_landing_before_kick_cancels_aerial_shot()
	test_ownership_loss_before_kick_cancels_aerial_shot()
	test_knockdown_before_kick_cancels_aerial_shot()
	test_aerial_shot_replay_is_deterministic()
	_finish()


## Rejects an unowned jump and retains the same owner throughout a valid takeoff.
func test_jump_requires_possession_and_does_not_release_ball() -> void:
	var empty_match := _create_match(false, false)
	var rejected := empty_match.advance_fixed_step(0.05, [_jump_action()])
	_expect(not _has_event(rejected, MatchEvent.Type.ACTION_ACCEPTED),
		"Unowned jump was accepted")
	var simulation := _create_match()
	var accepted := simulation.advance_fixed_step(0.05, [_jump_action()])
	var snapshot := simulation.create_snapshot()
	_expect(_has_event(accepted, MatchEvent.Type.ACTION_ACCEPTED), "Jump was rejected")
	_expect(snapshot.ball.owner_player_id == CARRIER_ID, "Jump released possession")
	_expect(snapshot.get_player(CARRIER_ID).jump_phase == PlayerMatchState.JumpPhase.TAKEOFF,
		"Jump skipped takeoff")
	_expect(not _has_event(simulation.advance_fixed_step(0.05, [_jump_action()]),
		MatchEvent.Type.ACTION_ACCEPTED), "Duplicate jump was accepted")


## Uses one fixed arc for player and owned ball, then clears both on round reset.
func test_jump_height_and_ball_follow_until_reset() -> void:
	var simulation := _create_match()
	simulation.advance_fixed_step(0.25, [_jump_action()])
	var airborne := simulation.create_snapshot()
	var player := airborne.get_player(CARRIER_ID)
	_expect(player.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE,
		"Jump did not become airborne")
	_expect(player.height_m > _config.ground_tackle_clearance_height_m,
		"Jump did not reach configured clearance")
	_expect(is_equal_approx(airborne.ball.height_m, player.height_m),
		"Owned ball did not follow player height")
	_expect(airborne.ball.owner_player_id == CARRIER_ID, "Airborne jump changed owner")
	simulation.advance_fixed_step(0.5, [])
	var landing := simulation.create_snapshot().get_player(CARRIER_ID)
	_expect(landing.jump_phase == PlayerMatchState.JumpPhase.LANDING,
		"Jump did not enter landing")
	simulation.advance_fixed_step(0.05, [])
	_expect(simulation.create_snapshot().get_player(CARRIER_ID).jump_phase
		== PlayerMatchState.JumpPhase.NONE, "Jump did not finish")
	simulation.advance_fixed_step(0.25, [_jump_action()])
	simulation.advance_fixed_step(0.05, [MatchAction.new("", MatchAction.Type.RESET_ROUND)])
	var reset := simulation.create_snapshot()
	_expect(is_zero_approx(reset.get_player(CARRIER_ID).height_m),
		"Reset retained player height")
	_expect(is_zero_approx(reset.ball.height_m), "Reset retained ball height")


## Preserves ordinary ground contact before a jump and after it fully ends.
func test_ground_tackle_before_takeoff_and_after_landing() -> void:
	var before := _create_match(true)
	before.advance_fixed_step(0.1, [_tackle_action()])
	var before_events := before.advance_fixed_step(0.1, [])
	_expect(_has_event(before_events, MatchEvent.Type.TACKLE_SUCCEEDED),
		"Ground tackle failed before takeoff")
	var after := _create_match(true)
	after.advance_fixed_step(0.8, [_jump_action()])
	_expect(after.create_snapshot().get_player(CARRIER_ID).jump_phase
		== PlayerMatchState.JumpPhase.NONE, "Jump did not end before tackle")
	after.advance_fixed_step(0.1, [_tackle_action()])
	var after_events := after.advance_fixed_step(0.1, [])
	_expect(_has_event(after_events, MatchEvent.Type.TACKLE_SUCCEEDED),
		"Ground tackle failed after landing")


## Rejects ground contact only during an airborne phase above the configured height.
func test_ground_tackle_cannot_touch_effective_airborne_carrier() -> void:
	var simulation := _create_match(true)
	simulation.advance_fixed_step(0.25, [_jump_action()])
	var events := simulation.advance_fixed_step(0.05, [_tackle_action()])
	_expect(not _has_event(events, MatchEvent.Type.ACTION_ACCEPTED),
		"Ground tackle started against high airborne carrier")
	_expect(simulation.create_snapshot().ball.owner_player_id == CARRIER_ID,
		"Airborne carrier lost possession")


## Rechecks height at the active contact step rather than only at command acceptance.
func test_tackle_started_before_clearance_rechecks_contact_height() -> void:
	var simulation := _create_match(true)
	simulation.advance_fixed_step(0.05, [_jump_action()])
	var accepted := simulation.advance_fixed_step(0.05, [_tackle_action()])
	_expect(_has_event(accepted, MatchEvent.Type.ACTION_ACCEPTED),
		"Early ground tackle should start during takeoff")
	var contact := simulation.advance_fixed_step(0.1, [])
	_expect(not _has_event(contact, MatchEvent.Type.TACKLE_SUCCEEDED),
		"Ground tackle ignored effective airborne height at contact")
	_expect(simulation.create_snapshot().ball.owner_player_id == CARRIER_ID,
		"Early tackle transferred an airborne ball")


## Releases exactly once at the kick frame and continues from nonzero ball height.
func test_aerial_shot_releases_once_from_carried_height() -> void:
	var simulation := _create_match()
	simulation.advance_fixed_step(0.15, [_jump_action()])
	var start_height_m := simulation.create_snapshot().ball.height_m
	var windup := simulation.advance_fixed_step(0.1, [_shot_action()])
	_expect(_has_event(windup, MatchEvent.Type.ACTION_ACCEPTED),
		"Airborne shot was rejected")
	_expect(simulation.create_snapshot().ball.owner_player_id == CARRIER_ID,
		"Airborne shot released during windup")
	var kick := simulation.advance_fixed_step(0.1, [])
	var ball := simulation.create_snapshot().ball
	_expect(_has_event(kick, MatchEvent.Type.BALL_SHOT), "Airborne shot missed kick frame")
	_expect(ball.motion_state == BallMatchState.MotionState.IN_FLIGHT,
		"Airborne shot did not fly independently")
	_expect(ball.owner_player_id.is_empty(), "Airborne shot retained owner")
	_expect(ball.height_m > start_height_m, "Airborne shot restarted at ground height")
	_expect(is_equal_approx(simulation.create_snapshot().get_player(CARRIER_ID).height_m,
		_config.jump_apex_height_m * 4.0 * (0.35 / 0.8) * (1.0 - 0.35 / 0.8)),
		"Player height diverged from fixed jump arc")
	var next := simulation.advance_fixed_step(0.1, [])
	_expect(not _has_event(next, MatchEvent.Type.BALL_SHOT),
		"Airborne shot released twice")


## The flight arc carries its release height and returns to ground at the end.
func test_aerial_shot_arc_starts_at_release_height() -> void:
	var ball := BallMatchState.new(Vector2.ZERO)
	ball._set_owner(CARRIER_ID)
	ball._set_control_height(0.5)
	ball._launch_shot(Vector2.ZERO, Vector2.RIGHT * 10.0, 10.0, 0.75, ball.height_m)
	_expect(is_equal_approx(ball.height_m, 0.5),
		"Shot launch reset the ball to ground height")
	ball._advance_shot(Vector2(5.0, 0.0), Vector2.RIGHT * 10.0, 5.0)
	_expect(is_equal_approx(ball.height_m, 1.0),
		"Shot midflight omitted the remaining release height")
	ball._advance_shot(Vector2(10.0, 0.0), Vector2.RIGHT * 10.0, 5.0)
	_expect(is_zero_approx(ball.height_m), "Shot arc did not return to ground")


## Keeps the owned ball when a queued aerial shot reaches landing before touch.
func test_landing_before_kick_cancels_aerial_shot() -> void:
	var simulation := _create_match()
	simulation.advance_fixed_step(0.55, [_jump_action()])
	simulation.advance_fixed_step(0.1, [_shot_action()])
	var events := simulation.advance_fixed_step(0.1, [])
	_expect(not _has_event(events, MatchEvent.Type.BALL_SHOT),
		"Landing launched an aerial shot")
	_expect(simulation.create_snapshot().ball.owner_player_id == CARRIER_ID,
		"Cancelled aerial shot released possession")


## A valid external possession transfer clears the queued shot before its kick frame.
func test_ownership_loss_before_kick_cancels_aerial_shot() -> void:
	var players := PlayerRuntimeSystem.new()
	_expect(players.register_player(CARRIER_ID, Vector2.ZERO, 5.0, "home", 80),
		"Carrier runtime was rejected")
	_expect(players.register_player(DEFENDER_ID, Vector2(-1.0, 0.0), 5.0, "away", 60),
		"Defender runtime was rejected")
	var carrier := players.get_player(CARRIER_ID)
	var defender := players.get_player(DEFENDER_ID)
	var ball := BallRuntimeSystem.new()
	ball.configure_match_rules(_config)
	_expect(ball.register_ball(Vector2(0.55, 0.0)), "Ball runtime was rejected")
	ball.state._set_owner(CARRIER_ID)
	carrier.state_machine.set_possession_state(PlayerMatchState.PossessionState.POSSESSING)
	_expect(carrier.state_machine.try_start_jump(_config), "Carrier could not jump")
	carrier.advance(0.15)
	ball.advance(0.15, players, false)
	_expect(ball.try_start_shot(carrier, Vector2.RIGHT, 1.0),
		"Carrier could not queue aerial shot")
	ball.advance(0.05, players, false)
	_expect(defender.state_machine.try_start_tackle(_config), "Defender could not tackle")
	defender.advance(0.2)
	_expect(ball.transfer_tackled_ball(carrier, defender), "Test transfer did not change owner")
	var result := ball.advance(0.2, players, false)
	_expect(result.shot_by_player_id.is_empty(), "Lost carrier still launched a shot")
	_expect(ball.state.owner_player_id == DEFENDER_ID,
		"Cancelled shot changed the new owner")


## An opponent's hit cancels the windup and drops the original ball without a shot.
func test_knockdown_before_kick_cancels_aerial_shot() -> void:
	var simulation := _create_match(true)
	simulation.advance_fixed_step(0.15, [_jump_action()])
	simulation.advance_fixed_step(0.05, [_shot_action()])
	var attack := MatchAction.new(
		DEFENDER_ID, MatchAction.Type.ATTACK, Vector2.ZERO, CARRIER_ID
	)
	var events := simulation.advance_fixed_step(0.05, [attack])
	_expect(_has_event(events, MatchEvent.Type.PLAYER_KNOCKED_DOWN),
		"Hit did not interrupt aerial shot")
	_expect(simulation.create_snapshot().ball.owner_player_id.is_empty(),
		"Knockdown did not release the ball")
	for step_index in range(5):
		events = simulation.advance_fixed_step(0.1, [])
		_expect(not _has_event(events, MatchEvent.Type.BALL_SHOT),
			"Interrupted shot generated a later ball")


## Equal seed, setup and commands produce the same aerial trajectory and ownership.
func test_aerial_shot_replay_is_deterministic() -> void:
	var first := _create_match()
	var second := _create_match()
	var simulations: Array[MatchSimulation] = [first, second]
	for simulation in simulations:
		simulation.advance_fixed_step(0.15, [_jump_action()])
		simulation.advance_fixed_step(0.1, [_shot_action()])
		simulation.advance_fixed_step(0.1, [])
	var first_ball := first.create_snapshot().ball
	var second_ball := second.create_snapshot().ball
	_expect(first_ball.position_m.is_equal_approx(second_ball.position_m),
		"Aerial shot positions diverged")
	_expect(is_equal_approx(first_ball.height_m, second_ball.height_m),
		"Aerial shot heights diverged")


## Builds one carrier, optional nearby defender, and a single initially free ball.
func _create_match(with_defender: bool = false, acquire_ball: bool = true) -> MatchSimulation:
	var simulation := MatchSimulation.new(44, _config)
	_expect(simulation.register_player(CARRIER_ID, Vector2.ZERO, 5.0, "home", 80),
		"Carrier registration failed")
	_expect(simulation.register_team_attacking_goal("home", Vector2(25.0, 0.0)),
		"Goal registration failed")
	if with_defender:
		_expect(simulation.register_player(
			DEFENDER_ID, Vector2(-1.0, 0.0), 5.0, "away", 60
		), "Defender registration failed")
	var ball_position_m := Vector2(0.5, 0.0) if acquire_ball else Vector2(5.0, 0.0)
	_expect(simulation.register_ball(ball_position_m), "Ball registration failed")
	_expect(simulation.start_match(), "Match did not start")
	if acquire_ball:
		simulation.advance_fixed_step(0.05, [])
	return simulation


func _jump_action() -> MatchAction:
	return MatchAction.new(CARRIER_ID, MatchAction.Type.JUMP)


func _shot_action() -> MatchAction:
	return MatchAction.new(CARRIER_ID, MatchAction.Type.SHOOT)


func _tackle_action() -> MatchAction:
	return MatchAction.new(DEFENDER_ID, MatchAction.Type.TACKLE, Vector2.ZERO, CARRIER_ID)


## Searches the step's structured events without relying on unrelated clock events.
func _has_event(events: Array[MatchEvent], event_type: int) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false


## Records each violated rule while allowing remaining scenarios to run.
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Reports all failed facts through the headless process exit status.
func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
