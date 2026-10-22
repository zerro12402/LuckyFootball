## Builds test matches and feeds input through fixed simulation to presentation.
class_name GameBootstrap
extends Node

signal startup_failed(errors: PackedStringArray)
signal game_started(snapshot: MatchStateSnapshot)
signal presentation_frame_ready(
	snapshot: MatchStateSnapshot,
	events: Array[MatchEvent],
	interpolation_alpha: float,
)
signal game_finished(snapshot: MatchStateSnapshot)

enum DemoMode {
	TOUCH_AND_DRIBBLE,
	PASS_AND_SHOOT,
	TACKLE_TEST,
	KNOCKDOWN_TEST,
	ATTACK_RECOIL_TEST,
	AERIAL_JUMP_SHOT_TEST,
	LOFTED_RECEIVE_AERIAL_SHOT_TEST,
	BALL_IMPACT_TEST,
	GOALKEEPER_TEST,
}

enum KeeperShotSource { GROUND, AERIAL, HEADER }
var keeper_lane: int = -1
var keeper_sample: float = -1.0
var keeper_source: KeeperShotSource = KeeperShotSource.GROUND
var keeper_starts_down: bool = false
var _keeper_reaction_requested: bool = false
var _keeper_header_requested: bool = false

enum BallImpactPreset { SWEPT_DEFENDERS, BLOCK_REBOUND, KNOCKDOWN_CONTINUE, KNOCKDOWN_REBOUND, WEAK_SHOT_REBOUND }

var ball_impact_preset: BallImpactPreset = BallImpactPreset.SWEPT_DEFENDERS

const TEST_TEAMMATE_POSITION_M := Vector2(10.0, -2.0)
const TEST_OPPONENT_POSITION_M := Vector2(6.0, 0.0)
const TEST_KNOCKDOWN_OPPONENT_POSITION_M := Vector2(1.05, 0.0)
const TEST_AERIAL_OPPONENT_POSITION_M := Vector2(-1.0, 0.0)
const TEST_LOFTED_RECEIVER_POSITION_M := Vector2(10.0, 0.0)
const AERIAL_RECEIVE_JUMP_LEAD_SECONDS := 0.2
const TEST_OPPONENT_TEAM_ID := "opponent_team"
const TEST_BALL_INITIAL_POSITION_M := Vector2(3.0, 0.0)
const TEST_TEAM_ID := "demo_team"

@export_range(0.001, 0.1, 0.001) var fixed_delta_seconds: float = 1.0 / 60.0
@export var random_seed: int = 1
@export var demo_mode: DemoMode = DemoMode.PASS_AND_SHOOT

@onready var _field_environment: FieldEnvironment = (
	get_node_or_null("FieldEnvironment") as FieldEnvironment
)
@onready var _keyboard_input: KeyboardPlayerInputAdapter = (
	get_node_or_null("KeyboardPlayerInputAdapter") as KeyboardPlayerInputAdapter
)
@onready var _result_hud: MatchResultHud = (
	get_node_or_null("MatchResultHud") as MatchResultHud
)
@onready var _touch_speed_input: LineEdit = get_node_or_null("%TouchSpeedInput") as LineEdit
@onready var _touch_speed_status: Label = get_node_or_null("%TouchSpeedStatus") as Label

var data_repository: DataRepository:
	get:
		return _data_repository

var demo_player_id: String:
	get:
		return _demo_player_id

var demo_opponent_id: String:
	get:
		return _demo_opponent_id

var demo_teammate_id: String:
	get:
		return _demo_teammate_id

var _data_repository: DataRepository
var _field_definition: FieldDefinition
var _match_config: MatchConfigDefinition
var _match_simulation: MatchSimulation
var _game_loop: GameLoop
var _queued_actions: Array[MatchAction] = []
var _pending_aerial_shot: MatchAction
var _pending_aerial_shot_jump_started: bool = false
var _lofted_receiver_jump_requested: bool = false
var _lofted_receiver_jump_started: bool = false
var _demo_player_id: String = ""
var _demo_teammate_id: String = ""
var _demo_opponent_id: String = ""
var _touch_speed_override: int = 0


