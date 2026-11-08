## Turns model replies into a compiled script, repairing only bounded compile failures.
class_name PlayerAIScriptGenerator
extends RefCounted

const MAX_ATTEMPTS := 3

var _builder: PlayerAIPromptBuilder
var _messages: Array[Dictionary] = []
var _attempt := 0
var _done := false


func _init(builder: PlayerAIPromptBuilder) -> void:
	_builder = builder


## Starts a generation and returns the first request messages.
func start(description: String, context: Dictionary = {}) -> Dictionary:
	_messages = _builder.messages(description, context)
	_attempt = 0
	_done = false
	return {"messages": _messages.duplicate(true)}


## Normalizes a transport reply before evaluating it as a script.
func accept_transport(response: Dictionary) -> Dictionary:
	if _done:
		return _fail("CANCELLED", "生成已结束")
	if not response.get("ok", false):
		return _fail(str(response.get("error_kind", "NETWORK")), str(response.get("error", "")))
	return accept(str(response.get("content", "")))


## Compiles one reply or appends a bounded repair turn with the exact error.
func accept(content: String) -> Dictionary:
	if _done:
		return _fail("CANCELLED", "生成已结束")
	_attempt += 1
	var trimmed := content.strip_edges()
	if trimmed.is_empty():
		return _retry_or_fail("EMPTY_RESPONSE", "模型返回为空", content)
	var json := extract_json(trimmed)
	if json.is_empty():
		return _retry_or_fail("INVALID_JSON", "未找到 JSON 对象", content)
	var compiled := PlayerAIScript.compile(json)
	if compiled.has("error"):
		return _retry_or_fail("COMPILE", str(compiled["error"]), content)
	_done = true
	return {"ok": true, "script": compiled["script"], "json": json, "attempts": _attempt,
		"prompt_version": PlayerAIPromptBuilder.PROMPT_VERSION, "error_kind": "", "error": ""}


func cancel() -> void:
	_done = true
	_messages.clear()


func is_done() -> bool:
	return _done


## Keeps the first balanced object and tolerates Markdown fences and surrounding prose.
static func extract_json(text: String) -> String:
	var start := text.find("{")
	if start < 0:
		return ""
	var depth := 0
	var quoted := false
	var escaped := false
	for index in range(start, text.length()):
		var character := text[index]
		if escaped:
			escaped = false
		elif quoted and character == "\\":
			escaped = true
		elif character == "\"":
			quoted = not quoted
		elif not quoted and character == "{":
			depth += 1
		elif not quoted and character == "}":
			depth -= 1
			if depth == 0:
				return text.substr(start, index - start + 1)
	return ""


## Renders a compact human-readable overlay summary for the lab.
static func summarize(json: String) -> String:
	var parsed: Variant = JSON.parse_string(json)
	if not parsed is Dictionary:
		return "无法解析生成的脚本"
	var version := int(parsed.get("version", 0))
	if version == PlayerAIScript.OVERLAY_VERSION:
		var scope: Dictionary = parsed.get("scope", {}) if parsed.get("scope") is Dictionary else {}
		var parts: PackedStringArray = []
		for key in ["role", "position", "duty"]:
			if scope.has(key):
				parts.append("%s=%s" % [key, scope[key]])
		var behaviors := {}
		var modifiers: Array = parsed.get("modifiers", []) if parsed.get("modifiers") is Array else []
		for modifier in modifiers:
			if not modifier is Dictionary or not modifier.get("weights") is Dictionary:
				continue
			for behavior in modifier["weights"]:
				behaviors[behavior] = float(behaviors.get(behavior, 1.0)) * float(modifier["weights"][behavior])
		var effects: PackedStringArray = []
		for behavior in behaviors:
			effects.append("%s×%s" % [behavior, str(behaviors[behavior]).trim_suffix(".0")])
		return "覆盖范围：%s；修改：%s；规则 %d 条" % [
			"、".join(parts) if not parts.is_empty() else "全队",
			"、".join(effects) if not effects.is_empty() else "无",
			modifiers.size(),
		]
	var rules: Array = parsed.get("rules", []) if parsed.get("rules") is Array else []
	return "整份脚本 v%d；规则 %d 条" % [version, rules.size()]


func _retry_or_fail(kind: String, message: String, content: String) -> Dictionary:
	if _attempt >= MAX_ATTEMPTS:
		return _fail(kind, message)
	_messages.append({"role": "assistant", "content": content})
	_messages.append({"role": "user",
		"content": "校验失败：%s。只输出修正后的完整 JSON。" % message})
	return {"retry": true, "messages": _messages.duplicate(true), "attempts": _attempt,
		"error_kind": kind, "error": message}


func _fail(kind: String, message: String) -> Dictionary:
	_done = true
	return {"ok": false, "error_kind": kind, "error": message, "attempts": _attempt,
		"prompt_version": PlayerAIPromptBuilder.PROMPT_VERSION}
