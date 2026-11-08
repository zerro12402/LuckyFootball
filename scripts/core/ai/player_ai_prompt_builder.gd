## Builds versioned prompts that keep the model inside the public overlay contract.
class_name PlayerAIPromptBuilder
extends RefCounted

const PROMPT_VERSION := 1
const MAX_DESCRIPTION_CHARS := 500

var _manual: String


func _init(manual: String) -> void:
	_manual = manual


func messages(description: String, context: Dictionary = {}) -> Array[Dictionary]:
	return [
		{"role": "system", "content": system_text()},
		{"role": "user", "content": user_text(description, context)},
	]


## Describes the default overlay shape, the closed scope keys and the hard limits.
func system_text() -> String:
	return "你是《幸运足球》的球员 AI 脚本生成器。只输出一个 JSON 对象，不要解释。\n" \
		+ "默认输出 version 3 覆盖补丁：{\"version\":3,\"mode\":\"overlay\",\"scope\":{...}," \
		+ "\"modifiers\":[{\"when\":[[字段,比较符,值]],\"weights\":{行为:倍率}}]}。\n" \
		+ "规则：只覆盖玩家明确提到的角色、位置、职责、阶段和行为，未提到的局面不要写 modifier；" \
		+ "scope 只能使用 role、position、duty；不要新增行为、字段或比赛规则；" \
		+ "动作无法映射到现有行为时忽略，不要编造。\n" \
		+ "仅当玩家明确要求重写整队时，才输出 version 2 的 rules/default 整份脚本。\n\n" \
		+ "脚本手册：\n" + _manual


## Keeps the player's words short, explicit and free of match state.
func user_text(description: String, context: Dictionary = {}) -> String:
	var text := "战术描述：" + description.strip_edges().substr(0, MAX_DESCRIPTION_CHARS)
	if not context.is_empty():
		text += "\n上下文：" + JSON.stringify(context)
	return text