## Loads static data, wires demo controls, and starts a reproducible match.
func _ready() -> void:
	set_process(false)
	_data_repository = DataRepository.new()
	if not _data_repository.load_all():
		startup_failed.emit(_data_repository.last_errors)
		return

	_field_definition = _data_repository.get_field_by_id("demo_field")
	if _field_definition == null:
		startup_failed.emit(PackedStringArray(["Missing demo_field definition"]))
		return
	_match_config = _data_repository.get_match_config_by_id("demo_match")
	if _match_config == null:
		startup_failed.emit(PackedStringArray(["Missing demo_match configuration"]))
		return
	if _field_environment != null:
		_field_environment.configure(_field_definition)
		_field_environment.configure_keeper_timing(_match_config.keeper_action_duration_seconds)
		_field_environment.configure_hit_stun(_match_config.tackle_hit_stun_seconds)
		_field_environment.configure_tackle_duration(_match_config.tackle_action_duration_seconds)
		_field_environment.configure_knockdown(
			_match_config.knockdown_action_duration_seconds,
			_match_config.knockdown_jump_height_m,
			_match_config.knockdown_landing_animation_seconds,
		)
		_field_environment.configure_teammate_aerial_shot_pose(
			demo_mode == DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST
		)

	var player_definitions := _data_repository.player_definitions
	var required_player_count := 1
	if demo_mode != DemoMode.TOUCH_AND_DRIBBLE:
		required_player_count = 2
	if demo_mode == DemoMode.GOALKEEPER_TEST:
		required_player_count = 3
	if player_definitions.size() < required_player_count:
		startup_failed.emit(PackedStringArray(["Demo players are missing"]))
		return
	_demo_player_id = player_definitions[0].player_id
	_demo_teammate_id = ""
	_demo_opponent_id = ""
	if demo_mode in [DemoMode.PASS_AND_SHOOT, DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST]:
		_demo_teammate_id = player_definitions[1].player_id
	if demo_mode in [
		DemoMode.TACKLE_TEST,
		DemoMode.KNOCKDOWN_TEST,
		DemoMode.ATTACK_RECOIL_TEST,
		DemoMode.AERIAL_JUMP_SHOT_TEST,
		DemoMode.BALL_IMPACT_TEST,
		DemoMode.GOALKEEPER_TEST,
	]:
		_demo_opponent_id = player_definitions[1].player_id
	if demo_mode == DemoMode.GOALKEEPER_TEST:
		_demo_opponent_id = player_definitions[2].player_id
	if _field_environment != null:
		var second_player_id := _demo_teammate_id
		if not _demo_opponent_id.is_empty():
			second_player_id = _demo_opponent_id
		_field_environment.set_presented_players(
			_demo_player_id,
			second_player_id,
			demo_mode in [
				DemoMode.TACKLE_TEST,
				DemoMode.KNOCKDOWN_TEST,
				DemoMode.ATTACK_RECOIL_TEST,
				DemoMode.AERIAL_JUMP_SHOT_TEST,
				DemoMode.BALL_IMPACT_TEST,
				DemoMode.GOALKEEPER_TEST,
			],
			"",
			"",
		)
	if _keyboard_input != null:
		_keyboard_input.action_requested.connect(queue_action)
		if _field_environment != null:
			_keyboard_input.meter_ticks_toggle_requested.connect(
				_field_environment.toggle_meter_ticks
			)
	var lofted_pass_hint := get_node_or_null("LoftedPassHint") as CanvasLayer
	if lofted_pass_hint != null:
		lofted_pass_hint.visible = demo_mode == DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST

	_configure_touch_speed_controls()
	reset_demo()


