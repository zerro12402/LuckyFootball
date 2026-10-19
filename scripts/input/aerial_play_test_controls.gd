## Drives aerial presets only when the shared demo is in aerial test mode.
class_name AerialPlayTestControls
extends CanvasLayer

enum Preset {
	GROUND_TACKLE,
	AIRBORNE_CLEARANCE,
	AFTER_LANDING,
	AERIAL_SHOT,
}

@onready var _bootstrap: GameBootstrap = get_parent() as GameBootstrap
@onready var _ground_button: Button = %GroundTackleButton
@onready var _airborne_button: Button = %AirborneClearanceButton
@onready var _landing_button: Button = %AfterLandingButton
@onready var _shot_button: Button = %AerialShotButton
@onready var _reset_button: Button = %ResetPresetButton
@onready var _status_label: Label = %PresetStatusLabel

var _selected_preset_name: String = "准备就绪"


## Hides the panel in other modes and binds aerial controls before match start.
func _ready() -> void:
	assert(_bootstrap != null, "Aerial controls require GameBootstrap")
	visible = _bootstrap.demo_mode == GameBootstrap.DemoMode.AERIAL_JUMP_SHOT_TEST
	if not visible:
		return
	_ground_button.pressed.connect(select_preset.bind(Preset.GROUND_TACKLE))
	_airborne_button.pressed.connect(select_preset.bind(Preset.AIRBORNE_CLEARANCE))
	_landing_button.pressed.connect(select_preset.bind(Preset.AFTER_LANDING))
	_shot_button.pressed.connect(select_preset.bind(Preset.AERIAL_SHOT))
	_reset_button.pressed.connect(reset_preset)
	_bootstrap.presentation_frame_ready.connect(_present_status)


## Rebuilds one fixed-seed test and reaches its named contact or shot checkpoint.
func select_preset(preset: Preset) -> void:
	reset_preset()
	match preset:
		Preset.GROUND_TACKLE:
			_selected_preset_name = "地面抢断"
			_queue_tackle()
			_advance_steps(12)
		Preset.AIRBORNE_CLEARANCE:
			_selected_preset_name = "有效腾空"
			_queue_jump()
			_advance_steps(15)
			_queue_tackle()
			_advance_steps(1)
		Preset.AFTER_LANDING:
			_selected_preset_name = "落地后抢断"
			_queue_jump()
			_advance_steps(48)
			_queue_tackle()
			_advance_steps(12)
		Preset.AERIAL_SHOT:
			_selected_preset_name = "空中射门"
			_queue_jump()
			_advance_steps(15)
			_bootstrap.queue_action(MatchAction.new(
				_bootstrap.demo_player_id, MatchAction.Type.SHOOT
			))
			_advance_steps(14)


## Restores the same two-player setup, already owning the nearby ball.
func reset_preset() -> void:
	_selected_preset_name = "重置"
	_bootstrap.reset_demo()


## Sends the normal jump command without directly changing player or ball state.
func _queue_jump() -> void:
	_bootstrap.queue_action(MatchAction.new(
		_bootstrap.demo_player_id, MatchAction.Type.JUMP
	))


## Lets the defender use the same ground-tackle action as other test modes.
func _queue_tackle() -> void:
	_bootstrap.queue_action(MatchAction.new(
		_bootstrap.demo_opponent_id,
		MatchAction.Type.TACKLE,
		Vector2.ZERO,
		_bootstrap.demo_player_id,
	))


## Replays a preset in exact fixed steps; normal frames resume afterward.
func _advance_steps(step_count: int) -> void:
	for step_index in range(step_count):
		_bootstrap._process(_bootstrap.fixed_delta_seconds)


## Shows only read-only match facts; the label never decides an action's outcome.
func _present_status(
	snapshot: MatchStateSnapshot,
	_events: Array[MatchEvent],
	_alpha: float,
) -> void:
	if snapshot == null or snapshot.ball == null or _bootstrap.demo_player_id.is_empty():
		return
	var carrier := snapshot.get_player(_bootstrap.demo_player_id)
	if carrier == null:
		return
	_status_label.text = "%s | 球权：%s\n球员 %.2f m / 足球 %.2f m" % [
		_selected_preset_name,
		snapshot.ball.owner_player_id if not snapshot.ball.owner_player_id.is_empty() else "自由球",
		carrier.height_m,
		snapshot.ball.height_m,
	]
