extends Node

signal agent_request_finished
signal night_request_finished

const DEFAULT_BASE_URL := "http://127.0.0.1:5173"

var base_url: String = DEFAULT_BASE_URL
var use_http_ai: bool = true
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_load_config()


func _load_config() -> void:
	var cfg := load("res://data/game_config.tres") as GameConfig
	if cfg == null:
		return
	base_url = str(cfg.api_base_url).trim_suffix("/")
	use_http_ai = cfg.use_http_ai
	GameManager.use_http_ai = use_http_ai


func request_agent(agent_id: String, user_message: String) -> void:
	_pending_kind = "agent"
	_pending_agent = agent_id
	var history := _history_for_api(GameManager.conversations[agent_id], user_message)
	var body := {
		"agentId": agent_id,
		"history": history,
		"userMessage": user_message,
		"ctx": _build_ctx(),
	}
	_post("/api/agent", body)


func request_night() -> void:
	_pending_kind = "night"
	_pending_agent = ""
	GameManager.request_pending = true
	GameManager.state_changed.emit()
	var recent: Array = []
	for aid in GameManager.AGENT_IDS:
		var conv: Array = GameManager.conversations[aid]
		var count := 0
		for i in range(conv.size() - 1, -1, -1):
			if conv[i].get("role") == "user":
				recent.append({"agent": aid, "line": conv[i].get("content", "")})
				count += 1
				if count >= 3:
					break
	var body := {
		"day": GameManager.day,
		"trust": {
			"commander": GameManager.agents["commander"]["trust"],
			"citizen": GameManager.agents["citizen"]["trust"],
			"priest": GameManager.agents["priest"]["trust"],
		},
		"priestFear": GameManager.agents["priest"]["fear"],
		"priestSpilledDirt": GameManager.priest_spilled_dirt,
		"citizenOfferedBlackmail": GameManager.citizen_offered_blackmail,
		"citizenAcceptedDirt": GameManager.citizen_accepted_dirt,
		"proof": GameManager.proof,
		"suspicion": GameManager.suspicion,
		"recentPlayerLines": recent,
	}
	_post("/api/night", body)


func _history_for_api(conversation: Array, user_message: String) -> Array:
	# Match React: history excludes the current line; userMessage is sent separately.
	var history: Array = []
	for msg in conversation:
		history.append({"role": msg.get("role", ""), "content": msg.get("content", "")})
	if not history.is_empty():
		var last: Dictionary = history[-1]
		if last.get("role") == "user" and last.get("content") == user_message:
			history.pop_back()
	return history


func _build_ctx() -> Dictionary:
	return {
		"day": GameManager.day,
		"trust": {
			"commander": GameManager.agents["commander"]["trust"],
			"citizen": GameManager.agents["citizen"]["trust"],
			"priest": GameManager.agents["priest"]["trust"],
		},
		"priestFear": GameManager.agents["priest"]["fear"],
		"citizenOfferedBlackmail": GameManager.citizen_offered_blackmail,
		"citizenAcceptedDirt": GameManager.citizen_accepted_dirt,
		"citizenEndorsedCommander": GameManager.citizen_endorsed_commander,
		"priestSpilledDirt": GameManager.priest_spilled_dirt,
		"proof": GameManager.proof,
		"suspicion": GameManager.suspicion,
	}


func _post(path: String, body: Dictionary) -> void:
	var url := base_url + path
	var json := JSON.stringify(body)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, json)
	if err != OK:
		_notify_error("Could not reach the court (%s)." % error_string(err))