## Rebuilds demo runtimes with a field-derived opponent goal and fresh input.
func reset_demo() -> void:
	if _data_repository == null or _demo_player_id.is_empty():
		return
	set_process(false)
	_keeper_reaction_requested = false
	_keeper_header_requested = false
	_queued_actions.clear()
	_pending_aerial_shot = null
	_pending_aerial_shot_jump_started = false
	_lofted_receiver_jump_requested = false
	_lofted_receiver_jump_started = false
	var melee_outcome := MatchSimulation.MeleeOutcome.TARGET_KNOCKED_DOWN
	if demo_mode == DemoMode.ATTACK_RECOIL_TEST:
		melee_outcome = MatchSimulation.MeleeOutcome.ATTACKER_RECOILS
	if demo_mode == DemoMode.BALL_IMPACT_TEST:
		random_seed = 2 if ball_impact_preset == BallImpactPreset.KNOCKDOWN_REBOUND else 1
	var aim_sampler := Callable()
	var save_sampler := Callable()
	if demo_mode == DemoMode.BALL_IMPACT_TEST:
		aim_sampler = func() -> int: return ShotAim.Lane.CENTER
	if demo_mode == DemoMode.GOALKEEPER_TEST:
		if keeper_lane >= 0:
			aim_sampler = func() -> int: return keeper_lane
		if keeper_sample >= 0.0:
			save_sampler = func() -> float: return keeper_sample
	_match_simulation = MatchSimulation.new(
		random_seed, _match_config, _field_definition, melee_outcome,
		Callable(), Callable(), aim_sampler, save_sampler
	)
	var opponent_goal_center_m := Vector2(_field_definition.length_m * 0.5, 0.0)
	var did_register_goal := _match_simulation.register_team_attacking_goal(
		TEST_TEAM_ID,
		opponent_goal_center_m,
	)
	assert(did_register_goal, "Demo team requires an opponent goal before play")
	if demo_mode == DemoMode.GOALKEEPER_TEST:
		_demo_teammate_id = (_data_repository.player_definitions[1].player_id
			if keeper_source == KeeperShotSource.HEADER else "")
	var demo_player := _data_repository.get_player_by_id(_demo_player_id)
	if demo_mode == DemoMode.TOUCH_AND_DRIBBLE and _touch_speed_override > 0:
		# Construct an explicit test definition; the repository's CSV definition remains unchanged.
		demo_player = PlayerDefinition.new(demo_player.player_id, demo_player.display_name,
			demo_player.default_role, _touch_speed_override, demo_player.shooting,
			demo_player.strength, demo_player.technique, demo_player.stamina,
			demo_player.tackling, demo_player.goalkeeping, demo_player.trait_ids, demo_player.visual_id)
	var player_position_m := Vector2.ZERO
	var shooting := demo_player.shooting
	if demo_mode == DemoMode.BALL_IMPACT_TEST:
		player_position_m = opponent_goal_center_m - Vector2(10.0, 0.0)
		shooting = 80 # Explicit test context; CSV attribute integration is a separate feature.
	if demo_mode == DemoMode.GOALKEEPER_TEST:
		player_position_m = Vector2(11.0 if keeper_source == KeeperShotSource.HEADER else 15.0, 0.0)
	var did_register_player := _match_simulation.register_player_from_definition(
		demo_player,
		player_position_m,
		TEST_TEAM_ID,
		false,
		shooting,
	)
	assert(did_register_player, "Demo player must register before the match starts")
	if not _demo_teammate_id.is_empty():
		var demo_teammate := _data_repository.get_player_by_id(_demo_teammate_id)
		var teammate_position_m := TEST_TEAMMATE_POSITION_M
		if demo_mode == DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST:
			teammate_position_m = TEST_LOFTED_RECEIVER_POSITION_M
		if demo_mode == DemoMode.GOALKEEPER_TEST:
			teammate_position_m = Vector2(20.0, 0.0)
		var did_register_teammate := _match_simulation.register_player_from_definition(
			demo_teammate,
			teammate_position_m,
			TEST_TEAM_ID,
		)
		assert(did_register_teammate, "Demo teammate must register before the match starts")
	if not _demo_opponent_id.is_empty():
		var opponent := _data_repository.get_player_by_id(_demo_opponent_id)
		var opponent_position_m := TEST_OPPONENT_POSITION_M
		var opponent_strength := opponent.strength
		if demo_mode in [DemoMode.KNOCKDOWN_TEST, DemoMode.ATTACK_RECOIL_TEST]:
			opponent_position_m = TEST_KNOCKDOWN_OPPONENT_POSITION_M
		elif demo_mode == DemoMode.AERIAL_JUMP_SHOT_TEST:
			opponent_position_m = TEST_AERIAL_OPPONENT_POSITION_M
		elif demo_mode == DemoMode.BALL_IMPACT_TEST:
			opponent_position_m = opponent_goal_center_m - Vector2(6.0, 0.0)
			opponent_strength = 60
			if ball_impact_preset == BallImpactPreset.BLOCK_REBOUND:
				opponent_strength = 80
			elif ball_impact_preset == BallImpactPreset.WEAK_SHOT_REBOUND:
				opponent_strength = 90
		if demo_mode == DemoMode.GOALKEEPER_TEST:
			opponent_position_m = Vector2(23.0, 0.0)
		assert(_match_simulation.register_player_from_definition(
			opponent, opponent_position_m, TEST_OPPONENT_TEAM_ID,
			demo_mode == DemoMode.GOALKEEPER_TEST,
			-1, opponent_strength,
		))
		if demo_mode == DemoMode.GOALKEEPER_TEST and keeper_starts_down:
			_match_simulation._player_runtime_system.get_player(_demo_opponent_id).state_machine.start_knockdown(_match_config)
		if demo_mode == DemoMode.BALL_IMPACT_TEST:
			_register_ball_impact_extra_defender(opponent_goal_center_m)
	var initial_ball_position_m := TEST_BALL_INITIAL_POSITION_M
	if demo_mode in [DemoMode.TACKLE_TEST, DemoMode.AERIAL_JUMP_SHOT_TEST]:
		initial_ball_position_m = Vector2(0.5, 0.0)
	elif demo_mode == DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST:
		initial_ball_position_m = Vector2(0.55, 0.0)
	elif demo_mode in [DemoMode.BALL_IMPACT_TEST, DemoMode.GOALKEEPER_TEST]:
		initial_ball_position_m = player_position_m + Vector2(0.55, 0.0)
	elif demo_mode in [DemoMode.KNOCKDOWN_TEST, DemoMode.ATTACK_RECOIL_TEST]:
		initial_ball_position_m = Vector2(1.6, 0.0)
	var did_register_ball := _match_simulation.register_ball(
		initial_ball_position_m,
	)
	assert(did_register_ball, "Demo ball must register before the match starts")
	var tackle_ai: TackleChaseAI
	var additional_tackle_ais: Array[TackleChaseAI] = []
	if not _demo_opponent_id.is_empty():
		var defender_goal_center_m := Vector2(-_field_definition.length_m * 0.5, 0.0)
		assert(_match_simulation.register_team_attacking_goal(
			TEST_OPPONENT_TEAM_ID, defender_goal_center_m
		))
		if demo_mode == DemoMode.TACKLE_TEST:
			tackle_ai = TackleChaseAI.new(
				_demo_opponent_id, _demo_player_id, _match_config, defender_goal_center_m,
				_match_simulation._player_runtime_system.get_player(_demo_player_id).state_machine.movement_speed_mps
			)
			additional_tackle_ais.append(TackleChaseAI.new(
				_demo_player_id, _demo_opponent_id, _match_config, opponent_goal_center_m,
				_match_simulation._player_runtime_system.get_player(_demo_opponent_id).state_machine.movement_speed_mps))
	_game_loop = GameLoop.new(
		_match_simulation, fixed_delta_seconds,
		GameLoop.DEFAULT_MAX_FRAME_DELTA_SECONDS,
		GameLoop.DEFAULT_MAX_STEPS_PER_FRAME, tackle_ai, additional_tackle_ais
	)
	if _keyboard_input != null:
		_keyboard_input.configure(
			_demo_player_id,
			_demo_teammate_id,
			_demo_opponent_id,
			demo_mode == DemoMode.AERIAL_JUMP_SHOT_TEST,
			demo_mode in [DemoMode.BALL_IMPACT_TEST, DemoMode.GOALKEEPER_TEST],
		)
		if demo_mode == DemoMode.TACKLE_TEST:
			_keyboard_input.set_process(false)

	var did_start := _match_simulation.start_match()
	assert(did_start, "A new match must start from the ready phase")
	# Begin the aerial test with legal possession so Space works immediately.
	if demo_mode == DemoMode.AERIAL_JUMP_SHOT_TEST:
		_match_simulation.advance_fixed_step(fixed_delta_seconds, [])
	if demo_mode == DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST:
		_match_simulation.advance_fixed_step(fixed_delta_seconds, [])
	if demo_mode in [DemoMode.BALL_IMPACT_TEST, DemoMode.GOALKEEPER_TEST]:
		_match_simulation.advance_fixed_step(fixed_delta_seconds, [])
	if demo_mode == DemoMode.GOALKEEPER_TEST and _field_environment != null:
		_field_environment.set_presented_players(_demo_player_id, _demo_opponent_id,
			true, _demo_teammate_id)
	var initial_snapshot := _match_simulation.create_snapshot()
	game_started.emit(initial_snapshot)
	_refresh_touch_speed_controls()
	var tackle_controls := get_node_or_null("TackleTestControls") as CanvasLayer
	if tackle_controls != null:
		tackle_controls.visible = demo_mode == DemoMode.TACKLE_TEST
		if tackle_controls.visible:
			(get_node("%TackleTestStatus") as Label).text = "双方 AI 自动带球与抢断\n失败时持球者起跳保球；~ 重置，M 刻度"
	_publish_frame(0.0)
	set_process(true)


