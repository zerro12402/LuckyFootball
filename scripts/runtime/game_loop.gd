class_name GameLoop
extends RefCounted

const DEFAULT_FIXED_DELTA_SECONDS := 1.0 / 60.0
const DEFAULT_MAX_FRAME_DELTA_SECONDS := 0.25
const DEFAULT_MAX_STEPS_PER_FRAME := 8
const STEP_EPSILON := 0.0000001

var _controller: MatchController
var _fixed_delta_seconds: float
var _max_frame_delta_seconds: float
var _max_steps_per_frame: int
var _accumulator_seconds: float = 0.0
var _pending_actions: Array[MatchAction] = []


func _init(
	controller: MatchController,
	fixed_delta_seconds: float = DEFAULT_FIXED_DELTA_SECONDS,
	max_frame_delta_seconds: float = DEFAULT_MAX_FRAME_DELTA_SECONDS,
	max_steps_per_frame: int = DEFAULT_MAX_STEPS_PER_FRAME,
) -> void:
	assert(controller != null, "GameLoop requires a MatchController")
	assert(fixed_delta_seconds > 0.0, "Fixed delta must be positive")
	assert(max_frame_delta_seconds > 0.0, "Maximum frame delta must be positive")
	assert(max_steps_per_frame > 0, "Maximum steps per frame must be positive")
	_controller = controller
	_fixed_delta_seconds = fixed_delta_seconds
	_max_frame_delta_seconds = max_frame_delta_seconds
	_max_steps_per_frame = max_steps_per_frame


func advance_frame(
	frame_delta_seconds: float,
	new_actions: Array[MatchAction],
) -> MatchFrameResult:
	assert(frame_delta_seconds >= 0.0, "Frame delta cannot be negative")
	var frame_events: Array[MatchEvent] = _controller.drain_lifecycle_events()
	var executed_steps := 0
	if _controller.is_running():
		for action in new_actions:
			_pending_actions.append(action)
		_accumulator_seconds += minf(frame_delta_seconds, _max_frame_delta_seconds)
		while (
			_accumulator_seconds + STEP_EPSILON >= _fixed_delta_seconds
			and executed_steps < _max_steps_per_frame
		):
			var step_actions: Array[MatchAction] = _pending_actions.duplicate()
			_pending_actions.clear()
			frame_events.append_array(
				_controller.advance_simulation(_fixed_delta_seconds, step_actions)
			)
			_accumulator_seconds -= _fixed_delta_seconds
			executed_steps += 1

	var interpolation_alpha := 0.0
	if _controller.is_running():
		interpolation_alpha = clampf(
			_accumulator_seconds / _fixed_delta_seconds,
			0.0,
			1.0,
		)
	return MatchFrameResult.new(
		_controller.create_snapshot(),
		frame_events,
		executed_steps,
		interpolation_alpha,
	)


func reset_timing() -> void:
	_accumulator_seconds = 0.0
	_pending_actions.clear()
