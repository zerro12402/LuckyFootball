class_name PlayerDefinition
extends RefCounted

var player_id: String:
	get:
		return _player_id

var display_name: String:
	get:
		return _display_name

var default_role: String:
	get:
		return _default_role

var speed: int:
	get:
		return _speed

var shooting: int:
	get:
		return _shooting

var strength: int:
	get:
		return _strength

var skill: int:
	get:
		return _skill

var stamina: int:
	get:
		return _stamina

var tackling: int:
	get:
		return _tackling

var goalkeeping: int:
	get:
		return _goalkeeping

var trait_ids: PackedStringArray:
	get:
		return _trait_ids.duplicate()

var visual_id: String:
	get:
		return _visual_id

var _player_id: String
var _display_name: String
var _default_role: String
var _speed: int
var _shooting: int
var _strength: int
var _skill: int
var _stamina: int
var _tackling: int
var _goalkeeping: int
var _trait_ids: PackedStringArray
var _visual_id: String


func _init(
	new_player_id: String,
	new_display_name: String,
	new_default_role: String,
	new_speed: int,
	new_shooting: int,
	new_strength: int,
	new_skill: int,
	new_stamina: int,
	new_tackling: int,
	new_goalkeeping: int,
	new_trait_ids: PackedStringArray,
	new_visual_id: String,
) -> void:
	_player_id = new_player_id
	_display_name = new_display_name
	_default_role = new_default_role
	_speed = new_speed
	_shooting = new_shooting
	_strength = new_strength
	_skill = new_skill
	_stamina = new_stamina
	_tackling = new_tackling
	_goalkeeping = new_goalkeeping
	_trait_ids = new_trait_ids.duplicate()
	_visual_id = new_visual_id
