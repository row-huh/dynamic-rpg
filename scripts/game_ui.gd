extends CanvasLayer

@onready var interact_prompt: Label = %InteractPrompt
@onready var intro_screen: Control = %IntroScreen
@onready var end_screen: Control = %EndScreen
@onready var hud: Control = %GameHUD
@onready var night_modal: Control = %NightModal
@onready var talk_touch_btn: Button = %TalkTouchButton
@onready var joystick_zone: Control = %JoystickZone
@onready var daily_popup: Control = %DailyPopup
@onready var popup_texture: TextureRect = %PopupTexture
@onready var daily_close_btn: Button = %DailyCloseButton
@onready var prev_btn: Button = %PrevButton
@onready var next_btn: Button = %NextButton
@onready var page_indicator: Label = %PageIndicator

const POPUP1_PATH = "res://assets/splash/popup1.png"
const POPUP2_PATH = "res://assets/splash/popup2.png"

var _nearby_npc: NpcAgent = null
var _player: CharacterBody2D = null
var _last_seen_day: int = 0
var _popup_textures: Array[Texture2D] = []
var _current_popup_idx: int = 0


func _ready() -> void:
	layer = 10
	intro_screen.visible = true
	end_screen.visible = false
	hud.visible = false
	night_modal.visible = false
	interact_prompt.visible = false
	daily_popup.visible = false

	# Load popup textures dynamically
	_popup_textures.append(load(POPUP1_PATH))
	_popup_textures.append(load(POPUP2_PATH))

	# Connect buttons
	daily_close_btn.pressed.connect(_on_daily_close_pressed)
	prev_btn.pressed.connect(_on_prev_pressed)
	next_btn.pressed.connect(_on_next_pressed)

	talk_touch_btn.pressed.connect(_on_touch_talk)
	GameManager.state_changed.connect(_on_state_changed)
	call_deferred("_bind_player")
	call_deferred("_update_api_badge")


func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player:
		_player.nearby_interactable_changed.connect(_on_nearby_changed)


func _process(_delta: float) -> void:
	if _player == null:
		return
	if GameManager.dialogue_open or GameManager.status != "playing":
		interact_prompt.visible = false
		return
	if _nearby_npc and is_instance_valid(_nearby_npc):
		interact_prompt.visible = true
		interact_prompt.text = _nearby_npc.get_prompt()
	else:
		interact_prompt.visible = false


func _on_nearby_changed(npc: NpcAgent) -> void:
	_nearby_npc = npc
	GameManager.active_agent = npc.agent_id if npc else GameManager.active_agent


func _on_touch_talk() -> void:
	if _nearby_npc and is_instance_valid(_nearby_npc):
		_nearby_npc.interactable.interact(_player)


func _on_state_changed() -> void:
	intro_screen.visible = GameManager.status == "intro"
	end_screen.visible = GameManager.status == "won" or GameManager.status == "lost"
	hud.visible = GameManager.status == "playing"
	night_modal.visible = GameManager.pending_night and GameManager.status == "playing"

	if GameManager.status == "intro":
		_last_seen_day = 0

	if GameManager.status == "playing" and not GameManager.pending_night and GameManager.day > _last_seen_day:
		_last_seen_day = GameManager.day
		_current_popup_idx = 0
		if _popup_textures.size() > 0:
			popup_texture.texture = _popup_textures[0]
			popup_texture.modulate.a = 1.0
			page_indicator.text = "Page 1 of %d" % _popup_textures.size()
		daily_popup.visible = true

	if end_screen.visible:
		%EndTitle.text = "Victory" if GameManager.status == "won" else "Defeat"
		%EndMessage.text = GameManager.ending_message

	if night_modal.visible:
		_populate_night_modal()

	_update_api_badge()


func _update_api_badge() -> void:
	var badge: Label = get_node_or_null("%ApiBadge")
	if badge == null:
		return
	if GameManager.use_http_ai:
		var url := HttpAgentClient.base_url if HttpAgentClient else "?"
		badge.text = "AI: %s" % url
	else:
		badge.text = "Offline stub dialogue"


func _populate_night_modal() -> void:
	var list: RichTextLabel = %NightLog
	if GameManager.request_pending:
		list.text = "[center][i]The court whispers...[/i][/center]"
		return
	var bb := "[center][b]Night %d — Whispers in the dark[/b][/center]\n\n" % GameManager.day
	for e in GameManager.get_todays_night():
		bb += "[b]%s → %s[/b]\n" % [
			GameManager.get_agent_name(e.get("from", "")),
			GameManager.get_agent_name(e.get("to", "")),
		]
		bb += "%s\n\"%s\"\n\n" % [e.get("line", ""), e.get("reply", "")]
	if bb.ends_with("\n\n"):
		pass
	elif GameManager.night_log.is_empty():
		bb += "The court sleeps. Nothing stirs."
	list.text = bb


func _on_restart_pressed() -> void:
	GameManager.reset_state()
	GameManager.begin_game()
	get_tree().reload_current_scene()


func _on_night_close_pressed() -> void:
	GameManager.close_night()


func _on_daily_close_pressed() -> void:
	daily_popup.visible = false


func _on_prev_pressed() -> void:
	if _popup_textures.size() < 2:
		return
	var prev_idx = (_current_popup_idx - 1 + _popup_textures.size()) % _popup_textures.size()
	_transition_to_page(prev_idx)


func _on_next_pressed() -> void:
	if _popup_textures.size() < 2:
		return
	var next_idx = (_current_popup_idx + 1) % _popup_textures.size()
	_transition_to_page(next_idx)


func _transition_to_page(idx: int) -> void:
	if idx < 0 or idx >= _popup_textures.size():
		return
	_current_popup_idx = idx

	# Smooth cross-fade transition using a Tween
	var tween = create_tween()
	# Fade out old texture
	tween.tween_property(popup_texture, "modulate:a", 0.0, 0.15)
	# Set new texture and update indicators
	tween.tween_callback(func():
		popup_texture.texture = _popup_textures[idx]
		page_indicator.text = "Page %d of %d" % [idx + 1, _popup_textures.size()]
	)
	# Fade in new texture
	tween.tween_property(popup_texture, "modulate:a", 1.0, 0.15)