## Wires temporary speed inputs only in the existing touch-and-dribble test mode.
func _configure_touch_speed_controls() -> void:
	var panel := get_node_or_null("TouchSpeedControls") as CanvasLayer
	if panel == null:
		return
	panel.visible = demo_mode == DemoMode.TOUCH_AND_DRIBBLE
	if not panel.visible:
		return
	var apply_button := get_node("%TouchSpeedApplyButton") as Button
	apply_button.pressed.connect(_apply_touch_speed_input)
	_touch_speed_input.text_submitted.connect(func(_text: String) -> void: _apply_touch_speed_input())


## Sends the entered value through validation instead of editing live simulation state.
func _apply_touch_speed_input() -> void:
	apply_touch_speed_for_test(_touch_speed_input.text)


## Validates an explicit test override and rebuilds the match while keeping CSV data read-only.
func apply_touch_speed_for_test(raw_value: String) -> bool:
	if demo_mode != DemoMode.TOUCH_AND_DRIBBLE or _data_repository == null:
		return false
	var value := raw_value.strip_edges()
	if not value.is_valid_int() or value.to_int() < 75 or value.to_int() > 100:
		if _touch_speed_status != null:
			_touch_speed_status.text = "请输入 75～100 的整数；当前速度未改变"
		return false
	_touch_speed_override = value.to_int()
	reset_demo()
	if _touch_speed_input != null:
		_touch_speed_input.release_focus()
	return true


