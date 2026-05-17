class_name StubDialogue

const OPENERS := {
	"commander": [
		"State your business, stranger. I have no patience for court gossip.",
		"The realm bleeds coin while the throne smiles. Speak plainly if you must.",
	],
	"citizen": [
		"You look like trouble. The market has ears, you know.",
		"Mira's the name. If you're here to sell dreams, save your breath.",
	],
	"priest": [
		"Peace be upon you... though you bring a storm in your eyes.",
		"Father Edran. The chapel is open, but my conscience is not.",
	],
	"bishop": [
		"Ah. Another soul seeking counsel. I listen more than I speak.",
		"Bishop Cyril. The king's shepherd. How may I guide you?",
	],
}

const REPLIES := {
	"commander": [
		"Words are wind. Bring me proof, or bring me silence.",
		"Mira's word weighs more than yours. Remember that.",
		"I serve the peace of the realm — not every rumor about the crown.",
	],
	"citizen": [
		"The people hunger while the palace feasts. We both know it.",
		"Perhaps... there is leverage on the priest. But trust must be earned first.",
		"Bring me something real from the palace, and we may speak of endorsements.",
	],
	"priest": [
		"I... I should not speak of what I have seen in those halls.",
		"Your threats cut deeper than your smile. Very well — listen closely.",
		"The king's seal was broken once, in the eastern vault. I said too much.",
	],
	"bishop": [
		"Interesting. I shall remember you said that.",
		"The king is well served. Be careful what you confess in God's house.",
		"Your tongue moves faster than your wisdom.",
	],
}

const NIGHT_STUB := [
	{
		"day": 0,
		"from": "citizen",
		"to": "priest",
		"line": "Did you hear the stranger asking questions in the market?",
		"reply": "I... I pray for guidance. These are dark days.",
		"effects": {"suspicion_delta": 4},
	},
	{
		"day": 0,
		"from": "commander",
		"to": "bishop",
		"line": "A wanderer sought my oath today. I sent them away.",
		"reply": "Wise. The crown has enough enemies without new ones.",
		"effects": {"proof_delta": 0},
	},
]


static func pick_opener(agent_id: String) -> String:
	var lines: Array = OPENERS.get(agent_id, ["..."])
	return lines[randi() % lines.size()]


static func mood_for_opener(agent_id: String) -> String:
	match agent_id:
		"commander":
			return "serious"
		"citizen":
			return "neutral"
		"priest":
			return "worried"
		"bishop":
			return "neutral"
	return "neutral"


static func generate_delta(agent_id: String, user_text: String, gm: Node) -> Dictionary:
	var lower := user_text.to_lower()
	var reply_pool: Array = REPLIES.get(agent_id, ["..."])
	var reply: String = reply_pool[randi() % reply_pool.size()]
	var delta := {"reply": reply, "mood": "neutral"}

	var trust_delta := 0
	var fear_delta := 0
	var gossip_score := 0
	var proof_delta := 0
	var proof_evidence := ""

	if lower.contains("treason") or lower.contains("coup") or lower.contains("king"):
		gossip_score = 10
		trust_delta = -2
		delta["mood"] = "serious"
	if lower.contains("proof") or lower.contains("evidence") or lower.contains("ledger"):
		trust_delta += 3
		delta["mood"] = "serious"
	if lower.contains("thank") or lower.contains("honor"):
		trust_delta += 2
		delta["mood"] = "happy"
	if lower.contains("lie") or lower.contains("threat"):
		trust_delta -= 4
		delta["mood"] = "angry"

	if agent_id == "priest":
		if lower.contains("secret") or lower.contains("blackmail") or lower.contains("fear"):
			fear_delta = 8
			delta["mood"] = "worried"
			reply = "You play a dangerous game. The vault... the seal was forged. I should not have said that."
			if int(gm.agents["priest"]["fear"]) + fear_delta >= 40 and not gm.priest_spilled_dirt.has("bastard"):
				delta["spill_dirt"] = ["bastard"]
		if lower.contains("leverage") and gm.citizen_offered_blackmail:
			fear_delta = 5

	if agent_id == "citizen":
		if int(gm.agents["citizen"]["trust"]) >= 50 and not gm.citizen_offered_blackmail:
			if lower.contains("priest") or lower.contains("leverage"):
				delta["citizen_offer_blackmail"] = true
				reply = "I know where Edran sins. Use it wisely — he cracks under pressure."
		if gm.priest_spilled_dirt.size() > 0 and int(gm.agents["citizen"]["trust"]) >= 70:
			if lower.contains("endorse") or lower.contains("commander") or lower.contains("alaric"):
				delta["citizen_endorse"] = true
				reply = "I'll vouch for you to Alaric. Don't waste what we built."

	if agent_id == "commander":
		if lower.contains("coup") or lower.contains("sword") or lower.contains("draw"):
			delta["perform_coup"] = true
			reply = "You ask me to betray my oath? Bold — or foolish."

	if agent_id == "bishop":
		if gossip_score > 0 or lower.contains("heir") or lower.contains("false"):
			proof_delta = 8
			proof_evidence = "Player spoke of: " + user_text.substr(0, 80)
			delta["mood"] = "serious"
		if lower.contains("kill") and lower.contains("king"):
			delta["inform_king"] = true
			delta["mood"] = "shocked"
			reply = "I must speak with His Majesty. Your game ends tonight."

	if agent_id != "bishop" and trust_delta != 0:
		delta["trust_delta"] = trust_delta
	if agent_id == "priest" and fear_delta != 0:
		delta["fear_delta"] = fear_delta
	if gossip_score > 0 and agent_id != "bishop":
		delta["gossip_score"] = gossip_score
	if proof_delta > 0:
		delta["proof_delta"] = proof_delta
		delta["proof_evidence"] = proof_evidence

	delta["reply"] = reply
	return delta


static func run_night(gm: Node) -> void:
	var exchanges: Array = []
	for template in NIGHT_STUB:
		var e: Dictionary = template.duplicate(true)
		e["day"] = gm.day
		exchanges.append(e)
	if gm.suspicion > 30:
		exchanges.append({
			"day": gm.day,
			"from": "bishop",
			"to": "commander",
			"line": "The court whispers of a false heir. Watch the roads.",
			"reply": "I'll double the patrols.",
			"effects": {"suspicion_delta": 6},
		})
	gm.apply_night_exchanges(exchanges)
