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
}

enum BallImpactPreset { SWEPT_DEFENDERS, BLOCK_REBOUND, KNOCKDOWN_CONTINUE, KNOCKDOWN_REBOUND, WEAK_SHOT_REBOUND }

var ball_impact_preset: BallImpactPreset = BallImpactPreset.SWEPT_DEFENDERS

const TEST_PLAYER_MOVEMENT_SPEED_MPS := 5.0
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
	]:
		_demo_opponent_id = player_definitions[1].player_id
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

	reset_demo()


## Rebuilds demo runtimes with a field-derived opponent goal and fresh input.
func reset_demo() -> void:
	if _data_repository == null or _demo_player_id.is_empty():
		return
	set_process(false)
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
	_match_simulation = MatchSimulation.new(
		random_seed, _match_config, _field_definition, melee_outcome
	)
	var opponent_goal_center_m := Vector2(_field_definition.length_m * 0.5, 0.0)
	var did_register_goal := _match_simulation.register_team_attacking_goal(
		TEST_TEAM_ID,
		opponent_goal_center_m,
	)
	assert(did_register_goal, "Demo team requires an opponent goal before play")
	var demo_player := _data_repository.get_player_by_id(_demo_player_id)
	var player_position_m := Vector2.ZERO
	var shooting := demo_player.shooting
	if demo_mode == DemoMode.BALL_IMPACT_TEST:
		player_position_m = opponent_goal_center_m - Vector2(10.0, 0.0)
		shooting = 80 # Explicit test context; CSV attribute integration is a separate feature.
	var did_register_player := _match_simulation.register_player(
		_demo_player_id,
		player_position_m,
		TEST_PLAYER_MOVEMENT_SPEED_MPS,
		TEST_TEAM_ID,
		shooting,
		demo_player.strength,
		demo_player.technique,
	)
	assert(did_register_player, "Demo player must register before the match starts")
	if not _demo_teammate_id.is_empty():
		var demo_teammate := _data_repository.get_player_by_id(_demo_teammate_id)
		var teammate_position_m := TEST_TEAMMATE_POSITION_M
		if demo_mode == DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST:
			teammate_position_m = TEST_LOFTED_RECEIVER_POSITION_M
		var did_register_teammate := _match_simulation.register_player(
			_demo_teammate_id,
			teammate_position_m,
			TEST_PLAYER_MOVEMENT_SPEED_MPS,
			TEST_TEAM_ID,
			demo_teammate.shooting,
			demo_teammate.strength,
			demo_teammate.technique,
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
		assert(_match_simulation.register_player(
			_demo_opponent_id, opponent_position_m,
			TEST_PLAYER_MOVEMENT_SPEED_MPS, TEST_OPPONENT_TEAM_ID,
			opponent.shooting, opponent_strength, opponent.technique,
		))
		if demo_mode == DemoMode.BALL_IMPACT_TEST:
			_register_ball_impact_extra_defender(opponent_goal_center_m)
	var initial_ball_position_m := TEST_BALL_INITIAL_POSITION_M
	if demo_mode in [DemoMode.TACKLE_TEST, DemoMode.AERIAL_JUMP_SHOT_TEST]:
		initial_ball_position_m = Vector2(0.5, 0.0)
	elif demo_mode == DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST:
		initial_ball_position_m = Vector2(0.55, 0.0)
	elif demo_mode == DemoMode.BALL_IMPACT_TEST:
		initial_ball_position_m = player_position_m + Vector2(0.55, 0.0)
	elif demo_mode in [DemoMode.KNOCKDOWN_TEST, DemoMode.ATTACK_RECOIL_TEST]:
		initial_ball_position_m = Vector2(1.6, 0.0)
	var did_register_ball := _match_simulation.register_ball(
		initial_ball_position_m,
	)
	assert(did_register_ball, "Demo ball must register before the match starts")
	var tackle_ai: TackleChaseAI
	if not _demo_opponent_id.is_empty():
		var defender_goal_center_m := Vector2(-_field_definition.length_m * 0.5, 0.0)
		assert(_match_simulation.register_team_attacking_goal(
			TEST_OPPONENT_TEAM_ID, defender_goal_center_m
		))
		if demo_mode == DemoMode.TACKLE_TEST:
			tackle_ai = TackleChaseAI.new(
				_demo_opponent_id, _demo_player_id, _match_config, defender_goal_center_m
			)
	_game_loop = GameLoop.new(
		_match_simulation, fixed_delta_seconds,
		GameLoop.DEFAULT_MAX_FRAME_DELTA_SECONDS,
		GameLoop.DEFAULT_MAX_STEPS_PER_FRAME, tackle_ai
	)
	if _keyboard_input != null:
		_keyboard_input.configure(
			_demo_player_id,
			_demo_teammate_id,
			_demo_opponent_id,
			demo_mode == DemoMode.AERIAL_JUMP_SHOT_TEST,
			demo_mode == DemoMode.BALL_IMPACT_TEST,
		)

	var did_start := _match_simulation.start_match()
	assert(did_start, "A new match must start from the ready phase")
	# Begin the aerial test with legal possession so Space works immediately.
	if demo_mode == DemoMode.AERIAL_JUMP_SHOT_TEST:
		_match_simulation.advance_fixed_step(fixed_delta_seconds, [])
	if demo_mode == DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST:
		_match_simulation.advance_fixed_step(fixed_delta_seconds, [])
	if demo_mode == DemoMode.BALL_IMPACT_TEST:
		_match_simulation.advance_fixed_step(fixed_delta_seconds, [])
	var initial_snapshot := _match_simulation.create_snapshot()
	game_started.emit(initial_snapshot)
	_publish_frame(0.0)
	set_process(true)


## Builds the optional second target and reuses the existing four actor slots.
func _register_ball_impact_extra_defender(goal: Vector2) -> void:
	var extra_id := ""
	if ball_impact_preset == BallImpactPreset.SWEPT_DEFENDERS:
		extra_id = _demo_opponent_id + "_second"
		assert(_match_simulation.register_player(extra_id, goal - Vector2(3.0, 0.0),
			TEST_PLAYER_MOVEMENT_SPEED_MPS, TEST_OPPONENT_TEAM_ID, 1, 60, 50))
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
		if (
			demo_mode == DemoMode.LOFTED_RECEIVE_AERIAL_SHOT_TEST
			and event.event_type == MatchEvent.Type.BALL_PASS_RECEIVED
			and event.subject_id == _demo_teammate_id
		):
			queue_action(MatchAction.new(_demo_teammate_id, MatchAction.Type.SHOOT))
		if event.event_type == MatchEvent.Type.RESET_COMPLETED:
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
					demo_mode == DemoMode.BALL_IMPACT_TEST,
				)
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