## Keeps the editable value and displayed physical speed aligned after any test reset.
func _refresh_touch_speed_controls() -> void:
	if demo_mode != DemoMode.TOUCH_AND_DRIBBLE or _touch_speed_input == null:
		return
	var player := _match_simulation._player_runtime_system.get_player(_demo_player_id)
	_touch_speed_input.text = str(player.speed_attribute)
	_touch_speed_status.text = "速度 %d → 无球 %.2f m/s，带球 %.2f m/s" % [
		player.speed_attribute, player.state_machine.movement_speed_mps,
		player.state_machine.movement_speed_mps * PlayerStateMachine.POSSESSION_MOVEMENT_SPEED_MULTIPLIER]


## Builds the optional second target and reuses the existing four actor slots.
func _register_ball_impact_extra_defender(goal: Vector2) -> void:
	var extra_id := ""
	if ball_impact_preset == BallImpactPreset.SWEPT_DEFENDERS:
		extra_id = _demo_opponent_id + "_second"
		var definition := _data_repository.get_player_by_id(_demo_opponent_id)
		assert(_match_simulation.register_player(extra_id, goal - Vector2(3.0, 0.0),
			PlayerRuntime.calculate_movement_speed_mps(definition.speed,
				_match_config.player_speed_at_100_mps), TEST_OPPONENT_TEAM_ID,
			1, 60, 50, false, definition.speed))
	if _field_environment != null:
		_field_environment.set_presented_players(_demo_player_id, _demo_opponent_id,
			true, extra_id)


