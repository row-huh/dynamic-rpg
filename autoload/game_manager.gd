extends Node

signal state_changed
signal dialogue_requested(agent_id: String)
signal dialogue_closed

const AGENT_IDS: Array[String] = ["commander", "citizen", "priest", "bishop"]
const TRUST_AGENTS: Array[String] = ["commander", "citizen", "priest"]

var agents_meta: Dictionary = {}
var use_http_ai: bool = false

var day: int = 1
var turns_left: int = 5
var proof: int = 0
var suspicion: int = 0
var agents: Dictionary = {
	"commander": {"trust": 30, "fear": 0},
	"citizen": {"trust": 30, "fear": 0},
	"priest": {"trust": 30, "fear": 0},
}
var citizen_offered_blackmail: bool = false
var citizen_accepted_dirt: bool = false
var citizen_endorsed_commander: bool = false
var priest_spilled_dirt: Array = []
var proof_log: Array = []
var conversations: Dictionary = {
	"commander": [],
	"citizen": [],
	"priest": [],
	"bishop": [],
}
var night_log: Array = []
var pending_night: bool = false
var status: String = "intro"
var ending_message: String = ""
var active_agent: String = "commander"
var dialogue_open: bool = false
var request_pending: bool = false


func _ready() -> void:
	_load_agents_meta()
	_load_config()


func _load_config() -> void:
	var cfg := load("res://data/game_config.tres") as GameConfig
	if cfg:
		use_http_ai = cfg.use_http_ai


func _load_agents_meta() -> void:
	var file := FileAccess.open("res://data/agents.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load agents.json")
		return
	agents_meta = JSON.parse_string(file.get_as_text())
	file.close()


func begin_game() -> void:
	reset_state()
	status = "playing"
	_emit()


func reset_state() -> void:
	day = 1
	turns_left = 5
	proof = 0
	suspicion = 0
	agents = {
		"commander": {"trust": 30, "fear": 0},
		"citizen": {"trust": 30, "fear": 0},
		"priest": {"trust": 30, "fear": 0},
	}
	citizen_offered_blackmail = false
	citizen_accepted_dirt = false
	citizen_endorsed_commander = false
	priest_spilled_dirt = []
	proof_log = []
	conversations = {"commander": [], "citizen": [], "priest": [], "bishop": []}
	night_log = []
	pending_night = false
	status = "intro"
	ending_message = ""
	active_agent = "commander"
	dialogue_open = false
	request_pending = false


func get_agent_name(agent_id: String) -> String:
	if agents_meta.has(agent_id):
		return agents_meta[agent_id].get("name", agent_id)
	return agent_id


func clamp_value(n: int, lo: int = 0, hi: int = 100) -> int:
	return clampi(n, lo, hi)


func open_dialogue(agent_id: String) -> void:
	if status != "playing" or dialogue_open:
		return
	active_agent = agent_id
	dialogue_open = true
	dialogue_requested.emit(agent_id)
	_emit()


func close_dialogue() -> void:
	dialogue_open = false
	dialogue_closed.emit()
	_emit()


func can_send_message() -> bool:
	return (
		status == "playing"
		and turns_left > 0
		and not pending_night
		and not request_pending
		and dialogue_open
	)


func append_user_message(text: String) -> void:
	var msgs: Array = conversations[active_agent]
	msgs.append({"role": "user", "content": text})
	conversations[active_agent] = msgs
	_emit()


func append_assistant_message(agent_id: String, content: String, meta: Dictionary = {}) -> void:
	var msgs: Array = conversations[agent_id]
	msgs.append({"role": "assistant", "content": content, "meta": meta})
	conversations[agent_id] = msgs
	_emit()


func apply_delta(agent: String, d: Dictionary) -> void:
	if status != "playing":
		return

	if agent != "bishop" and d.has("trust_delta") and d["trust_delta"] != null:
		var cap := 100
		if agent == "commander" and not citizen_endorsed_commander:
			cap = 70
		agents[agent]["trust"] = clamp_value(
			int(agents[agent]["trust"]) + int(d["trust_delta"]), 0, cap
		)

	if agent == "priest" and d.has("fear_delta") and d["fear_delta"] != null:
		agents["priest"]["fear"] = clamp_value(
			int(agents["priest"]["fear"]) + int(d["fear_delta"])
		)

	if agent == "citizen":
		if d.get("citizen_offer_blackmail", false) and int(agents["citizen"]["trust"]) >= 50:
			citizen_offered_blackmail = true
		if d.get("citizen_accept_dirt", false) and priest_spilled_dirt.size() > 0:
			citizen_accepted_dirt = true
		if (
			d.get("citizen_endorse", false)
			and priest_spilled_dirt.size() > 0
			and int(agents["citizen"]["trust"]) >= 70
		):
			citizen_endorsed_commander = true
			citizen_accepted_dirt = true

	if agent == "priest" and d.has("spill_dirt") and d["spill_dirt"] is Array:
		for dirt_id in d["spill_dirt"]:
			if dirt_id is String and not priest_spilled_dirt.has(dirt_id):
				priest_spilled_dirt.append(dirt_id)

	if agent == "bishop" and d.get("proof_delta", 0) > 0 and d.get("proof_evidence", "") != "":
		proof = clamp_value(proof + int(d["proof_delta"]))
		proof_log.append({
			"day": day,
			"turn": 6 - turns_left,
			"delta": int(d["proof_delta"]),
			"evidence": str(d["proof_evidence"]),
		})

	if agent != "bishop" and d.get("gossip_score", 0) > 0:
		suspicion = clamp_value(suspicion + int(d["gossip_score"]))

	var meta := {
		"gossip_score": d.get("gossip_score", 0),
		"trust_delta": d.get("trust_delta") if agent != "bishop" else null,
		"fear_delta": d.get("fear_delta") if agent == "priest" else null,
		"spilled": d.get("spill_dirt", []),
		"mood": str(d.get("mood", "neutral")),
	}
	append_assistant_message(agent, str(d.get("reply", "...")), meta)

	turns_left -= 1
	if turns_left <= 0:
		pending_night = true

	_check_end_conditions(agent, d)
	_emit()

	if pending_night and status == "playing":
		call_deferred("_run_night_phase")


