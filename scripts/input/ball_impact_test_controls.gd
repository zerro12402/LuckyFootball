## Submits shot presets and displays ordered contact facts without deciding their outcomes.
class_name BallImpactTestControls
extends CanvasLayer

@onready var _bootstrap: GameBootstrap = get_parent() as GameBootstrap
@onready var _status: Label = %BallImpactStatusLabel

## Binds only this mode's shared-scene controls to the normal command path.
func _ready() -> void:
	visible = _bootstrap.demo_mode == GameBootstrap.DemoMode.BALL_IMPACT_TEST
	if not visible:
		return
	%SweptDefendersButton.pressed.connect(_select.bind(GameBootstrap.BallImpactPreset.SWEPT_DEFENDERS))
	%BlockReboundButton.pressed.connect(_select.bind(GameBootstrap.BallImpactPreset.BLOCK_REBOUND))
	%ImpactContinueButton.pressed.connect(_select.bind(GameBootstrap.BallImpactPreset.KNOCKDOWN_CONTINUE))
	%ImpactReboundButton.pressed.connect(_select.bind(GameBootstrap.BallImpactPreset.KNOCKDOWN_REBOUND))
	%WeakShotReboundButton.pressed.connect(_select.bind(GameBootstrap.BallImpactPreset.WEAK_SHOT_REBOUND))
	%ImpactReplayButton.pressed.connect(_replay)
	%ImpactResetButton.pressed.connect(_reset)
	_bootstrap.presentation_frame_ready.connect(_present)
	_status.text = "按 K 射门；~ 重置\n射门 80 / 目标强壮度 60"

## Chooses explicit test inputs while letting simulation produce every result.
func _select(preset: GameBootstrap.BallImpactPreset) -> void:
	_status.text = "射门中……"
	_bootstrap.select_ball_impact_preset(preset)

## Reconstructs the selected preset and the same match random stream.
func _replay() -> void:
	_select(_bootstrap.ball_impact_preset)

## Restores the selected setup without automatically shooting.
func _reset() -> void:
	_bootstrap.select_ball_impact_preset(_bootstrap.ball_impact_preset, false)
	_status.text = "按 K 射门；~ 重置"

## Displays the contact/knockdown/route facts in their committed event order.
func _present(_snapshot: MatchStateSnapshot, events: Array[MatchEvent], _alpha: float) -> void:
	for event in events:
		if event.event_type == MatchEvent.Type.RESET_COMPLETED:
			_status.text = "按 K 再次射门；可固定种子重放"
		elif event.event_type == MatchEvent.Type.BALL_SHOT:
			_status.text = "种子 %d：射门" % _bootstrap.random_seed
		elif event.event_type == MatchEvent.Type.BALL_HIT:
			_status.text += "\n命中 %s" % event.target_player_id
		elif event.event_type == MatchEvent.Type.PLAYER_KNOCKED_DOWN:
			_status.text += " → 击倒"
		elif event.event_type == MatchEvent.Type.BALL_CONTINUED:
			_status.text += " → 继续"
		elif event.event_type == MatchEvent.Type.BALL_REBOUNDED:
			_status.text += " → 反弹"