## Replays one selected impact setup with its real fixed-seed random stream.
func select_ball_impact_preset(preset: BallImpactPreset, start_shot: bool = true) -> void:
	assert(demo_mode == DemoMode.BALL_IMPACT_TEST)
	ball_impact_preset = preset
	reset_demo()
	if start_shot:
		queue_action(MatchAction.new(_demo_player_id, MatchAction.Type.SHOOT))


## Exposes a copy of meaningful simulation events to the shared preset panel.
func get_event_history() -> Array[MatchEvent]:
	if _match_simulation == null:
		return []
	return _match_simulation.get_event_history()

## Advances and presents the match from the display frame clock.
func _process(delta: float) -> void:
	_publish_frame(delta)


## Buffers commands for the next fixed step and holds early aerial shots until airborne.
func queue_action(action: MatchAction) -> void:
	assert(action != null, "Cannot queue a null MatchAction")
	if demo_mode == DemoMode.TACKLE_TEST and not action.player_id.is_empty():
		return # AI commands enter through GameLoop; keyboard retains only round controls.
	if (
		action.action_type == MatchAction.Type.RESTART_TEST
		and _match_simulation != null
		and not _match_simulation.is_running()
	):
		reset_demo()
		return
	if (
		demo_mode in [
			DemoMode.AERIAL_JUMP_SHOT_TEST,
			DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST,
			DemoMode.GOALKEEPER_TEST,
		]
		and action.action_type == MatchAction.Type.SHOOT
		and _match_simulation != null
	):
		var player := _match_simulation.create_snapshot().get_player(action.player_id)
		var is_takeoff := (
			player != null and player.jump_phase == PlayerMatchState.JumpPhase.TAKEOFF
		)
		var has_queued_jump := false
		for queued_action in _queued_actions:
			if (
				queued_action.action_type == MatchAction.Type.JUMP
				and queued_action.player_id == action.player_id
			):
				has_queued_jump = true
				break
		if is_takeoff or has_queued_jump:
			_pending_aerial_shot = action
			_pending_aerial_shot_jump_started = is_takeoff
			return
	_queued_actions.append(action)


## Pauses the active match when one exists.
func pause_match() -> bool:
	if _match_simulation == null:
		return false
	return _match_simulation.pause_match()


## Resumes the match and refreshes movement input.
func resume_match() -> bool:
	if _match_simulation == null:
		return false
	var did_resume := _match_simulation.resume_match()
	if did_resume and _keyboard_input != null:
		_keyboard_input.force_resend()
	return did_resume


## Publishes the final frame before stopping updates.
func finish_match() -> bool:
	if _match_simulation == null or not _match_simulation.finish_match():
		return false
	_publish_frame(0.0)
	set_process(false)
	game_finished.emit(_match_simulation.create_snapshot())
	return true


## Predicts the directed pass contact and submits one early jump through MatchAction.
func _queue_lofted_receiver_jump(frame_actions: Array[MatchAction]) -> void:
	if demo_mode != DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST or (
		_lofted_receiver_jump_requested
	):
		return
	var snapshot := _match_simulation.create_snapshot()
	var ball := snapshot.ball
	var receiver := snapshot.get_player(_demo_teammate_id)
	if receiver == null or ball.motion_state != BallMatchState.MotionState.IN_FLIGHT or (
		ball.target_player_id != _demo_teammate_id or ball.height_m <= 0.0
	):
		return
	if receiver.jump_phase != PlayerMatchState.JumpPhase.NONE or (
		receiver.action_state != PlayerMatchState.ActionState.IDLE
		or receiver.possession_state != PlayerMatchState.PossessionState.NO_BALL
	):
		return
	var speed_mps := ball.velocity_mps.length()
	if speed_mps <= 0.0:
		return
	var flight_direction := ball.velocity_mps / speed_mps
	var to_receiver := receiver.position_m - ball.position_m
	var along_path_m := to_receiver.dot(flight_direction)
	var cross_path_m := (to_receiver - flight_direction * along_path_m).length()
	if along_path_m <= 0.0 or (
		cross_path_m > BallRuntimeSystem.DEFAULT_POSSESSION_RADIUS_M
	):
		return
	var seconds_until_contact := maxf(
		(along_path_m - BallRuntimeSystem.DEFAULT_POSSESSION_RADIUS_M) / speed_mps,
		0.0,
	)
	if seconds_until_contact > AERIAL_RECEIVE_JUMP_LEAD_SECONDS or (
		seconds_until_contact < _match_config.jump_takeoff_seconds
	):
		return
	frame_actions.append(MatchAction.new(_demo_teammate_id, MatchAction.Type.JUMP))
	_lofted_receiver_jump_requested = true


