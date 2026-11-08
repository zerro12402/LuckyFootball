## Stores the player's local DeepSeek key outside the project and never logs it.
class_name PlayerAISettings
extends RefCounted

const DEFAULT_PATH := "user://player_ai_settings.cfg"
const SECTION := "deepseek"
const KEY_NAME := "deepseek_api_key"
const ENV_NAME := "DEEPSEEK_API_KEY"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## Prefers the local file, then an explicit developer environment override.
func api_key() -> String:
	var config := ConfigFile.new()
	if config.load(_path) == OK:
		var stored := str(config.get_value(SECTION, KEY_NAME, "")).strip_edges()
		if not stored.is_empty():
			return stored
	return OS.get_environment(ENV_NAME).strip_edges()


func has_key() -> bool:
	return not api_key().is_empty()


## Saves or removes the key without touching any other section of the file.
func save_key(key: String) -> bool:
	var config := ConfigFile.new()
	config.load(_path)
	var trimmed := key.strip_edges()
	if trimmed.is_empty():
		config.erase_section_key(SECTION, KEY_NAME)
	else:
		config.set_value(SECTION, KEY_NAME, trimmed)
	return config.save(_path) == OK


func clear_key() -> bool:
	return save_key("")


## Keeps diagnostics readable without exposing the full secret.
func masked_key() -> String:
	var key := api_key()
	if key.length() <= 8:
		return "*".repeat(key.length())
	return key.substr(0, 4) + "…" + key.substr(key.length() - 4)


func storage_path() -> String:
	return _path
