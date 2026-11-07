## Compiles and evaluates bounded JSON decision rules without exposing any executable host interface.
class_name PlayerAIScript
extends PlayerAIDecisionStrategy

const MAX_SOURCE_BYTES := 8192
const MAX_JSON_DEPTH := 8
const MAX_RULES := 24
const MAX_CONDITIONS := 8
const MAX_INSTRUCTIONS := 128
const OPERATORS := ["==", "!=", "<", "<=", ">", ">="]

var _version := 1
var _rules: Array[Dictionary] = []
var _default: Dictionary = {}


## Reports JSON lines and schema paths before constructing a reusable, typed rule list.
static func compile(source: String) -> Dictionary:
	if source.length() > MAX_SOURCE_BYTES or source.to_utf8_buffer().size() > MAX_SOURCE_BYTES:
		return {"error": "脚本超过 8192 字节"}
	if not _within_depth(source):
		return {"error": "JSON 嵌套超过 8 层"}
	var json := JSON.new()
	if json.parse(source) != OK:
		return {"error": "第 %d 行：%s" % [json.get_error_line() + 1, json.get_error_message()]}
	if not json.data is Dictionary:
		return {"error": "根节点必须是对象"}
	var root: Dictionary = json.data
	var version: Variant = root.get("version")
	if root.size() != 3 or not (version is int or version is float) or float(version) not in [1.0, 2.0] \
			or not root.get("rules") is Array or not root.get("default") is Dictionary:
		return {"error": "根节点须包含 version: 1 或 2、rules 和 default"}
	if root["rules"].size() > MAX_RULES:
		return {"error": "rules 最多 24 条"}
	var fallback_error := _result_error(root["default"], int(version))
	if not fallback_error.is_empty():
		return {"error": "default：%s" % fallback_error}
	var script := PlayerAIScript.new()
	script._version = int(version)
	for index in range(root["rules"].size()):
		var rule: Variant = root["rules"][index]
		var error := _rule_error(rule, script._version)
		if not error.is_empty():
			return {"error": "rules[%d]：%s" % [index, error]}
		script._rules.append(rule)
	script._default = root["default"]
	return {"script": script}


## Caps nesting before the engine JSON parser can recurse; ignores brackets inside quoted strings.
static func _within_depth(source: String) -> bool:
	var depth := 0
	var quoted := false
	var escaped := false
	for character in source:
		if escaped:
			escaped = false
		elif quoted and character == "\\":
			escaped = true
		elif character == "\"":
			quoted = not quoted
		elif not quoted and character in ["{", "["]:
			depth += 1
			if depth > MAX_JSON_DEPTH:
				return false
		elif not quoted and character in ["}", "]"]:
			depth -= 1
	return true


## Validates statically named fields, operators and values using the published version contract.
static func _rule_error(rule: Variant, version: int) -> String:
	if not rule is Dictionary or rule.size() != 2 or not rule.get("when") is Array \
			or not rule.get("then") is Dictionary:
		return "须包含 when 数组和 then 对象"
	if rule["when"].is_empty() or rule["when"].size() > MAX_CONDITIONS:
		return "when 须有 1 至 8 个条件"
	for index in range(rule["when"].size()):
		var condition: Variant = rule["when"][index]
		if not condition is Array or condition.size() != 3 or not condition[0] is String \
				or condition[1] not in OPERATORS:
			return "when[%d] 须为 [字段, 比较符, 值]" % index
		var field: String = condition[0]
		var field_type := ScriptedAIContract.field_type(field, version)
		var value: Variant = condition[2]
		if field_type in [TYPE_FLOAT, TYPE_INT] and (value is float or value is int) and is_finite(float(value)):
			continue
		if field_type in [TYPE_BOOL, TYPE_STRING] and typeof(value) == field_type \
				and condition[1] in ["==", "!="]:
			continue
		return "when[%d] 的字段、比较符或值类型无效：%s" % [index, field]
	return _result_error(rule["then"], version)


## Restricts output to fallback, finite multipliers, or an advertised behavior and target ID.
static func _result_error(result: Dictionary, version: int) -> String:
	if result.is_empty():
		return ""
	if result.size() == 2 and result.get("behavior") is String and result.get("target") is String:
		if ScriptedAIContract.behaviors(version).has(result["behavior"]) and result["target"].length() <= 64:
			return ""
		return "未知行为或目标 ID 过长"
	if result.size() == 1 and result.get("weights") is Dictionary:
		var weights: Dictionary = result["weights"]
		if weights.is_empty():
			return "weights 不能为空"
		for behavior in weights:
			var amount: Variant = weights[behavior]
			if not ScriptedAIContract.behaviors(version).has(behavior) or not (amount is float or amount is int) \
					or not is_finite(float(amount)) or float(amount) < 0.0:
				return "无效的行为倍率：%s" % behavior
		return ""
	return "结果须为 {}、weights 对象或 behavior/target 对象"


func interface_version() -> int:
	return _version


## Evaluates bounded ordered rules using only detached public input values.
func decide(view: Dictionary) -> Dictionary:
	if view.get("version") != _version:
		return {"error": "脚本接口版本不匹配"}
	var instructions := 0
	for rule in _rules:
		var matches := true
		for condition in rule["when"]:
			instructions += 1
			if instructions > MAX_INSTRUCTIONS:
				return {"error": "超过单次决策的 128 次比较预算"}
			if not _matches(view, condition):
				matches = false
				break
		if matches:
			return rule["then"].duplicate(true)
	return _default.duplicate(true)


## Dispatches only the six comparison operators validated at submission.
static func _matches(view: Dictionary, condition: Array) -> bool:
	var field: String = condition[0]
	var left: Variant
	if field.begins_with("has."):
		left = view["candidates"].has(field.substr(4))
	elif field.begins_with("has_target."):
		var parts := field.split(".", false, 2)
		left = ScriptedAIContract.has_target(view["candidates"], parts[1], parts[2])
	elif "." in field:
		var parts := field.split(".", true, 1)
		left = view[parts[0]][parts[1]]
	else:
		left = view[field]
	var right: Variant = condition[2]
	match condition[1]:
		"==": return left == right
		"!=": return left != right
		"<": return left < right
		"<=": return left <= right
		">": return left > right
		">=": return left >= right
	return false