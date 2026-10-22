## Checks the real shared menu/presets and hand-anchor fields without rendering frames.
extends SceneTree

var _failures: PackedStringArray = []

## Defers until the test tree is available; no screenshot or render is requested.
func _init() -> void:
	call_deferred("_run")

## Runs three shot sources, all lanes and both F04 outcomes through shared mode wiring.
func _run() -> void:
	var menu := (load("res://scenes/main/game_modes.tscn") as PackedScene).instantiate() as GameModeController
	root.add_child(menu)
	menu.get_node("ModeUi/ModePanel/ModeButtons/KeeperTestButton").pressed.emit()
	_check(menu.current_mode == GameModeController.Mode.GOALKEEPER_TEST, "menu opens keeper mode")
	var bootstrap := menu.get_node("ModeHost").get_child(0) as GameBootstrap
	bootstrap.set_process(false)
	_check((bootstrap.get_node("GoalkeeperControls") as CanvasLayer).visible, "shared controls visible")
	for source in range(3):
		for lane in range(3):
			for success in [true, false]:
				bootstrap.keeper_source = source as GameBootstrap.KeeperShotSource
				bootstrap.keeper_lane = lane
				bootstrap.keeper_sample = 0.49 if success else 0.50
				bootstrap.select_keeper_preset()
				bootstrap.set_process(false)
				var resolved := _until_save(bootstrap)
				_check(resolved != null, "source %d lane %d success %s reaches save" % [source, lane, success])
				if resolved == null:
					continue
				if source == GameBootstrap.KeeperShotSource.HEADER:
					var has_header := false
					for fact in bootstrap.get_event_history():
						has_header = has_header or fact.event_type == MatchEvent.Type.BALL_HEADED
					_check(has_header, "header preset must really head the ball")
				if source == GameBootstrap.KeeperShotSource.AERIAL:
					_check(resolved.goalkeeper_save.height_m > 0.0, "aerial source retains ball height")
				_check(resolved.goalkeeper_save.did_catch == success, "preset injection respected")
				var snapshot := bootstrap._match_simulation.create_snapshot()
				var keeper := snapshot.get_player(bootstrap.demo_opponent_id)
				var environment := bootstrap.get_node("FieldEnvironment") as FieldEnvironment
				var actor := environment.get_node("WorldActors/Players/DemoTeammate") as PlayerActor
				if lane != ShotAim.Lane.CENTER:
					var sprite := actor.get_node("BodySprite") as Sprite2D
					_check(sprite.frame_coords == Vector2i(0, 11 if lane == 0 else 12), "only valid dive frame")
				if success:
					var ball_actor := environment.get_node("WorldActors/Players/Ball") as BallActor
					var sprite := ball_actor.get_node("BallSprite") as Sprite2D
					_check(sprite.global_position.is_equal_approx(actor.get_keeper_hand_world_position()), "held ball on mirrored hands")
					# Both facing directions must mirror the same authored hand point.
					var state := PlayerMatchState.new("anchor", Vector2.ZERO)
					state._set_save_lane(lane)
					state._set_action_state(PlayerMatchState.ActionState.SAVING, PlayerMatchState.ActionPhase.ACTIVE)
					actor.configure_keeper_hands(true, 1.2)
					state._set_facing_direction(Vector2.RIGHT)
					actor.present(PlayerStateSnapshot.new(state), environment._projection)
					var right := actor.get_keeper_hand_world_position() - actor.global_position
					state._set_facing_direction(Vector2.LEFT)
					actor.present(PlayerStateSnapshot.new(state), environment._projection)
					var left := actor.get_keeper_hand_world_position() - actor.global_position
					_check(is_equal_approx(left.x, -right.x) and is_equal_approx(left.y, right.y), "hand anchors mirror on facing change")
					_check(keeper.possession_state == PlayerMatchState.PossessionState.POSSESSING, "keeper owns ball")
				else:
					_check(snapshot.ball.owner_player_id.is_empty(), "miss has no hand ball")
				var first := _trace(bootstrap)
				bootstrap.select_keeper_preset()
				bootstrap.set_process(false)
				_until_save(bootstrap)
				_check(first == _trace(bootstrap), "same preset seed replays facts")
	bootstrap.keeper_starts_down = true
	bootstrap.keeper_source = GameBootstrap.KeeperShotSource.GROUND
	bootstrap.select_keeper_preset()
	bootstrap.set_process(false)
	for step in range(70):
		bootstrap._process(bootstrap.fixed_delta_seconds)
	_check(not _trace(bootstrap).contains("save:"), "initially down keeper never samples")
	bootstrap.select_keeper_preset(false)
	bootstrap.set_process(false)
	_check(bootstrap._match_simulation.create_snapshot().ball.control_attachment == BallMatchState.ControlAttachment.FOOT, "reset removes hand attachment")
	menu.show_mode(GameModeController.Mode.TOUCH_AND_DRIBBLE)
	var touch := menu.get_node("ModeHost").get_child(0) as GameBootstrap
	_check(not (touch.get_node("GoalkeeperControls") as CanvasLayer).visible, "controls hide in other modes")
	menu.free()
	for failure in _failures:
		push_error(failure)
	print("Goalkeeper shared mode failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)

## Stops at the actual contact outcome so assertions can inspect the active pose.
func _until_save(bootstrap: GameBootstrap) -> MatchEvent:
	for step in range(160):
		bootstrap._process(bootstrap.fixed_delta_seconds)
		for event in bootstrap.get_event_history():
			if event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED:
				return event
	return null

## Includes the goal lane and exact F04 sample in the deterministic replay trace.
func _trace(bootstrap: GameBootstrap) -> String:
	var trace := ""
	for event in bootstrap.get_event_history():
		if event.shot_aim != null:
			trace += "aim:%d;" % event.shot_aim.lane
		if event.goalkeeper_save != null and event.event_type == MatchEvent.Type.GOALKEEPER_SAVE_RESOLVED:
			trace += "save:%d:%.2f:%s;" % [event.goalkeeper_save.lane, event.goalkeeper_save.sample, event.goalkeeper_save.did_catch]
	return trace

## Accumulates useful independent failures without hiding later preset results.
func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
