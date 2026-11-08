## Covers prompt shape, JSON extraction, bounded repair, transport mapping and local key storage.
extends SceneTree

const FakeTransport = preload("res://tests/support/fake_ai_transport.gd")
const MANUAL := "# 幸运足球球员 AI 脚本手册 · 接口 v2\n只会输出覆盖补丁。"

var _failures: PackedStringArray = []


func _init() -> void:
	_test_prompt_and_extraction()
	_test_generator_repair()
	_test_transport_mapping()
	_test_settings_roundtrip()
	_test_overlay_summary()
	for failure in _failures:
		push_error(failure)
	print("AI generation failures: ", _failures.size())
	quit(0 if _failures.is_empty() else 1)


## Confirms the manual, the overlay default and the player's words reach the model.
func _test_prompt_and_extraction() -> void:
	var builder := PlayerAIPromptBuilder.new(MANUAL)
	var messages := builder.messages("后卫防守时用冲撞不要铲球", {"role": "home"})
	_check(messages.size() == 2 and messages[0]["role"] == "system" and messages[1]["role"] == "user",
		"A generation sends one system and one user message")
	_check(messages[0]["content"].contains(MANUAL) and messages[0]["content"].contains("version 3")
		and messages[0]["content"].contains("scope"), "The system prompt carries the manual and overlay rules")
	_check(messages[1]["content"].contains("后卫防守时用冲撞不要铲球"), "The player's tactic reaches the user prompt")
	var fenced := "说明\n```json\n{\"version\":3,\"mode\":\"overlay\",\"scope\":{},\"modifiers\":[]}\n```"
	_check(PlayerAIScriptGenerator.extract_json(fenced).begins_with("{\"version\":3"),
		"Fenced replies keep the first balanced object")
	_check(PlayerAIScriptGenerator.extract_json("{\"a\":{\"b\":1}} trailing") == "{\"a\":{\"b\":1}}",
		"Nested objects stop at the matching brace")
	_check(PlayerAIScriptGenerator.extract_json("no json here").is_empty(),
		"Replies without an object are rejected")


## Verifies a repair turn reuses the same conversation and never returns a partial script.
func _test_generator_repair() -> void:
	var builder := PlayerAIPromptBuilder.new(MANUAL)
	var fake := FakeTransport.new()
	var valid := '{"version":3,"mode":"overlay","scope":{"role":"back"},"modifiers":[' \
		+ '{"when":[["phase","==","defend"]],"weights":{"tackle":0}}]}'
	fake.responses = [
		{"ok": true, "content": "not json", "finish_reason": "stop", "status": 200},
		{"ok": true, "content": valid, "finish_reason": "stop", "status": 200},
	]
	var generator := PlayerAIScriptGenerator.new(builder)
	var step := generator.start("后卫防守不要铲球")
	var result := generator.accept_transport(fake.post(step["messages"], "test-key"))
	_check(result.get("retry", false) and result["messages"].size() == 4,
		"A failed reply appends one repair turn to the same conversation")
	var finished := generator.accept_transport(fake.post(result["messages"], "test-key"))
	_check(finished.get("ok", false) and finished["attempts"] == 2
		and finished["json"].begins_with("{\"version\":3"),
		"A valid repair compiles and reports both attempts")

	var failing := FakeTransport.new()
	failing.responses = [
		{"ok": true, "content": "not json", "finish_reason": "stop", "status": 200},
		{"ok": true, "content": "not json", "finish_reason": "stop", "status": 200},
		{"ok": true, "content": "not json", "finish_reason": "stop", "status": 200},
	]
	var stubborn := PlayerAIScriptGenerator.new(builder)
	step = stubborn.start("坏输入")
	var last: Dictionary = {}
	for index in range(3):
		last = stubborn.accept_transport(failing.post(step.get("messages", []), "test-key"))
		if last.get("retry", false):
			step = last
	_check(not last.get("ok", false) and last.get("error_kind") == "INVALID_JSON"
		and last.get("attempts") == 3, "Three failed replies stop with a bounded error")

	var truncated := PlayerAIScriptGenerator.new(builder)
	step = truncated.start("长战术")
	var cut := truncated.accept_transport({"ok": false, "error_kind": "TRUNCATED", "error": "输出被截断"})
	_check(not cut.get("ok", true) and cut.get("error_kind") == "TRUNCATED",
		"A truncated reply fails instead of binding a partial script")
	truncated.cancel()
	_check(truncated.accept_transport({"ok": true, "content": valid}).get("error_kind") == "CANCELLED",
		"A cancelled generation ignores late replies")


