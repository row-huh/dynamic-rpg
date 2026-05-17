extends CanvasLayer

@onready var interact_prompt: Label = %InteractPrompt
@onready var intro_screen: Control = %IntroScreen
@onready var end_screen: Control = %EndScreen
@onready var hud: Control = %GameHUD
@onready var night_modal: Control = %NightModal
@onready var talk_touch_btn: Button = %TalkTouchButton
@onready var joystick_zone: Control = %JoystickZone
@onready var daily_popup: Control = %DailyPopup
@onready var popup_aspect: AspectRatioContainer = %PopupAspect
@onready var popup_texture: TextureRect = %PopupTexture

var _nearby_npc: NpcAgent = null
var _player: CharacterBody2D = null
var _last_seen_day: int = 0


func _ready() -> void:
	layer = 10
	intro_screen.visible = true
	end_screen.visible = false
	hud.visible = false
	night_modal.visible = false
	interact_prompt.visible = false
	daily_popup.visible = false
	if popup_texture.texture:
		popup_aspect.ratio = float(popup_texture.texture.get_width()) / float(popup_texture.texture.get_height())
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
		badge.visible = GameManager.status == "playing" or GameManager.status == "intro"
	else:
		badge.text = "Offline stub dialogue"
		badge.visible = GameManager.status == "intro"


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


func _on_begin_pressed() -> void:
	GameManager.begin_game()


func _on_restart_pressed() -> void:
	GameManager.reset_state()
	GameManager.begin_game()
	get_tree().reload_current_scene()


func _on_night_close_pressed() -> void:
	GameManager.close_night()


func _on_daily_close_pressed() -> void:
	daily_popup.visible = false