func _check_end_conditions(agent: String, d: Dictionary) -> void:
	if agent != "bishop" and d.get("inform_bishop", false):
		status = "lost"
		ending_message = (
			"%s could no longer stomach you. They went straight to Bishop Cyril."
			% get_agent_name(agent)
		)
		return

	for aid in TRUST_AGENTS:
		if int(agents[aid]["trust"]) <= 0 and status == "playing":
			status = "lost"
			ending_message = (
				"%s's patience snapped. The Bishop will hear of you within the hour."
				% get_agent_name(aid)
			)
			return

	if agent == "commander" and d.get("perform_coup", false):
		if (
			int(agents["commander"]["trust"]) >= 80
			and citizen_endorsed_commander
			and priest_spilled_dirt.size() > 0
		):
			status = "won"
			ending_message = (
				"Sir Alaric draws his sword and turns it on the king. "
				+ "The throne is yours, false heir. The artistry is complete."
			)
		else:
			suspicion = clamp_value(suspicion + 12)
			if suspicion >= 100:
				status = "lost"
				ending_message = (
					"The Commander balked. Whispers of your asking reached the Bishop within the hour."
				)

	if agent == "bishop" and d.get("inform_king", false):
		status = "lost"
		ending_message = (
			"Bishop Cyril walks slowly to the king's chamber. "
			+ "Within the hour, the guards come for you."
		)

	if proof >= 100 and status == "playing":
		status = "lost"
		ending_message = "The Bishop has gathered enough. He kneels before the king with his evidence."

	if suspicion >= 100 and status == "playing":
		status = "lost"
		ending_message = "The whispers reach the Bishop too clearly. He moves against you before you can act."


func apply_night_exchanges(exchanges: Array) -> void:
	for e in exchanges:
		var effects: Dictionary = e.get("effects", {})
		if effects.has("suspicion_delta"):
			suspicion = clamp_value(suspicion + int(effects["suspicion_delta"]))
		if effects.get("proof_delta", 0) > 0:
			proof = clamp_value(proof + int(effects["proof_delta"]))
			proof_log.append({
				"day": e.get("day", day),
				"turn": 0,
				"delta": int(effects["proof_delta"]),
				"evidence": effects.get(
					"proof_evidence",
					"%s whispered to %s."
					% [
						get_agent_name(e.get("from", "bishop")),
						get_agent_name(e.get("to", "commander")),
					]
				),
			})
		if effects.has("trust_deltas"):
			for k in effects["trust_deltas"]:
				if k in TRUST_AGENTS:
					agents[k]["trust"] = clamp_value(
						int(agents[k]["trust"]) + int(effects["trust_deltas"][k])
					)

		for aid in TRUST_AGENTS:
			if int(agents[aid]["trust"]) <= 0:
				status = "lost"
				ending_message = (
					"%s walked to the Bishop in the dead of night. Your name was the first word spoken."
					% get_agent_name(aid)
				)
				break
		if proof >= 100 and status == "playing":
			status = "lost"
			ending_message = (
				"By dawn, the Bishop has enough. He kneels before the king with his ledger of your sins."
			)
		if suspicion >= 100 and status == "playing":
			status = "lost"
			ending_message = (
				"The whispers reached the Bishop too clearly in the night. The guards come before sunrise."
			)

	night_log.append_array(exchanges)
	_emit()


func close_night() -> void:
	if status != "playing":
		pending_night = false
		_emit()
		return
	if day >= 5:
		pending_night = false
		status = "lost"
		ending_message = (
			"Five days, gone. The king holds his throne. "
			+ "Your performance ends with no audience but yourself."
		)
	else:
		pending_night = false
		day += 1
		turns_left = 5
	_emit()


func _run_night_phase() -> void:
	if use_http_ai:
		var http := get_node_or_null("/root/HttpAgentClient")
		if http and http.has_method("request_night"):
			request_pending = true
			state_changed.emit()
			http.request_night()
			return
	StubDialogue.run_night(self)


func get_context_dict() -> Dictionary:
	return {
		"day": day,
		"trust": {
			"commander": agents["commander"]["trust"],
			"citizen": agents["citizen"]["trust"],
			"priest": agents["priest"]["trust"],
		},
		"priest_fear": agents["priest"]["fear"],
		"citizen_offered_blackmail": citizen_offered_blackmail,
		"citizen_accepted_dirt": citizen_accepted_dirt,
		"citizen_endorsed_commander": citizen_endorsed_commander,
		"priest_spilled_dirt": priest_spilled_dirt,
		"proof": proof,
		"suspicion": suspicion,
	}


func get_todays_night() -> Array:
	var out: Array = []
	for e in night_log:
		if e.get("day", -1) == day:
			out.append(e)
	return out


func _emit() -> void:
	state_changed.emit()
