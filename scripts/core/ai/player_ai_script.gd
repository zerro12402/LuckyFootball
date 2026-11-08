## Compiles and evaluates bounded JSON decision rules without exposing any executable host interface.
class_name PlayerAIScript
extends PlayerAIDecisionStrategy

const MAX_SOURCE_BYTES := 8192
const MAX_JSON_DEPTH := 8
const MAX_RULES := 24
const MAX_CONDITIONS := 8
const MAX_INSTRUCTIONS := 128
const OVERLAY_VERSION := 3
const SCOPE_KEYS := ["role", "position", "duty"]
const OPERATORS := ["==", "!=", "<", "<=", ">", ">="]

var _version := 1
var _rules: Array[Dictionary] = []
var _default: Dictionary = {}
var _scope: Dictionary = {}
var _modifiers: Array[Dictionary] = []


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
	if not (version is int or version is float) or float(version) not in [1.0, 2.0, 3.0]:
		return {"error": "version 须为 1、2 或 3"}
	if int(version) == OVERLAY_VERSION:
		return _compile_overlay(root)
	if root.size() != 3 or not root.get("rules") is Array or not root.get("default") is Dictionary:
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


## Validates a version 3 overlay document and rejects keys reserved for v1/v2 documents.
static func _compile_overlay(root: Dictionary) -> Dictionary:
	if root.size() != 4 or not root.get("mode") is String or root["mode"] != "overlay" \
			or not root.get("scope") is Dictionary or not root.get("modifiers") is Array:
		return {"error": "v3 根节点须包含 version、mode: overlay、scope 和 modifiers"}
	var scope: Dictionary = root["scope"]
	if scope.size() > SCOPE_KEYS.size():
		return {"error": "scope 最多 3 个键"}
	for key in scope:
		if not key is String or key not in SCOPE_KEYS:
			return {"error": "scope 仅支持 role、position、duty"}
		if not scope[key] is String or String(scope[key]).length() > 32:
			return {"error": "scope.%s 须为不超过 32 字符的字符串" % key}
	var modifiers: Array = root["modifiers"]
	if modifiers.is_empty() or modifiers.size() > MAX_RULES:
		return {"error": "modifiers 须有 1 至 24 项"}
	var script := PlayerAIScript.new()
	script._version = OVERLAY_VERSION
	script._scope = scope.duplicate(true)
	for index in range(modifiers.size()):
		var modifier: Variant = modifiers[index]
		var error := _modifier_error(modifier, OVERLAY_VERSION)
		if not error.is_empty():
			return {"error": "modifiers[%d]：%s" % [index, error]}
		script._modifiers.append(modifier)
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
	var conditions_error := _conditions_error(rule["when"], version)
	if not conditions_error.is_empty():
		return conditions_error
	return _result_error(rule["then"], version)


## Shares condition validation between full scripts and overlay modifiers.
static func _conditions_error(conditions: Array, version: int) -> String:
	if conditions.is_empty() or conditions.size() > MAX_CONDITIONS:
		return "when 须有 1 至 8 个条件"
	for index in range(conditions.size()):
		var condition: Variant = conditions[index]
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
	return ""


## Validates an overlay modifier, which may only adjust candidate weights.
static func _modifier_error(modifier: Variant, version: int) -> String:
	if not modifier is Dictionary or modifier.size() != 2 or not modifier.get("when") is Array \
			or not modifier.get("weights") is Dictionary:
		return "须包含 when 数组和 weights 对象"
	var conditions_error := _conditions_error(modifier["when"], version)
	if not conditions_error.is_empty():
		return conditions_error
	return _weights_error(modifier["weights"], version)


## Restricts output to fallback, finite multipliers, or an advertised behavior and target ID.
static func _result_error(result: Dictionary, version: int) -> String:
	if result.is_empty():
		return ""
	if result.size() == 2 and result.get("behavior") is String and result.get("target") is String:
		if ScriptedAIContract.behaviors(version).has(result["behavior"]) and result["target"].length() <= 64:
			return ""
		return "未知行为或目标 ID 过长"
	if result.size() == 1 and result.get("weights") is Dictionary:
		return _weights_error(result["weights"], version)
	return "结果须为 {}、weights 对象或 behavior/target 对象"


## Rejects unknown behaviors and negative or non-finite multipliers.
static func _weights_error(weights: Dictionary, version: int) -> String:
	if weights.is_empty():
		return "weights 不能为空"
	for behavior in weights:
		var amount: Variant = weights[behavior]
		if not ScriptedAIContract.behaviors(version).has(behavior) or not (amount is float or amount is int) \
				or not is_finite(float(amount)) or float(amount) < 0.0:
			return "无效的行为倍率：%s" % behavior
	return ""


func interface_version() -> int:
	return _version


## Evaluates bounded rules or merges every matching overlay modifier using only public input values.
func decide(view: Dictionary) -> Dictionary:
	if view.get("version") != _version:
		return {"error": "脚本接口版本不匹配"}
	if _version == OVERLAY_VERSION:
		return _decide_overlay(view)
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


## Multiplies every matching modifier per behavior and drops behaviors unavailable in this decision.
func _decide_overlay(view: Dictionary) -> Dictionary:
	if not _scope_matches(view):
		return {}
	var merged: Dictionary = {}
	var instructions := 0
	for modifier in _modifiers:
		var matches := true
		for condition in modifier["when"]:
			instructions += 1
			if instructions > MAX_INSTRUCTIONS:
				return {"error": "超过单次决策的 128 次比较预算"}
			if not _matches(view, condition):
				matches = false
				break
		if not matches:
			continue
		for behavior in modifier["weights"]:
			if not view["candidates"].has(behavior):
				continue
			var amount := float(modifier["weights"][behavior])
			merged[behavior] = float(merged.get(behavior, 1.0)) * amount
	if merged.is_empty():
		return {}
	var positive := false
	for value in merged.values():
		if float(value) > 0.0:
			positive = true
	if not positive:
		return {"error": "覆盖补丁没有正权重"}
	return {"weights": merged}


## Restricts a patch to the declared role, position and duty before any condition runs.
func _scope_matches(view: Dictionary) -> bool:
	if _scope.is_empty():
		return true
	var self_view: Dictionary = view.get("self", {})
	for key in _scope:
		if str(self_view.get(key, "")) != str(_scope[key]):
			return false
	return true


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
