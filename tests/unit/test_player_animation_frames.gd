## Checks that player animations never select transparent cells in the sprite sheet.
extends SceneTree

const PLAYER_SCENE := preload("res://scenes/actors/player_actor.tscn")
const SPRITE_PATH := "res://assets/art/characters/soccer_player.png"

var _failures: PackedStringArray = []


## Inspects animation keys and exits with a failure when a referenced cell is blank.
func _init() -> void:
	test_player_animations_reference_visible_frames()
	for failure in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("PASS: player animation frames")
	quit(0 if _failures.is_empty() else 1)


## Every sprite frame used by an animation must contain at least one visible pixel.
func test_player_animations_reference_visible_frames() -> void:
	var actor := PLAYER_SCENE.instantiate()
	var sprite: Sprite2D = actor.get_node("BodySprite")
	var animator: AnimationPlayer = actor.get_node("AnimationPlayer")
	var image := Image.new()
	var image_error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(SPRITE_PATH))
	assert(image_error == OK, "Could not read player sprite sheet")
	var frame_width := image.get_width() / sprite.hframes
	var frame_height := image.get_height() / sprite.vframes
	for animation_name in animator.get_animation_list():
		var animation := animator.get_animation(animation_name)
		for track_index in animation.get_track_count():
			if animation.track_get_path(track_index) != NodePath("BodySprite:frame_coords"):
				continue
			for key_index in animation.track_get_key_count(track_index):
				var frame: Vector2i = animation.track_get_key_value(track_index, key_index)
				if not _frame_has_visible_pixel(image, frame, frame_width, frame_height):
					_failures.append("%s references blank frame %s" % [animation_name, frame])
	actor.free()


## Reads source PNG alpha directly; this does not instantiate a render viewport.
func _frame_has_visible_pixel(
	image: Image,
	frame: Vector2i,
	frame_width: int,
	frame_height: int,
) -> bool:
	for y in range(frame.y * frame_height, (frame.y + 1) * frame_height):
		for x in range(frame.x * frame_width, (frame.x + 1) * frame_width):
			if image.get_pixel(x, y).a > 0.0:
				return true
	return false
