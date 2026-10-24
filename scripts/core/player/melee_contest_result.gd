## Immutable F05/F06 facts; absent F06 samples use -1 and an explicit reason.
class_name MeleeContestResult
extends RefCounted

enum Outcome { DODGED, ATTACKER_WIN, TARGET_WIN, DRAW }
enum StrengthReason { DODGED, EQUAL_STRENGTH, GUARANTEED_WIN, SAMPLED, OVERRIDE }

var did_hit: bool:
	get: return _outcome != Outcome.DODGED
var has_strength_result: bool:
	get: return _strength_reason != StrengthReason.DODGED and not _is_override

var sequence: int:
	get: return _sequence
var _sequence: int
var attacker_id: String:
	get: return _attacker_id
var _attacker_id: String
var target_id: String:
	get: return _target_id
var _target_id: String
var attacker_strength: int:
	get: return _attacker_strength
var _attacker_strength: int
var target_strength: int:
	get: return _target_strength
var _target_strength: int
var target_technique: int:
	get: return _target_technique
var _target_technique: int
var contact_position_m: Vector2:
	get: return _contact_position_m
var _contact_position_m: Vector2
var direction: Vector2:
	get: return _direction
var _direction: Vector2
var dodge_probability: float:
	get: return _dodge_probability
var _dodge_probability: float
var dodge_sample: float:
	get: return _dodge_sample
var _dodge_sample: float
var outcome: int:
	get: return _outcome
var _outcome: int
var auto_win_gap: int:
	get: return _auto_win_gap
var _auto_win_gap: int
var strength_gap: int:
	get: return _strength_gap
var _strength_gap: int
var stronger_id: String:
	get: return _stronger_id
var _stronger_id: String
var stronger_win_probability: float:
	get: return _stronger_win_probability
var _stronger_win_probability: float
var has_strength_sample: bool:
	get: return _has_strength_sample
var _has_strength_sample: bool
var strength_sample: float:
	get: return _strength_sample
var _strength_sample: float
var strength_reason: int:
	get: return _strength_reason
var _strength_reason: int
var is_override: bool:
	get: return _is_override
var _is_override: bool

func _init(
	new_sequence: int,
	new_attacker_id: String,
	new_target_id: String,
	new_attacker_strength: int,
	new_target_strength: int,
	new_target_technique: int,
	new_contact_position_m: Vector2,
	new_direction: Vector2,
	new_dodge_probability: float,
	new_dodge_sample: float,
	new_outcome: int,
	new_strength_gap: int,
	new_auto_win_gap: int,
	new_stronger_id: String,
	new_stronger_win_probability: float,
	new_has_strength_sample: bool,
	new_strength_sample: float,
	new_strength_reason: int,
	new_is_override: bool,
) -> void:
	_sequence = new_sequence
	_attacker_id = new_attacker_id
	_target_id = new_target_id
	_attacker_strength = new_attacker_strength
	_target_strength = new_target_strength
	_target_technique = new_target_technique
	_contact_position_m = new_contact_position_m
	_direction = new_direction
	_dodge_probability = new_dodge_probability
	_dodge_sample = new_dodge_sample
	_outcome = new_outcome
	_auto_win_gap = new_auto_win_gap
	_strength_gap = new_strength_gap
	_stronger_id = new_stronger_id
	_stronger_win_probability = new_stronger_win_probability
	_has_strength_sample = new_has_strength_sample
	_strength_sample = new_strength_sample
	_strength_reason = new_strength_reason
	_is_override = new_is_override
