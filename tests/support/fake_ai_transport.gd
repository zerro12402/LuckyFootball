## Returns queued responses so generation tests never touch the network.
extends RefCounted

var responses: Array[Dictionary] = []
var calls: Array[Array] = []


## Feeds the next queued reply and records the outgoing messages.
func post(messages: Array, _api_key: String) -> Dictionary:
	calls.append(messages.duplicate(true))
	if responses.is_empty():
		return {"ok": false, "error_kind": "NETWORK", "error": "no queued response", "status": 0,
			"content": "", "finish_reason": ""}
	return responses.pop_front()
