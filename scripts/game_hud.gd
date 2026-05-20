extends Control

@onready var day_label: Label = %DayLabel
@onready var turns_label: Label = %TurnsLabel
@onready var proof_bar: ProgressBar = %ProofBar
@onready var suspicion_bar: ProgressBar = %SuspicionBar
@onready var commander_trust: ProgressBar = %CommanderTrust
@onready var citizen_trust: ProgressBar = %CitizenTrust
@onready var priest_trust: ProgressBar = %PriestTrust
@onready var priest_fear: ProgressBar = %PriestFear
@onready var commander_trust_val: Label = %CommanderTrustVal
@onready var citizen_trust_val: Label = %CitizenTrustVal
@onready var priest_trust_val: Label = %PriestTrustVal
@onready var priest_fear_val: Label = %PriestFearVal
@onready var proof_val: Label = %ProofVal
@onready var suspicion_val: Label = %SuspicionVal
@onready var quest_label: RichTextLabel = %QuestLabel

var _last_day: int = -1

const POLL_INTERVAL := 2.5  # seconds between backend polls

var _http_poll: HTTPRequest
var _poll_timer: Timer
var _is_polling: bool = false  # guard: don't stack requests
var _base_url: String = "https://tanstack-start-app.court-of-whispers.workers.dev/"


var _last_local_change_time: int = 0
var _last_applied_updated_at: int = 0


func _ready() -> void:
	# Load base URL from game config
	var cfg := load("res://data/game_config.tres") as GameConfig
	if cfg:
		_base_url = str(cfg.api_base_url).trim_suffix("/")

	# Dedicated HTTPRequest for polling (separate from agent dialogue requests)
	_http_poll = HTTPRequest.new()
	add_child(_http_poll)
	_http_poll.request_completed.connect(_on_poll_completed)

	# Timer for periodic polling
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.autostart = false
	_poll_timer.timeout.connect(_poll_state)
	add_child(_poll_timer)

	GameManager.state_changed.connect(_refresh)
	GameManager.dialogue_closed.connect(_on_local_change)
	
	var http := get_node_or_null("/root/HttpAgentClient")
	if http:
		if http.has_signal("agent_request_finished"):
			http.agent_request_finished.connect(_on_local_change)
		if http.has_signal("night_request_finished"):
			http.night_request_finished.connect(_on_local_change)
			
	_refresh()


func _on_local_change() -> void:
	_last_local_change_time = Time.get_ticks_msec()


func start_polling() -> void:
	if not _poll_timer.is_stopped():
		return
	_poll_timer.start()
	_poll_state()  # immediate first poll when drawer opens


func stop_polling() -> void:
	_poll_timer.stop()


func _poll_state() -> void:
	# Only poll when the game is actually running and HTTP AI is enabled
	if _is_polling or GameManager.status != "playing" or not GameManager.use_http_ai:
		return
	_is_polling = true
	var url := _base_url + "/api/state"
	_http_poll.request(url, PackedStringArray(["Accept: application/json"]), HTTPClient.METHOD_GET)


func _on_poll_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_is_polling = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return  # silently skip bad responses — don't break the game

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed is Dictionary:
		return

	# Apply server state into GameManager so _refresh picks it up
	_apply_server_state(parsed)
	_refresh()


func _apply_server_state(s: Dictionary) -> void:
	# Avoid race conditions: ignore background polls for 5 seconds after local updates
	if Time.get_ticks_msec() - _last_local_change_time < 5000:
		return

	# Only update if server snapshot is newer than our last change
	# (updatedAt 0 means server has never received a push — skip)
	var updated_at: int = int(s.get("updatedAt", 0))
	if updated_at == 0 or updated_at <= _last_applied_updated_at:
		return

	_last_applied_updated_at = updated_at


	if s.has("day"):
		GameManager.day = int(s["day"])
	if s.has("turnsLeft"):
		GameManager.turns_left = int(s["turnsLeft"])
	if s.has("proof"):
		GameManager.proof = int(s["proof"])
	if s.has("suspicion"):
		GameManager.suspicion = int(s["suspicion"])
	if s.has("priestFear"):
		GameManager.agents["priest"]["fear"] = int(s["priestFear"])
	if s.has("trust") and s["trust"] is Dictionary:
		var t: Dictionary = s["trust"]
		if t.has("commander"):
			GameManager.agents["commander"]["trust"] = int(t["commander"])
		if t.has("citizen"):
			GameManager.agents["citizen"]["trust"] = int(t["citizen"])
		if t.has("priest"):
			GameManager.agents["priest"]["trust"] = int(t["priest"])
	if s.has("citizenOfferedBlackmail"):
		GameManager.citizen_offered_blackmail = bool(s["citizenOfferedBlackmail"])
	if s.has("citizenAcceptedDirt"):
		GameManager.citizen_accepted_dirt = bool(s["citizenAcceptedDirt"])
	if s.has("citizenEndorsedCommander"):
		GameManager.citizen_endorsed_commander = bool(s["citizenEndorsedCommander"])
	if s.has("priestSpilledDirt") and s["priestSpilledDirt"] is Array:
		GameManager.priest_spilled_dirt = s["priestSpilledDirt"]


func _refresh() -> void:
	if GameManager.status != "playing":
		return
	day_label.text = "Day %d of 5" % GameManager.day
	turns_label.text = "%d words left today" % GameManager.turns_left

	proof_bar.value = GameManager.proof
	proof_val.text = str(GameManager.proof)
	suspicion_bar.value = GameManager.suspicion
	suspicion_val.text = str(GameManager.suspicion)

	commander_trust.value = GameManager.agents["commander"]["trust"]
	commander_trust_val.text = str(GameManager.agents["commander"]["trust"])

	citizen_trust.value = GameManager.agents["citizen"]["trust"]
	citizen_trust_val.text = str(GameManager.agents["citizen"]["trust"])

	priest_trust.value = GameManager.agents["priest"]["trust"]
	priest_trust_val.text = str(GameManager.agents["priest"]["trust"])

	priest_fear.value = GameManager.agents["priest"]["fear"]
	priest_fear_val.text = str(GameManager.agents["priest"]["fear"])

	if GameManager.day != _last_day:
		if _last_day != -1:
			_pulse_day_label()
		_last_day = GameManager.day
	
	var quests: Array[String] = []
	var q1_done = GameManager.citizen_offered_blackmail
	var q2_done = not GameManager.priest_spilled_dirt.is_empty()
	var q3_done = GameManager.citizen_accepted_dirt
	var q4_done = GameManager.agents["commander"]["trust"] >= 80
	var q5_done = GameManager.status == "won"

	quests.append(_format_quest("Earn Mira's faith — she offers leverage on the priest", q1_done))
	quests.append(_format_quest("Press Father Edran for palace dirt", q2_done))
	quests.append(_format_quest("Bring the dirt back to Mira — she endorses you", q3_done))
	quests.append(_format_quest("Use the dirt to turn Sir Alaric", q4_done))
	quests.append(_format_quest("Convince the Commander to perform the coup", q5_done))

	quest_label.text = "[b][color=#d4a648]Your Path[/color][/b]\n\n" + "\n\n".join(quests)

func _format_quest(text: String, is_done: bool) -> String:
	if is_done:
		return "  [color=#6b5f52][s]● %s[/s][/color]" % text
	return "  [color=#d4a648]○ %s[/color]" % text

func _pulse_day_label() -> void:
	var tween = create_tween()
	tween.tween_property(day_label, "modulate", Color(0.83, 0.65, 0.28, 1), 0.2)
	tween.tween_property(day_label, "modulate", Color(1, 1, 1, 1), 0.5)
