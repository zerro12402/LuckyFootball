## Development-only one-round action source; formal production scenes never reference this script.
class_name FormalPresetActionSource
extends MatchActionSource

var player_id: String
var is_exit: bool
var _shot_issued: bool = false

func _init(id: String, exit_preset: bool) -> void:
	player_id = id
	is_exit = exit_preset

## Uses the same legal action protocol as future tactical sources, without submitting scores or resets.
func propose_actions(snapshot: MatchStateSnapshot) -> Array[MatchAction]:
	if snapshot.round_sequence != 1 or snapshot.ball == null or snapshot.ball.owner_player_id != player_id:
		return []
	if is_exit:
		return [MatchAction.new(player_id, MatchAction.Type.MOVE, Vector2.UP)]
	if not _shot_issued:
		_shot_issued = true
		return [MatchAction.new(player_id, MatchAction.Type.SHOOT)]
	return []
