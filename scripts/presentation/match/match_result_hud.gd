## Displays score and settled ball results from snapshots and events only.
class_name MatchResultHud
extends CanvasLayer

@onready var _score_label: Label = %ScoreLabel
@onready var _result_label: Label = %ResultLabel

var _last_result_text: String = ""


## Keeps the result visible through the delayed reset, then marks it complete.
func present(snapshot: MatchStateSnapshot, events: Array[MatchEvent]) -> void:
	_score_label.text = "左门 %d  ·  右门 %d" % [
		snapshot.left_goal_count,
		snapshot.right_goal_count,
	]
	var result_text := ""
	for event in events:
		if event.event_type == MatchEvent.Type.MATCH_STARTED:
			_last_result_text = ""
			result_text = "等待比赛结果"
		elif event.event_type == MatchEvent.Type.GOAL_SCORED:
			_last_result_text = "进球：%s" % _side_name(event.side, true)
			result_text = _last_result_text
		elif event.event_type == MatchEvent.Type.TACKLE_SUCCEEDED:
			_last_result_text = "抢断成功"
			result_text = _last_result_text
		elif event.event_type == MatchEvent.Type.BALL_OUT_OF_BOUNDS:
			_last_result_text = "出界：%s" % _side_name(event.side, false)
			result_text = _last_result_text
		elif event.event_type == MatchEvent.Type.RESET_COMPLETED:
			if event.reason == MatchEvent.ResetReason.MANUAL_ROUND:
				_last_result_text = ""
				result_text = "回合已重置"
			elif event.reason == MatchEvent.ResetReason.RESTART_TEST:
				_last_result_text = ""
				result_text = "测试已重新开始"
			elif not _last_result_text.is_empty():
				result_text = _last_result_text + " · 已重置"
	if not result_text.is_empty():
		_result_label.text = result_text


## Names the crossed physical field edge without inferring a scoring team.
func _side_name(side: int, is_goal: bool) -> String:
	match side:
		MatchBoundaryResult.Side.TOP:
			return "上边线"
		MatchBoundaryResult.Side.BOTTOM:
			return "下边线"
		MatchBoundaryResult.Side.LEFT:
			return "左侧球门" if is_goal else "左侧底线"
		MatchBoundaryResult.Side.RIGHT:
			return "右侧球门" if is_goal else "右侧底线"
		_:
			return "未知边界"
