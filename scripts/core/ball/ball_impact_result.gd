## Keeps contact, dodge, knockdown and ball response as separate immutable facts.
class_name BallImpactResult
extends RefCounted

enum Route { CONTINUE, REBOUND }

var source: BallShotSource:
	get: return _source
var target_player_id: String:
	get: return _target_player_id
var target_strength: int:
	get: return _target_strength
var position_m: Vector2:
	get: return _position_m
var height_m: float:
	get: return _height_m
var velocity_before_mps: Vector2:
	get: return _velocity_before_mps
var velocity_after_mps: Vector2:
	get: return _velocity_after_mps
var did_dodge: bool:
	get: return _did_dodge
var was_knocked_down: bool:
	get: return _was_knocked_down
var route: Route:
	get: return _route
var route_sample: float:
	get: return _route_sample

var _source: BallShotSource
var _target_player_id: String
var _target_strength: int
var _position_m: Vector2
var _height_m: float
var _velocity_before_mps: Vector2
var _velocity_after_mps: Vector2
var _did_dodge: bool
var _was_knocked_down: bool
var _route: Route
var _route_sample: float

func _init(contact: BallContactCandidate, shot_source: BallShotSource, strength: int,
		before: Vector2, after: Vector2, dodged: bool, knocked_down: bool,
		response: Route, sample: float = -1.0) -> void:
	_source = shot_source
	_target_player_id = contact.player_id
	_target_strength = strength
	_position_m = contact.position_m
	_height_m = contact.height_m
	_velocity_before_mps = before
	_velocity_after_mps = after
	_did_dodge = dodged
	_was_knocked_down = knocked_down
	_route = response
	_route_sample = sample