## Checks every documented transport failure converges on the public error kinds.
func _test_transport_mapping() -> void:
	var success := JSON.stringify({"choices": [{"message": {"content": "{\"a\":1}"}, "finish_reason": "stop"}]})
	var ok := DeepSeekTransport.normalize(HTTPRequest.RESULT_SUCCESS, 200, success.to_utf8_buffer())
	_check(ok["ok"] and ok["content"] == "{\"a\":1}", "A successful reply exposes its content")
	_check(DeepSeekTransport.normalize(HTTPRequest.RESULT_SUCCESS, 401, PackedByteArray())["error_kind"] == "AUTH",
		"401 maps to AUTH")
	_check(DeepSeekTransport.normalize(HTTPRequest.RESULT_SUCCESS, 402, PackedByteArray())["error_kind"] == "PAYMENT",
		"402 maps to PAYMENT")
	_check(DeepSeekTransport.normalize(HTTPRequest.RESULT_SUCCESS, 429, PackedByteArray())["error_kind"] == "RATE_LIMIT",
		"429 maps to RATE_LIMIT")
	_check(DeepSeekTransport.normalize(HTTPRequest.RESULT_SUCCESS, 500, PackedByteArray())["error_kind"] == "HTTP",
		"Other statuses map to HTTP")
	_check(DeepSeekTransport.normalize(HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedByteArray())["error_kind"] == "TIMEOUT",
		"A failed request maps to TIMEOUT")
	_check(DeepSeekTransport.normalize(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())["error_kind"] == "NETWORK",
		"A connection failure maps to NETWORK")
	_check(DeepSeekTransport.normalize(HTTPRequest.RESULT_SUCCESS, 200, PackedByteArray(), true)["error_kind"] == "CANCELLED",
		"A cancelled request maps to CANCELLED")
	var empty := JSON.stringify({"choices": [{"message": {"content": ""}, "finish_reason": "stop"}]})
	_check(DeepSeekTransport.normalize(HTTPRequest.RESULT_SUCCESS, 200, empty.to_utf8_buffer())["error_kind"] == "EMPTY_RESPONSE",
		"An empty content maps to EMPTY_RESPONSE")
	var cut := JSON.stringify({"choices": [{"message": {"content": "{\"a\""}, "finish_reason": "length"}]})
	_check(DeepSeekTransport.normalize(HTTPRequest.RESULT_SUCCESS, 200, cut.to_utf8_buffer())["error_kind"] == "TRUNCATED",
		"A length finish maps to TRUNCATED")


## Uses a temporary file so the real player settings are never touched.
func _test_settings_roundtrip() -> void:
	OS.set_environment(PlayerAISettings.ENV_NAME, "")
	var path := "user://test_player_ai_settings_%s.cfg" % OS.get_process_id()
	var settings := PlayerAISettings.new(path)
	_check(not settings.has_key(), "A missing local file has no key")
	_check(settings.save_key("sk-test-12345678"), "The key saves to the local file")
	_check(settings.api_key() == "sk-test-12345678", "The saved key round-trips")
	_check(settings.masked_key().contains("sk-t") and not settings.masked_key().contains("1234"),
		"The displayed key stays masked")
	_check(settings.clear_key() and not settings.has_key(), "Clearing removes the key")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Confirms the lab summary states scope and behavior changes without raw JSON.
func _test_overlay_summary() -> void:
	var summary := PlayerAIScriptGenerator.summarize('{"version":3,"mode":"overlay","scope":{"role":"back"},' \
		+ '"modifiers":[{"when":[["phase","==","defend"]],"weights":{"tackle":0}},' \
		+ '{"when":[["phase","==","defend"]],"weights":{"attack":3}}]}')
	_check(summary.contains("role=back") and summary.contains("tackle×0")
		and summary.contains("attack×3") and summary.contains("规则 2 条"),
		"The summary lists scope, merged effects and rule count")
	_check(PlayerAIScriptGenerator.summarize('{"version":2,"rules":[],"default":{}}').contains("整份脚本 v2"),
		"A full script summary names its version")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
