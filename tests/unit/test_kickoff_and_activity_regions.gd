## Verifies production kickoff, two-one-two rosters and phase-specific soft responsibility regions without rendering.
extends SceneTree
const Fixture = preload("res://tests/support/ai_fixture.gd")
var _failures: PackedStringArray = []

## Uses real tables and production assembly while isolating invalid input and temporal boundary cases.
func _init() -> void:
	_test_opening_and_release()
	_test_round_restarts()
	_test_regions()
	for failure in _failures:
		printerr(failure)
	print("Kickoff and activity regions: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

## The opening owner is reproducible, opponent commands cannot enter the circle, and queued passes do not unlock early.
func _test_opening_and_release() -> void:
	var f := Fixture.new()
	for team in f.formal.teams.teams:
		var forwards := 0
		var backs := 0
		var mids := 0
		for entry in f.formal.teams.get_roster(team.team_id):
			forwards += int(entry.default_position.begins_with("forward"))
			backs += int(entry.default_position.begins_with("back"))
			mids += int(entry.default_position == "mid")
		_check(forwards == 2 and backs == 2 and mids == 1, "both teams field two forwards, one midfielder and two backs")
	var simulation := f.formal.create(20.0, "opening", 42, true)
	var clone := f.formal.create(20.0, "opening", 42, true)
	var before := simulation.create_snapshot()
	_check(before.kickoff_team_id == clone.create_snapshot().kickoff_team_id, "same seed chooses same opening team")
	_check(before.kickoff_pending and before.ball.owner_player_id == before.kickoff_player_id
		and before.ball.position_m.is_equal_approx(Vector2.ZERO), "READY has exactly one opening owner with ball at center")
	var receiver := ""
	var opponent := ""
	var possessing := 0
	for player in before.players:
		var direction := f.formal.teams.get_team(player.team_id).attacking_direction
		_check(player.position_m.x * direction <= 0.0, "every player starts in own half")
		possessing += int(player.possession_state == PlayerMatchState.PossessionState.POSSESSING)
		if player.team_id != before.kickoff_team_id:
			_check(player.position_m.length() > f.formal.field.center_circle_radius_m + f.rules.ball_radius_m,
				"defenders start outside center-circle exclusion")
			opponent = player.player_id
		elif player.player_id != before.kickoff_player_id and not player.is_goalkeeper:
			receiver = player.player_id
	_check(possessing == 1, "kickoff possession is unique")
	simulation.start_match()
	var opponent_position := simulation.create_snapshot().get_player(opponent).position_m
	simulation.advance_fixed_step(0.01, [MatchAction.new(opponent, MatchAction.Type.MOVE, Vector2.LEFT),
		MatchAction.new(before.kickoff_player_id, MatchAction.Type.MOVE)])
	_check(simulation.create_snapshot().kickoff_pending
		and simulation.create_snapshot().get_player(opponent).position_m == opponent_position,
		"zero movement cannot unlock kickoff and opponent intent is rejected")
	simulation.advance_fixed_step(0.01, [MatchAction.new(before.kickoff_player_id,
		MatchAction.Type.PASS, Vector2.ZERO, receiver)])
	_check(simulation.create_snapshot().kickoff_pending, "accepted pass windup is not the actual opening kick")
	var released := false
	for step in range(35):
		var events := simulation.advance_fixed_step(0.01, [])
		for event in events:
			if event.event_type == MatchEvent.Type.BALL_PASSED:
				released = true
		if released:
			break
	_check(released and not simulation.create_snapshot().kickoff_pending, "actual pass release opens normal play")
	_check(before.kickoff_pending, "old kickoff snapshot remains immutable")
	var paused := f.formal.create(3.0, "paused_opening", 11, true)
	paused.start_match()
	var old_batch := MatchActionBatch.new(paused.create_snapshot(),
		[MatchAction.new(paused.create_snapshot().kickoff_player_id, MatchAction.Type.MOVE, Vector2.RIGHT)])
	paused.pause_match()
	paused.resume_match()
	paused.advance_action_batch(0.01, old_batch)
	_check(paused.create_snapshot().kickoff_pending, "stale pre-pause opening batch cannot unlock")
	paused.advance_fixed_step(0.01,
		[MatchAction.new(paused.create_snapshot().kickoff_player_id, MatchAction.Type.MOVE, Vector2.RIGHT)])
	_check(not paused.create_snapshot().kickoff_pending, "accepted dribbling unlocks the opening")

## Existing boundary settlement hands center restarts to the conceding side or exchanges the out restart.
func _test_round_restarts() -> void:
	var f := Fixture.new()
	var simulation := f.formal.create(20.0, "restart", 42, true)
	simulation.start_match()
	simulation.advance_fixed_step(0.01,
		[MatchAction.new(simulation.create_snapshot().kickoff_player_id, MatchAction.Type.MOVE, Vector2.RIGHT)])
	f.formal.launch_boundary(simulation, 0.01)
	for step in range(600):
		simulation.advance_fixed_step(0.01, [])
		if simulation.create_snapshot().round_sequence == 2:
			break
	var snapshot := simulation.create_snapshot()
	_check(snapshot.round_sequence == 2 and snapshot.kickoff_pending
		and snapshot.kickoff_team_id == "away" and snapshot.ball.owner_player_id == snapshot.kickoff_player_id,
		"right-goal reset gives conceding away team the kickoff")
	simulation.advance_fixed_step(0.01, [MatchAction.new(snapshot.kickoff_player_id, MatchAction.Type.MOVE, Vector2.LEFT)])
	f.formal.launch_boundary(simulation, 0.01, false)
	for step in range(600):
		simulation.advance_fixed_step(0.01, [])
		if simulation.create_snapshot().round_sequence == 3:
			break
	snapshot = simulation.create_snapshot()
	_check(snapshot.round_sequence == 3 and snapshot.kickoff_team_id == "home" and snapshot.kickoff_pending,
		"prototype out reset exchanges opening team without reseeding the match")

## Tactical ranges differ by team phase, mirror across the pitch, and permit transient ball duties.
func _test_regions() -> void:
	var f := Fixture.new()
	var regions := f.formal.data.load_activity_regions()
	_check(regions != null and regions.regions.size() == 18, "six positions have all three phase definitions")
	var attack := regions.get_region("back_left", TeamTacticalContext.Phase.ATTACK).bounds(f.formal.field, 1.0)
	var defend := regions.get_region("back_left", TeamTacticalContext.Phase.DEFEND).bounds(f.formal.field, 1.0)
	var mirrored := regions.get_region("back_left", TeamTacticalContext.Phase.ATTACK).bounds(f.formal.field, -1.0)
	_check(attack.end.x > defend.end.x and attack.position.x > defend.position.x,
		"attacking back region advances relative to defending region")
	_check(is_equal_approx(attack.position.x, -mirrored.end.x) and attack.position.y == mirrored.position.y,
		"opposite team regions mirror longitudinally")
	var builder := RoleCandidateBuilder.new(f.tuning, f.rules, f.formal.field, regions)
	var player := f.player("iron_guard", Vector2(10, 0))
	var owner := f.player("swift_forward", Vector2(15, 0))
	var enemy := f.player("enemy", Vector2(15, 0), "away")
	var ball := BallMatchState.new(owner.state.position_m)
	ball._set_owner(owner.player_id)
	var snapshot := f.snapshot([player, owner, enemy], ball)
	var choices := builder.build(snapshot, player.player_id, "back", Vector2(-16, -7),
		Vector2(25, 0), owner.player_id, false, -1, "back_left")
	_check(choices.size() == 1 and choices[0].behavior == AIActionCandidate.Behavior.RETURN
		and _inside(choices[0].targets[0].destination_m, attack), "released nonprimary player returns to active region")
	ball._set_owner(player.player_id)
	snapshot = f.snapshot([player, owner, enemy], ball)
	_check(not builder.requires_region_return(snapshot, snapshot.get_player(player.player_id), "", "back_left", Vector2(25, 0)),
		"carrier may temporarily leave responsibility region")
	ball._set_owner(enemy.player_id)
	snapshot = f.snapshot([player, owner, enemy], ball)
	var press := builder.movement_target(snapshot, snapshot.get_player(player.player_id),
		AIActionCandidate.Behavior.PRESS, "back", Vector2(-16, -7), Vector2(25, 0), "back_left")
	_check(press.x > defend.end.x and not builder.requires_region_return(snapshot,
		snapshot.get_player(player.player_id), player.player_id, "back_left", Vector2(25, 0)),
		"primary defender can pursue beyond defending region")
	var support := builder.movement_target(snapshot, snapshot.get_player(player.player_id),
		AIActionCandidate.Behavior.RETURN, "back", Vector2(-16, -7), Vector2(25, 0), "back_left")
	_check(_inside(support, defend) and player.state.position_m == Vector2(10, 0),
		"ordinary return stays in region without teleporting the actor")
	var csv := FileAccess.get_file_as_string("res://resources/data/player_activity_regions.csv")
	var path := "user://bad_activity_regions.csv"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(csv + "keeper,attack,own_penalty,0,1,0,1,duplicate\n")
	file.close()
	var bad := PlayerActivityRegionRepository.new()
	_check(not bad.load_from_csv(path) and bad.regions.is_empty(), "duplicate region rejects complete publication")
	for invalid in [csv.replace("back_left,attack,field,0.1,0.6", "back_left,attack,field,0.7,0.6"),
			csv.replace("keeper,attack,own_penalty,0,1,0,1", "keeper,attack,own_penalty,0,inf,0,1"),
			"position_id,phase,space,min_u,max_u,min_v,max_v,comment\n"]:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(invalid)
		file.close()
		_check(not bad.load_from_csv(path) and bad.regions.is_empty(), "invalid bounds or incomplete coverage reject publication")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var returning := f.player("formal_player_03", Vector2(-0.05, -2.5))
	owner.state._set_position(Vector2(-24, 0))
	ball._set_owner(owner.player_id)
	snapshot = f.snapshot([returning, owner], ball)
	var intent := Vector2.ZERO
	for action in f.source(true).propose_actions(snapshot):
		if action.player_id == returning.player_id and action.action_type == MatchAction.Type.MOVE:
			intent = action.direction
	_check(intent.x > 0.0, "return crosses the region edge even when within ordinary arrival tolerance")

## Rectangle comparisons include the right edge used by clamped destinations.
func _inside(point: Vector2, bounds: Rect2) -> bool:
	return point.x >= bounds.position.x and point.x <= bounds.end.x \
		and point.y >= bounds.position.y and point.y <= bounds.end.y

## Aggregates independent assertions into one exit status.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
