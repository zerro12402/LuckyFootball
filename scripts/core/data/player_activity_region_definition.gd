## Immutable normalized responsibility bounds, projected through field dimensions and attack direction.
class_name PlayerActivityRegionDefinition
extends RefCounted

var position_id: String:
	get: return _position_id
var phase: int:
	get: return _phase
var _position_id: String
var _phase: int
var _space: String
var _min_uv: Vector2
var _max_uv: Vector2

func _init(position: String, tactical_phase: int, space: String, minimum: Vector2, maximum: Vector2) -> void:
	_position_id = position
	_phase = tactical_phase
	_space = space
	_min_uv = minimum
	_max_uv = maximum

## Mirrors only the longitudinal axis, matching existing formation coordinates for both teams.
func bounds(field: FieldDefinition, attack_direction: float) -> Rect2:
	var length := field.penalty_area_depth_m if _space == "own_penalty" else field.length_m
	var width := field.penalty_area_width_m if _space == "own_penalty" else field.width_m
	var first := Vector2(attack_direction * (-field.length_m * 0.5 + _min_uv.x * length),
		-width * 0.5 + _min_uv.y * width)
	var last := Vector2(attack_direction * (-field.length_m * 0.5 + _max_uv.x * length),
		-width * 0.5 + _max_uv.y * width)
	return Rect2(Vector2(minf(first.x, last.x), first.y),
		Vector2(absf(last.x - first.x), last.y - first.y))