## Clears the request after an observed jump fully lands, not while it is still queued.
func _finish_lofted_receiver_jump(snapshot: MatchStateSnapshot) -> void:
	if not _lofted_receiver_jump_requested:
		return
	var receiver := snapshot.get_player(_demo_teammate_id)
	if receiver == null:
		return
	if receiver.jump_phase != PlayerMatchState.JumpPhase.NONE:
		_lofted_receiver_jump_started = true
	elif _lofted_receiver_jump_started:
		_lofted_receiver_jump_requested = false
		_lofted_receiver_jump_started = false


## Releases queued aerial shots and presents the fixed-loop snapshot.
func _publish_frame(frame_delta_seconds: float) -> void:
	var frame_actions: Array[MatchAction] = _queued_actions.duplicate()
	_queued_actions.clear()
	_queue_lofted_receiver_jump(frame_actions)
	_queue_keeper_test_actions(frame_actions, frame_delta_seconds)
	if _pending_aerial_shot != null:
		var snapshot := _match_simulation.create_snapshot()
		var player := snapshot.get_player(_pending_aerial_shot.player_id)
		if player != null and player.jump_phase in [
			PlayerMatchState.JumpPhase.TAKEOFF,
			PlayerMatchState.JumpPhase.AIRBORNE,
		]:
			_pending_aerial_shot_jump_started = true
		if player == null or snapshot.ball.owner_player_id != _pending_aerial_shot.player_id:
			_pending_aerial_shot = null
		elif player.jump_phase == PlayerMatchState.JumpPhase.AIRBORNE:
			frame_actions.append(_pending_aerial_shot)
			_pending_aerial_shot = null
		# Keep waiting through NONE while GameLoop buffers a jump at high display rates.
		elif _pending_aerial_shot_jump_started and player.jump_phase in [
			PlayerMatchState.JumpPhase.NONE,
			PlayerMatchState.JumpPhase.LANDING,
		]:
			_pending_aerial_shot = null
		if _pending_aerial_shot == null:
			_pending_aerial_shot_jump_started = false
	var frame_result := _game_loop.advance_frame(frame_delta_seconds, frame_actions)
	_finish_lofted_receiver_jump(frame_result.snapshot)
	for event in frame_result.events:
		if demo_mode == DemoMode.TACKLE_TEST and event.tackle_contest != null:
			var status := get_node_or_null("%TackleTestStatus") as Label
			if status != null:
				status.text = "双方 AI 自动带球与抢断\n抢断 %d / 技巧 %d：成功率 %.1f%%\n%s；~ 重置，M 刻度" % [
					event.tackle_contest.tackling, event.tackle_contest.technique,
					event.tackle_contest.probability * 100.0,
					"抢断成功，交换球权" if event.tackle_contest.succeeded else "抢断失败，持球者起跳保球"]
		if (
			demo_mode == DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST
			and event.event_type == MatchEvent.Type.BALL_PASS_RECEIVED
			and event.subject_id == _demo_teammate_id
		):
			queue_action(MatchAction.new(_demo_teammate_id, MatchAction.Type.SHOOT))
		if event.event_type == MatchEvent.Type.RESET_COMPLETED:
			if demo_mode == DemoMode.TACKLE_TEST:
				var status := get_node_or_null("%TackleTestStatus") as Label
				if status != null:
					status.text = "双方 AI 自动带球与抢断\n新一轮；~ 重置，M 刻度"
			_keeper_reaction_requested = false
			_keeper_header_requested = false
			_queued_actions.clear()
			_pending_aerial_shot = null
			_pending_aerial_shot_jump_started = false
			_lofted_receiver_jump_requested = false
			_lofted_receiver_jump_started = false
			if _keyboard_input != null:
				_keyboard_input.configure(
					_demo_player_id,
					_demo_teammate_id,
					_demo_opponent_id,
					demo_mode == DemoMode.AERIAL_JUMP_SHOT_TEST,
					demo_mode in [DemoMode.BALL_IMPACT_TEST, DemoMode.GOALKEEPER_TEST],
				)
				if demo_mode == DemoMode.TACKLE_TEST:
					_keyboard_input.set_process(false)
			break
	if _field_environment != null:
		_field_environment.present(frame_result.snapshot)
		_field_environment.present_events(frame_result.events)
	if _result_hud != null:
		_result_hud.present(frame_result.snapshot, frame_result.events)
	presentation_frame_ready.emit(
		frame_result.snapshot,
		frame_result.events,
		frame_result.interpolation_alpha,
	)