var _pending_kind: String = ""
var _pending_agent: String = ""


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if _pending_kind == "night":
		GameManager.request_pending = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_notify_error("Network failure — is court-of-whispers running? (%s)" % base_url)
		return

	var raw_text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(raw_text)

	if response_code == 429:
		_notify_error("Too many requests. Wait and try again.")
		return
	if response_code == 402:
		_notify_error("AI credits exhausted on the server.")
		return
	if response_code < 200 or response_code >= 300:
		var detail := ""
		if parsed is Dictionary and parsed.has("error"):
			detail = ": " + str(parsed["error"])
		_notify_error("Server returned %d%s" % [response_code, detail])
		return

	if parsed == null:
		_notify_error("Invalid JSON from server.")
		return

	if _pending_kind == "agent":
		if parsed is Dictionary and parsed.has("error"):
			_notify_error(str(parsed["error"]))
			return
		var delta := _camel_to_delta(parsed)
		var dialogue := get_tree().get_first_node_in_group("dialogue_controller")
		if dialogue and dialogue.has_method("on_agent_response"):
			dialogue.on_agent_response(delta)
		else:
			GameManager.request_pending = false
			GameManager.apply_delta(_pending_agent, delta)
		agent_request_finished.emit()
	elif _pending_kind == "night":
		var exchanges: Array = []
		if parsed is Dictionary:
			exchanges = parsed.get("exchanges", [])
		GameManager.apply_night_exchanges(_normalize_night_exchanges(exchanges))
		night_request_finished.emit()

	_pending_kind = ""


func _normalize_night_exchanges(exchanges: Array) -> Array:
	var out: Array = []
	for e in exchanges:
		if e is not Dictionary:
			continue
		var fx: Dictionary = e.get("effects", {})
		out.append({
			"day": e.get("day", GameManager.day),
			"from": e.get("from", ""),
			"to": e.get("to", ""),
			"line": e.get("line", ""),
			"reply": e.get("reply", ""),
			"effects": {
				"suspicion_delta": _fx_int(fx, "suspicion_delta", "suspicionDelta"),
				"proof_delta": _fx_int(fx, "proof_delta", "proofDelta"),
				"proof_evidence": _fx_str(fx, "proof_evidence", "proofEvidence"),
				"trust_deltas": _fx_trust(fx),
			},
		})
	return out


func _fx_int(fx: Dictionary, snake: String, camel: String) -> int:
	if fx.has(snake):
		return int(fx[snake])
	if fx.has(camel):
		return int(fx[camel])
	return 0


func _fx_str(fx: Dictionary, snake: String, camel: String) -> String:
	if fx.has(snake):
		return str(fx[snake])
	if fx.has(camel):
		return str(fx[camel])
	return ""


func _fx_trust(fx: Dictionary) -> Dictionary:
	if fx.has("trust_deltas"):
		return fx["trust_deltas"]
	if fx.has("trustDeltas"):
		return fx["trustDeltas"]
	return {}


func _camel_to_delta(raw: Dictionary) -> Dictionary:
	return {
		"reply": raw.get("reply", "..."),
		"mood": str(raw.get("mood", "neutral")),
		"trust_delta": raw.get("trustDelta"),
		"fear_delta": raw.get("fearDelta"),
		"citizen_offer_blackmail": raw.get("citizenOfferBlackmail", false),
		"citizen_accept_dirt": raw.get("citizenAcceptDirt", false),
		"citizen_endorse": raw.get("citizenEndorse", false),
		"spill_dirt": raw.get("spillDirt", []),
		"proof_delta": raw.get("proofDelta", 0),
		"proof_evidence": raw.get("proofEvidence", ""),
		"gossip_score": raw.get("gossipScore", 0),
		"perform_coup": raw.get("performCoup", false),
		"inform_bishop": raw.get("informBishop", false),
		"inform_king": raw.get("informKing", false),
	}


func _notify_error(msg: String) -> void:
	GameManager.request_pending = false
	var dialogue := get_tree().get_first_node_in_group("dialogue_controller")
	if dialogue and dialogue.has_method("on_agent_error"):
		dialogue.on_agent_error(msg)
	if _pending_kind == "night":
		StubDialogue.run_night(GameManager)
	_pending_kind = ""
	GameManager.state_changed.emit()
