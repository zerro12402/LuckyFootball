## Bridges variable display frames to deterministic match steps without scene-tree dependencies.
class_name GameLoop
extends RefCounted

const DEFAULT_FIXED_DELTA_SECONDS := 1.0 / 60.0
const DEFAULT_MAX_FRAME_DELTA_SECONDS := 0.25
const DEFAULT_MAX_STEPS_PER_FRAME := 8
const STEP_EPSILON := 0.0000001

var _simulation: MatchSimulation
var _fixed_delta_seconds: float
var _max_frame_delta_seconds: float
var _max_steps_per_frame: int
var _accumulator_seconds: float = 0.0
var _pending_actions: Array[MatchAction] = []
var _tackle_ais: Array[TackleChaseAI] = []
var _action_sources: Array[MatchActionSource] = []
var _control_revision: int = -1
var _match_id: String = ""
var _pending_stamp: MatchStateSnapshot


## Validates the timing limits shared by every frame of this match.
func _init(
	simulation: MatchSimulation,
	fixed_delta_seconds: float = DEFAULT_FIXED_DELTA_SECONDS,
	max_frame_delta_seconds: float = DEFAULT_MAX_FRAME_DELTA_SECONDS,
	max_steps_per_frame: int = DEFAULT_MAX_STEPS_PER_FRAME,
	tackle_ai: TackleChaseAI = null,
	additional_tackle_ais: Array[TackleChaseAI] = [],
	action_sources: Array[MatchActionSource] = [],
) -> void:
	assert(simulation != null, "GameLoop requires a MatchSimulation")
	assert(fixed_delta_seconds > 0.0, "Fixed delta must be positive")
	assert(max_frame_delta_seconds > 0.0, "Maximum frame delta must be positive")
	assert(max_steps_per_frame > 0, "Maximum steps per frame must be positive")
	_simulation = simulation
	_fixed_delta_seconds = fixed_delta_seconds
	_max_frame_delta_seconds = max_frame_delta_seconds
	_max_steps_per_frame = max_steps_per_frame
	if tackle_ai != null:
		_tackle_ais.append(tackle_ai)
	_tackle_ais.append_array(additional_tackle_ais)
	_action_sources.append_array(_tackle_ais)
	_action_sources.append_array(action_sources)


## Calls authorized sources once per fixed step against one snapshot, then revalidates the batch.
func advance_frame(frame_delta_seconds: float, new_actions: Array[MatchAction]) -> MatchFrameResult:
	assert(is_finite(frame_delta_seconds) and frame_delta_seconds >= 0.0)
	var frame_events := _simulation.drain_lifecycle_events()
	var snapshot := _simulation.create_snapshot()
	_sync_control(snapshot)
	var executed_steps := 0
	if _simulation.is_running():
		if snapshot.can_decide_player_actions:
			_pending_actions.append_array(new_actions)
			if not new_actions.is_empty():
				_pending_stamp = snapshot
		_accumulator_seconds += minf(frame_delta_seconds, _max_frame_delta_seconds)
		while _simulation.is_running() and _accumulator_seconds + STEP_EPSILON >= _fixed_delta_seconds and executed_steps < _max_steps_per_frame:
			snapshot = _simulation.create_snapshot()
			var actions: Array[MatchAction] = []
			if snapshot.can_decide_player_actions:
				if _pending_stamp != null and MatchActionBatch.new(_pending_stamp, []).matches(snapshot):
					actions.append_array(_pending_actions)
				for source in _action_sources:
					actions.append_array(_stable_actions(source.propose_actions(snapshot)))
			_pending_actions.clear()
			_pending_stamp = null
			var batch := MatchActionBatch.new(snapshot, actions)
			if _simulation.is_formal():
				frame_events.append_array(_simulation.advance_action_batch(_fixed_delta_seconds, batch))
			else:
				frame_events.append_array(_simulation.advance_fixed_step(_fixed_delta_seconds, actions))
			_accumulator_seconds = maxf(_accumulator_seconds - _fixed_delta_seconds, 0.0)
			executed_steps += 1
			_sync_control(_simulation.create_snapshot())
	else:
		reset_timing()
	var alpha := 0.0
	if _simulation.is_running():
		alpha = clampf(_accumulator_seconds / _fixed_delta_seconds, 0.0, 1.0)
	frame_events.append_array(_simulation.drain_lifecycle_events())
	return MatchFrameResult.new(_simulation.create_snapshot(), frame_events, executed_steps, alpha)

## Invalidates caches even when pause/resume happened between displayed frames.
func _sync_control(snapshot: MatchStateSnapshot) -> void:
	if snapshot.control_revision == _control_revision and snapshot.match_id == _match_id:
		return
	_control_revision = snapshot.control_revision
	_match_id = snapshot.match_id
	reset_timing()
	for source in _action_sources:
		source.invalidate_control(snapshot)

## Sorts by player ID while preserving command order within one player's source output.
func _stable_actions(actions: Array[MatchAction]) -> Array[MatchAction]:
	var players: Dictionary[String, Array] = {}
	for action in actions:
		if action == null:
			continue
		if not players.has(action.player_id):
			players[action.player_id] = []
		players[action.player_id].append(action)
	var ids := players.keys()
	ids.sort()
	var ordered: Array[MatchAction] = []
	for id in ids:
		ordered.append_array(players[id])
	return ordered


## Discards unfinished frame time and commands when starting a fresh timing sequence.
func reset_timing() -> void:
	_accumulator_seconds = 0.0
	_pending_actions.clear()
	_pending_stamp = null
