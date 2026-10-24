## Readonly command envelope; stale instances, steps, revisions and rounds cannot submit late actions.
class_name MatchActionBatch
extends RefCounted

var match_id: String:
	get: return _match_id
var simulation_step: int:
	get: return _simulation_step
var control_revision: int:
	get: return _control_revision
var round_sequence: int:
	get: return _round_sequence
var actions: Array[MatchAction]:
	get: return _actions.duplicate()
var _control_owner_token: int
var _match_id: String
var _simulation_step: int
var _control_revision: int
var _round_sequence: int
var _actions: Array[MatchAction]

func _init(snapshot: MatchStateSnapshot, intents: Array[MatchAction]) -> void:
	_control_owner_token = snapshot._control_owner_token
	_match_id = snapshot.match_id
	_simulation_step = snapshot.simulation_step
	_control_revision = snapshot.control_revision
	_round_sequence = snapshot.round_sequence
	_actions = intents.duplicate()

## Matching the complete stamp prevents paused, reset or replaced instances from replaying old intent.
func matches(snapshot: MatchStateSnapshot) -> bool:
	return _control_owner_token == snapshot._control_owner_token and _match_id == snapshot.match_id and _simulation_step == snapshot.simulation_step and _control_revision == snapshot.control_revision and _round_sequence == snapshot.round_sequence