## Rebuilds selected test inputs; all movement, kicking and saving still use MatchAction.
func select_keeper_preset(start_shot: bool = true) -> void:
	assert(demo_mode == DemoMode.GOALKEEPER_TEST)
	reset_demo()
	if not start_shot:
		return
	if keeper_source == KeeperShotSource.HEADER:
		queue_action(MatchAction.new(_demo_player_id, MatchAction.Type.PASS, Vector2.ZERO, _demo_teammate_id))
	else:
		if keeper_source == KeeperShotSource.AERIAL:
			queue_action(MatchAction.new(_demo_player_id, MatchAction.Type.JUMP))
		queue_action(MatchAction.new(_demo_player_id, MatchAction.Type.SHOOT))


## Test-only reaction submits a matching intention after real release, never decides success.
func _queue_keeper_test_actions(actions: Array[MatchAction], frame_seconds: float) -> void:
	if demo_mode != DemoMode.GOALKEEPER_TEST:
		return
	var ball := _match_simulation.create_snapshot().ball
	if ball == null:
		return
	if ball.flight_kind == BallMatchState.FlightKind.PASS and not _keeper_header_requested:
		actions.append(MatchAction.new(_demo_teammate_id, MatchAction.Type.HEADER_SHOT))
		_keeper_header_requested = true
	if ball.flight_kind == BallMatchState.FlightKind.SHOT and not _keeper_reaction_requested:
		var aim := ball.shot_aim
		if aim != null and _is_keeper_contact_imminent(ball, aim, frame_seconds):
			actions.append(MatchAction.new(_demo_opponent_id, MatchAction.Type.SAVE,
				Vector2(-1.0, float(aim.lane - ShotAim.Lane.CENTER))))
			_keeper_reaction_requested = true


## Predicts the first planar hand contact so the demo does not dive immediately at release.
func _is_keeper_contact_imminent(ball: BallStateSnapshot, aim: ShotAim, frame_seconds: float) -> bool:
	var keeper := _match_simulation.create_snapshot().get_player(_demo_opponent_id)
	if keeper == null or ball.velocity_mps.is_zero_approx():
		return false
	var hand := keeper.position_m + keeper.facing_direction * _match_config.keeper_hand_forward_m
	hand.y += float(aim.lane - ShotAim.Lane.CENTER) * _match_config.keeper_hand_lateral_m
	var offset := hand - ball.position_m
	var direction := ball.velocity_mps.normalized()
	var along := offset.dot(direction)
	var radius := _match_config.keeper_contact_radius_m + _match_config.ball_radius_m
	var perpendicular_squared := maxf(offset.length_squared() - along * along, 0.0)
	if along < 0.0 or perpendicular_squared > radius * radius:
		return false
	var contact_distance := maxf(along - sqrt(radius * radius - perpendicular_squared), 0.0)
	var speed := ball.velocity_mps.length()
	var discriminant := speed * speed - 2.0 * _match_config.shot_ground_deceleration_mps2 * contact_distance
	if discriminant < 0.0:
		return false
	var seconds := (speed - sqrt(discriminant)) / _match_config.shot_ground_deceleration_mps2
	return seconds <= maxf(frame_seconds, fixed_delta_seconds)
