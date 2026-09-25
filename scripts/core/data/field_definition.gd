class_name FieldDefinition
extends RefCounted

var field_id: String:
	get:
		return _field_id

var length_m: float:
	get:
		return _length_m

var width_m: float:
	get:
		return _width_m

var goal_width_m: float:
	get:
		return _goal_width_m

var goal_depth_m: float:
	get:
		return _goal_depth_m

var penalty_area_depth_m: float:
	get:
		return _penalty_area_depth_m

var penalty_area_width_m: float:
	get:
		return _penalty_area_width_m

var center_circle_radius_m: float:
	get:
		return _center_circle_radius_m

var pixels_per_meter: float:
	get:
		return _pixels_per_meter

var visual_id: String:
	get:
		return _visual_id

var _field_id: String
var _length_m: float
var _width_m: float
var _goal_width_m: float
var _goal_depth_m: float
var _penalty_area_depth_m: float
var _penalty_area_width_m: float
var _center_circle_radius_m: float
var _pixels_per_meter: float
var _visual_id: String


func _init(
	new_field_id: String,
	new_length_m: float,
	new_width_m: float,
	new_goal_width_m: float,
	new_goal_depth_m: float,
	new_penalty_area_depth_m: float,
	new_penalty_area_width_m: float,
	new_center_circle_radius_m: float,
	new_pixels_per_meter: float,
	new_visual_id: String,
) -> void:
	_field_id = new_field_id
	_length_m = new_length_m
	_width_m = new_width_m
	_goal_width_m = new_goal_width_m
	_goal_depth_m = new_goal_depth_m
	_penalty_area_depth_m = new_penalty_area_depth_m
	_penalty_area_width_m = new_penalty_area_width_m
	_center_circle_radius_m = new_center_circle_radius_m
	_pixels_per_meter = new_pixels_per_meter
	_visual_id = new_visual_id
