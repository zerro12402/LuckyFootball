## Sends DeepSeek chat completions over HTTPS and normalizes every failure for the UI.
class_name DeepSeekTransport
extends Node

const ENDPOINT := "https://api.deepseek.com/chat/completions"
const MODEL := "deepseek-chat"
const TIMEOUT_SECONDS := 30.0

var _request: HTTPRequest
var _cancelled := false


func _ready() -> void:
	_ensure_request()


## Performs one request; callers await the returned dictionary.
func post(messages: Array, api_key: String, model: String = MODEL) -> Dictionary:
	if api_key.strip_edges().is_empty():
		return {"ok": false, "error_kind": "MISSING_KEY", "error": "未配置 DeepSeek Key", "status": 0}
	_ensure_request()
	_cancelled = false
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key.strip_edges(),
	])
	var body := JSON.stringify({
		"model": model,
		"messages": messages,
		"temperature": 0.2,
		"max_tokens": 2048,
		"response_format": {"type": "json_object"},
	})
	var started := _request.request(ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	if started != OK:
		return {"ok": false, "error_kind": "NETWORK", "error": error_string(started), "status": 0}
	var completed: Array = await _request.request_completed
	return normalize(completed[0], completed[1], completed[3], _cancelled)


## Stops the in-flight request; the pending completion resolves as CANCELLED.
func cancel() -> void:
	_cancelled = true
	if _request != null:
		_request.cancel_request()


func is_busy() -> bool:
	return _request != null and _request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED


## Maps the raw HTTPRequest outcome without reading the network, so tests run offline.
static func normalize(result: int, status: int, body: PackedByteArray, cancelled: bool = false) -> Dictionary:
	if cancelled:
		return _error("CANCELLED", "已取消", status)
	if result == HTTPRequest.RESULT_REQUEST_FAILED:
		return _error("TIMEOUT", "请求超时或中断", status)
	if result != HTTPRequest.RESULT_SUCCESS:
		return _error("NETWORK", "网络错误：%d" % result, status)
	if status == 401:
		return _error("AUTH", "Key 无效", status)
	if status == 402:
		return _error("PAYMENT", "余额不足", status)
	if status == 429:
		return _error("RATE_LIMIT", "请求过于频繁", status)
	if status < 200 or status >= 300:
		return _error("HTTP", "HTTP %d" % status, status)
	var text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return _error("HTTP", "响应不是 JSON", status)
	var choices: Variant = parsed.get("choices")
	if not choices is Array or choices.is_empty() or not choices[0] is Dictionary:
		return _error("EMPTY_RESPONSE", "响应缺少 choices", status)
	var message: Variant = choices[0].get("message")
	var content := str(message.get("content", "")) if message is Dictionary else ""
	if content.strip_edges().is_empty():
		return _error("EMPTY_RESPONSE", "模型返回为空", status)
	var finish_reason := str(choices[0].get("finish_reason", ""))
	if finish_reason == "length":
		return {"ok": false, "error_kind": "TRUNCATED", "error": "输出被截断", "status": status,
			"content": content, "finish_reason": finish_reason}
	return {"ok": true, "content": content, "finish_reason": finish_reason, "status": status,
		"error_kind": "", "error": ""}


static func _error(kind: String, message: String, status: int) -> Dictionary:
	return {"ok": false, "error_kind": kind, "error": message, "status": status,
		"content": "", "finish_reason": ""}


func _ensure_request() -> void:
	if _request != null:
		return
	_request = HTTPRequest.new()
	_request.timeout = TIMEOUT_SECONDS
	_request.use_threads = true
	add_child(_request)
