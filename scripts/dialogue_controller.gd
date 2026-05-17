extends Control

enum State {
	IDLE,
	SHOWING_LINE,
	AWAITING_CONTINUE,
	AWAITING_INPUT,
	WAITING_AI,
}

@onready var jrpg_box = %JrpgDialogueBox
@onready var input_modal = %PlayerInputModal

var _state: State = State.IDLE
var _agent_id: String = ""


func _ready() -> void:
	add_to_group("dialogue_controller")
	visible = true
	jrpg_box.hide_box()
	input_modal.close_modal()

	jrpg_box.continue_pressed.connect(_on_continue_pressed)
	jrpg_box.close_pressed.connect(_on_close)
	input_modal.submitted.connect(_on_input_submitted)
	input_modal.cancelled.connect(_on_input_cancelled)

	jrpg_box.line_finished.connect(_on_line_finished)

	GameManager.dialogue_requested.connect(_on_dialogue_open)
	GameManager.dialogue_closed.connect(_on_dialogue_closed)
	GameManager.state_changed.connect(_on_state_changed)


func _on_dialogue_open(agent_id: String) -> void:
	_agent_id = agent_id
	_state = State.SHOWING_LINE
	jrpg_box.show_box()

	var meta: Dictionary = GameManager.agents_meta.get(agent_id, {})
	var speaker: String = meta.get("name", agent_id)

	if GameManager.conversations[agent_id].is_empty():
		if GameManager.use_http_ai:
			jrpg_box.show_line(agent_id, speaker, "...", "neutral")
			_state = State.AWAITING_CONTINUE
		else:
			var opener := StubDialogue.pick_opener(agent_id)
			var mood: String = StubDialogue.mood_for_opener(agent_id)
			GameManager.append_assistant_message(agent_id, opener, {"mood": mood})
			_show_assistant_line(agent_id, speaker, opener, mood)
	else:
		_show_last_assistant_line(agent_id, speaker)


func _show_last_assistant_line(agent_id: String, speaker: String) -> void:
	var conv: Array = GameManager.conversations[agent_id]
	for i in range(conv.size() - 1, -1, -1):
		if conv[i].get("role") == "assistant":
			var mood: String = str(conv[i].get("meta", {}).get("mood", "neutral"))
			_show_assistant_line(agent_id, speaker, conv[i].get("content", ""), mood)
			return
	jrpg_box.show_line(agent_id, speaker, "...", "neutral")
	_state = State.AWAITING_CONTINUE


func _show_assistant_line(agent_id: String, speaker: String, text: String, mood: String) -> void:
	_state = State.SHOWING_LINE
	jrpg_box.show_line(agent_id, speaker, text, mood, false)


func _on_line_finished() -> void:
	if _state == State.SHOWING_LINE:
		_state = State.AWAITING_CONTINUE


func _on_continue_pressed() -> void:
	if _state != State.AWAITING_CONTINUE:
		return
	if not GameManager.can_send_message():
		_on_close()
		return
	_state = State.AWAITING_INPUT
	input_modal.open_modal()


func _on_input_submitted(text: String) -> void:
	if not GameManager.can_send_message():
		return
	GameManager.append_user_message(text)
	_state = State.WAITING_AI
	jrpg_box.show_thinking()

	if GameManager.use_http_ai:
		var http := get_node_or_null("/root/HttpAgentClient")
		if http and http.has_method("request_agent"):
			GameManager.request_pending = true
			http.request_agent(GameManager.active_agent, text)
			return

	var delta := StubDialogue.generate_delta(GameManager.active_agent, text, GameManager)
	_on_agent_delta_ready(delta)


func _on_input_cancelled() -> void:
	if _state == State.WAITING_AI:
		return
	_state = State.AWAITING_CONTINUE


func on_agent_response(delta: Dictionary) -> void:
	GameManager.request_pending = false
	_on_agent_delta_ready(delta)


func _on_agent_delta_ready(delta: Dictionary) -> void:
	var mood: String = str(delta.get("mood", "neutral"))
	var reply: String = str(delta.get("reply", "..."))
	var agent_id := GameManager.active_agent
	var speaker := GameManager.get_agent_name(agent_id)

	# apply_delta appends assistant message; show line after
	GameManager.apply_delta(agent_id, delta)
	_show_assistant_line(agent_id, speaker, reply, mood)


func on_agent_error(message: String) -> void:
	GameManager.request_pending = false
	var agent_id := GameManager.active_agent
	var speaker := GameManager.get_agent_name(agent_id)
	var err_text := message if not message.is_empty() else "The voices fall silent. Try again."
	GameManager.append_assistant_message(agent_id, err_text, {"mood": "worried"})
	_show_assistant_line(agent_id, speaker, err_text, "worried")


func _on_close() -> void:
	input_modal.close_modal()
	jrpg_box.hide_box()
	_state = State.IDLE
	GameManager.close_dialogue()


func _on_dialogue_closed() -> void:
	input_modal.close_modal()
	jrpg_box.hide_box()
	_state = State.IDLE


func _on_state_changed() -> void:
	if GameManager.status != "playing":
		_on_close()
	elif GameManager.dialogue_open and jrpg_box.visible:
		jrpg_box.status_label.text = "Day %d · %d turns" % [GameManager.day, GameManager.turns_left]
