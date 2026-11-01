## Verifies half-open scoring time, short final steps and unique immutable results for real ball trajectories.
extends SceneTree
const Fixture = preload("res://tests/support/formal_match_fixture.gd")
var _failures: PackedStringArray = []

## Checks both swept trajectory paths at the deadline and terminal preemption of ongoing settlement.
func _init() -> void:
	var fixture := Fixture.new()
	for shot: bool in [false, true]:
		for goal: bool in [false, true]:
			for crossing: float in [0.05, 0.1, 0.15]:
				var simulation := fixture.create(0.1)
				simulation.start_match()
				fixture.launch_boundary(simulation, crossing, goal, shot)
				var facts := simulation.advance_fixed_step(0.2, [])
				var snapshot := simulation.create_snapshot()
				var expected := 1 if crossing < 0.1 else 0
				_check(_count(facts, MatchEvent.Type.GOAL_SCORED if goal else MatchEvent.Type.BALL_OUT_OF_BOUNDS) == expected, "crossing eligibility %s/%s/%.2f" % [shot, goal, crossing])
				_check(snapshot.phase == MatchState.Phase.FINISHED and snapshot.elapsed_seconds == 0.1 and snapshot.result != null, "deadline clips all trajectories and produces result")
				_check(snapshot.home_score == (expected if goal else 0) and snapshot.away_score == 0, "crossing scores are frozen and attributed by attack direction")
				_check(_count(facts, MatchEvent.Type.MATCH_FINISHED) == 1 and _count(facts, MatchEvent.Type.RESET_COMPLETED) == 0, "unique finish preempts reset")
				_check(snapshot.result.outcome == (FormalMatchResult.Outcome.HOME_WIN if goal and expected == 1 else FormalMatchResult.Outcome.DRAW), "terminal result reflects eligible goals only")
				var sequence := 0
				for event in facts:
					_check(event.event_sequence > sequence, "step facts have monotonically increasing order")
					sequence = event.event_sequence
					if event.event_type in [MatchEvent.Type.GOAL_SCORED, MatchEvent.Type.BALL_OUT_OF_BOUNDS, MatchEvent.Type.GOAL_NET_CONTACT]:
						_check(event.match_time_seconds < 0.1, "boundary fact is stamped before deadline")
	var left := fixture.create(0.1)
	left.start_match()
	fixture.launch_boundary(left, 0.05, true, true, true)
	left.advance_fixed_step(0.2, [])
	_check(left.create_snapshot().away_score == 1 and left.create_snapshot().result.outcome == FormalMatchResult.Outcome.AWAY_WIN, "left goal produces away victory")
	# Identical physical right-goal fact belongs to the other team when its attacking direction flips.
	var teams := TeamDataRepository.new()
	teams.load_all("res://resources/data", fixture.data, fixture.field)
	teams._teams = [TeamDefinition.new("home", "home", "two_one_two", -1), TeamDefinition.new("away", "away", "two_one_two", 1)]
	var swapped := FormalMatchAssembler.new().create_match(fixture.data, teams, fixture.field, fixture.config(0.1), "swapped", 42, "home", "away", false)
	swapped.start_match()
	fixture.launch_boundary(swapped, 0.05)
	swapped.advance_fixed_step(0.2, [])
	_check(swapped.create_snapshot().away_score == 1 and swapped.create_snapshot().right_goal_count == 1, "physical goal count is distinct from team score")
	var save_tail := fixture.create(0.15)
	save_tail.start_match()
	save_tail._player_runtime_system.get_player("formal_player_09").state._set_position(Vector2(23, 10))
	fixture.launch_boundary(save_tail, 0.05)
	save_tail.advance_fixed_step(0.1, [MatchAction.new("formal_player_09", MatchAction.Type.SAVE, Vector2.LEFT)])
	_check(save_tail.create_snapshot().get_player("formal_player_09").action_state == PlayerMatchState.ActionState.SAVING, "save tail is still active after early goal")
	var final := save_tail.advance_fixed_step(0.1, [])
	_check(save_tail.create_snapshot().phase == MatchState.Phase.FINISHED and save_tail.create_snapshot().home_score == 1, "deadline does not wait for save or net tail")
	_check(_count(final, MatchEvent.Type.RESET_COMPLETED) == 0 and save_tail.create_snapshot().round_sequence == 1, "no terminal reset or new round")
	var reset_tie := fixture.create(0.1)
	reset_tie.start_match()
	fixture.launch_boundary(reset_tie, 0.01, false)
	reset_tie.advance_fixed_step(0.05, [])
	reset_tie._settlement_remaining_seconds = 0.05
	var tie_events := reset_tie.advance_fixed_step(0.1, [])
	_check(_count(tie_events, MatchEvent.Type.RESET_COMPLETED) == 0 and reset_tie.create_snapshot().round_sequence == 1, "finish wins when reset deadline coincides")
	var raw := FileAccess.get_file_as_string("res://resources/data/match_configs.csv")
	for value in ["0", "-1", "NaN", "inf"]:
		var file := FileAccess.open("user://formal_invalid_duration.csv", FileAccess.WRITE)
		file.store_string(raw.replace("match_duration_seconds,180.0", "match_duration_seconds," + value))
		file.close()
		_check(not MatchConfigDataRepository.new().load_from_csv("user://formal_invalid_duration.csv").is_success, "invalid duration rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://formal_invalid_duration.csv"))
	for failure in _failures:
		push_error(failure)
	print("Formal deadline failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Counts facts without assuming renderer/UI sequencing.
func _count(events: Array[MatchEvent], type: int) -> int:
	var count := 0
	for event in events:
		count += int(event.event_type == type)
	return count

## Retains every independent deadline failure.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
