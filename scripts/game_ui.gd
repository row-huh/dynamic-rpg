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
@onready var drawer_btn: Button = %DrawerToggleButton

const POPUP1_PATH = "res://assets/splash/popup1.png"
const POPUP2_PATH = "res://assets/splash/popup2.png"

var _nearby_npc: NpcAgent = null
var _player: CharacterBody2D = null
var _last_seen_day: int = 0
var _popup_textures: Array[Texture2D] = []
var _current_popup_idx: int = 0
var _drawer_open: bool = false
var _blur_bg: ColorRect = null
var _night_song_triggered_day: int = -1
var _active_banner: PanelContainer = null
var _fade_tween: Tween = null


func _ready() -> void:
	layer = 10
	intro_screen.visible = true
	end_screen.visible = false
	hud.visible = false
	night_modal.visible = false
	interact_prompt.visible = false
	daily_popup.visible = false

	# Initialize and script dynamic ToastManager
	var toast_script = load("res://scripts/toast_manager.gd")
	if toast_script:
		%ToastManager.set_script(toast_script)
		%ToastManager._ready()

	# Load popup textures dynamically
	_popup_textures.append(load(POPUP1_PATH))
	_popup_textures.append(load(POPUP2_PATH))

	# Connect buttons
	daily_close_btn.pressed.connect(_on_daily_close_pressed)
	prev_btn.pressed.connect(_on_prev_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	drawer_btn.pressed.connect(_on_drawer_toggle)

	talk_touch_btn.pressed.connect(_on_touch_talk)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.music_stop_requested.connect(stop_song)
	call_deferred("_bind_player")
	call_deferred("_update_api_badge")
	
	drawer_btn.visible = false

	# Setup Blur Background
	_blur_bg = ColorRect.new()
	_blur_bg.name = "NightBlurBg"
	_blur_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_blur_bg.visible = false
	
	var shader = Shader.new()
	shader.code = "shader_type canvas_item;\n" + \
		"uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;\n" + \
		"void fragment() {\n" + \
		"    COLOR = textureLod(screen_texture, SCREEN_UV, 2.5);\n" + \
		"    COLOR.rgb *= 0.5;\n" + \
		"}"
	var material = ShaderMaterial.new()
	material.shader = shader
	_blur_bg.material = material
	
	add_child(_blur_bg)
	move_child(_blur_bg, night_modal.get_index())

	# Setup NightModal Stylebox (similar to drawer)
	var night_style := StyleBoxFlat.new()
	night_style.bg_color = Color(0.12, 0.09, 0.08, 0.98)
	night_style.border_width_left = 2
	night_style.border_width_top = 2
	night_style.border_width_right = 2
	night_style.border_width_bottom = 2
	night_style.border_color = Color(0.2, 0.15, 0.12, 1)
	night_style.corner_radius_top_left = 8
	night_style.corner_radius_top_right = 8
	night_style.corner_radius_bottom_right = 8
	night_style.corner_radius_bottom_left = 8
	night_style.shadow_color = Color(0, 0, 0, 0.5)
	night_style.shadow_size = 12
	night_style.content_margin_left = 20
	night_style.content_margin_top = 20
	night_style.content_margin_right = 20
	night_style.content_margin_bottom = 20
	night_modal.add_theme_stylebox_override("panel", night_style)

	# Setup NightCloseButton Style
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.2, 0.15, 0.12, 1)
	btn_normal.border_width_left = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_bottom = 1
	btn_normal.border_color = Color(0.83, 0.65, 0.28, 1)
	btn_normal.corner_radius_top_left = 4
	btn_normal.corner_radius_top_right = 4
	btn_normal.corner_radius_bottom_right = 4
	btn_normal.corner_radius_bottom_left = 4
	btn_normal.content_margin_top = 8
	btn_normal.content_margin_bottom = 8
	
	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.28, 0.21, 0.17, 1)
	btn_hover.shadow_color = Color(0.83, 0.65, 0.28, 0.3)
	btn_hover.shadow_size = 4
	
	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.15, 0.11, 0.09, 1)
	btn_pressed.border_color = Color(0.63, 0.49, 0.21, 1)
	
	var btn_disabled := btn_normal.duplicate()
	btn_disabled.bg_color = Color(0.12, 0.09, 0.08, 1)
	btn_disabled.border_color = Color(0.4, 0.3, 0.15, 1)
	
	var close_btn: Button = %NightCloseButton
	if close_btn:
		close_btn.text = "continue"
		close_btn.add_theme_stylebox_override("normal", btn_normal)
		close_btn.add_theme_stylebox_override("hover", btn_hover)
		close_btn.add_theme_stylebox_override("pressed", btn_pressed)
		close_btn.add_theme_stylebox_override("focus", btn_normal)
		close_btn.add_theme_stylebox_override("disabled", btn_disabled)
		close_btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8, 1))
		close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.9, 1))
		close_btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.65, 0.6, 1))
		close_btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.35, 0.3, 1))

	# Setup TalkTouchButton Style
	var talk_normal := StyleBoxFlat.new()
	talk_normal.bg_color = Color(0.2, 0.15, 0.12, 0.9)
	talk_normal.border_width_left = 2
	talk_normal.border_width_top = 2
	talk_normal.border_width_right = 2
	talk_normal.border_width_bottom = 2
	talk_normal.border_color = Color(0.83, 0.65, 0.28, 1.0)
	talk_normal.corner_radius_top_left = 8
	talk_normal.corner_radius_top_right = 8
	talk_normal.corner_radius_bottom_right = 8
	talk_normal.corner_radius_bottom_left = 8
	talk_normal.content_margin_top = 8
	talk_normal.content_margin_bottom = 8

	var talk_hover := StyleBoxFlat.new()
	talk_hover.bg_color = Color(0.83, 0.65, 0.28, 0.95)
	talk_hover.border_width_left = 2
	talk_hover.border_width_top = 2
	talk_hover.border_width_right = 2
	talk_hover.border_width_bottom = 2
	talk_hover.border_color = Color(0.91, 0.84, 0.72, 1.0)
	talk_hover.corner_radius_top_left = 8
	talk_hover.corner_radius_top_right = 8
	talk_hover.corner_radius_bottom_right = 8
	talk_hover.corner_radius_bottom_left = 8
	talk_hover.content_margin_top = 8
	talk_hover.content_margin_bottom = 8
	talk_hover.shadow_color = Color(0.83, 0.65, 0.28, 0.35)
	talk_hover.shadow_size = 4

	var talk_disabled := StyleBoxFlat.new()
	talk_disabled.bg_color = Color(0.12, 0.09, 0.08, 0.6)
	talk_disabled.border_width_left = 1
	talk_disabled.border_width_top = 1
	talk_disabled.border_width_right = 1
	talk_disabled.border_width_bottom = 1
	talk_disabled.border_color = Color(0.35, 0.30, 0.25, 0.6)
	talk_disabled.corner_radius_top_left = 8
	talk_disabled.corner_radius_top_right = 8
	talk_disabled.corner_radius_bottom_right = 8
	talk_disabled.corner_radius_bottom_left = 8
	talk_disabled.content_margin_top = 8
	talk_disabled.content_margin_bottom = 8

	talk_touch_btn.add_theme_stylebox_override("normal", talk_normal)
	talk_touch_btn.add_theme_stylebox_override("hover", talk_hover)
	talk_touch_btn.add_theme_stylebox_override("pressed", talk_hover)
	talk_touch_btn.add_theme_stylebox_override("focus", talk_normal)
	talk_touch_btn.add_theme_stylebox_override("disabled", talk_disabled)

	talk_touch_btn.add_theme_color_override("font_color", Color(0.91, 0.84, 0.72, 1.0))
	talk_touch_btn.add_theme_color_override("font_hover_color", Color(0.12, 0.09, 0.08, 1.0))
	talk_touch_btn.add_theme_color_override("font_pressed_color", Color(0.12, 0.09, 0.08, 1.0))
	talk_touch_btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.40, 0.35, 0.6))

	_on_state_changed()


func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player:
		_player.nearby_interactable_changed.connect(_on_nearby_changed)


func _process(_delta: float) -> void:
	if _player == null:
		return
	if GameManager.dialogue_open or GameManager.status != "playing":
		interact_prompt.visible = false
		talk_touch_btn.visible = false
		joystick_zone.visible = false
		return

	# Show touch controls when playing
	talk_touch_btn.visible = true
	joystick_zone.visible = true

	if _nearby_npc and is_instance_valid(_nearby_npc):
		interact_prompt.visible = true
		interact_prompt.text = _nearby_npc.get_prompt()
		talk_touch_btn.disabled = false
	else:
		interact_prompt.visible = false
		talk_touch_btn.disabled = true



func _on_nearby_changed(npc: NpcAgent) -> void:
	_nearby_npc = npc
	GameManager.active_agent = npc.agent_id if npc else GameManager.active_agent


func _on_touch_talk() -> void:
	if _nearby_npc and is_instance_valid(_nearby_npc):
		_nearby_npc.interactable.interact(_player)


func _on_state_changed() -> void:
	intro_screen.visible = GameManager.status == "intro"
	end_screen.visible = GameManager.status == "won" or GameManager.status == "lost"
	
	var playing = GameManager.status == "playing"
	hud.visible = playing
	drawer_btn.visible = playing
	if not playing:
		_drawer_open = false
		hud.position.x = -350.0
	elif GameManager.day == 1 and not _drawer_open and hud.position.x < -100:
		_drawer_open = true
		hud.position.x = 16.0
		hud._refresh()
		if hud.has_method("start_polling"):
			hud.start_polling()
		
	night_modal.visible = GameManager.pending_night and playing and not GameManager.dialogue_open
	if _blur_bg:
		_blur_bg.visible = night_modal.visible

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
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if end_screen.visible:
		%EndTitle.text = "Victory" if GameManager.status == "won" else "Defeat"
		%EndMessage.text = GameManager.ending_message
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if night_modal.visible:
		_populate_night_modal()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
	var close_btn: Button = %NightCloseButton
	if GameManager.request_pending:
		list.text = "[center]\n\n[font_size=24]⌛[/font_size]\n\n[i][color=#8a7b6b]The court whispers...[/color][/i][/center]"
		if close_btn:
			close_btn.text = "loading..."
			close_btn.disabled = true
		return
		
	if close_btn:
		close_btn.text = "continue"
		close_btn.disabled = false
	
	if GameManager.day != _night_song_triggered_day:
		_night_song_triggered_day = GameManager.day
		if GameManager.day == 1:
			play_song("never_gonna_give_you_up.mp3")
		elif GameManager.day == 4:
			play_song("reigen.mp3")
	
	var bb := "[center][font_size=20][b][color=#d4a648]✦ NIGHT %d BRIEFING ✦[/color][/b][/font_size][/center]\n" % GameManager.day
	bb += "[center][i][color=#8a7b6b]Whispers in the shadows[/color][/i][/center]\n\n"
	
	# SECTION 1: Whispers
	var todays_night = GameManager.get_todays_night()
	if todays_night.is_empty():
		bb += "[center][color=#6b5f52][i]The court sleeps. Nothing stirs in the shadows.[/i][/color][/center]\n\n"
	else:
		for e in todays_night:
			bb += "[center][color=#d4a648]%s[/color]  [color=#5c4c43]◀   ▶[/color]  [color=#bca89f]%s[/color][/center]\n" % [
				GameManager.get_agent_name(e.get("from", "")).to_upper(),
				GameManager.get_agent_name(e.get("to", "")).to_upper(),
			]
			bb += "[center][color=#e5dcd5][i]\" %s \"[/i][/color][/center]\n\n" % e.get("reply", "")

	bb += "\n[center][font_size=16][b][color=#d4a648]✦ DAILY STATS & INFLUENCE ✦[/color][/b][/font_size][/center]\n\n"

	# SECTION 2: Deltas
	var deltas = GameManager.get_day_deltas()
	if deltas.is_empty():
		bb += "[center][color=#6b5f52][i]The status quo remains. No changes today.[/i][/color][/center]"
	else:
		bb += "[table=3]"
		bb += "[cell][b][color=#8a7b6b]  Metric[/color][/b][/cell][cell][center][b][color=#8a7b6b]Value[/color][/b][/center][/cell][cell][right][b][color=#8a7b6b]Shift  [/color][/b][/right][/cell]"
		bb += _format_delta_cell("Sir Alaric's Trust", GameManager.agents["commander"]["trust"], deltas.get("commander_trust", 0))
		bb += _format_delta_cell("Mira's Trust", GameManager.agents["citizen"]["trust"], deltas.get("citizen_trust", 0))
		bb += _format_delta_cell("Father Edran's Trust", GameManager.agents["priest"]["trust"], deltas.get("priest_trust", 0))
		bb += _format_delta_cell("Father Edran's Fear", GameManager.agents["priest"]["fear"], deltas.get("priest_fear", 0))
		bb += _format_delta_cell("Bishop's Proof", GameManager.proof, deltas.get("proof", 0))
		bb += _format_delta_cell("Suspicion", GameManager.suspicion, deltas.get("suspicion", 0))
		bb += "[/table]"

	list.text = bb


func _format_delta_cell(label: String, current: int, delta: int) -> String:
	var d_str = "  —"
	var d_color = "#6b5f52"
	
	if delta > 0:
		if label in ["Suspicion", "Bishop's Proof"]:
			d_str = "▲ +%d" % delta
			d_color = "#e74c3c"
		elif label == "Father Edran's Fear":
			d_str = "▲ +%d" % delta
			d_color = "#3498db"
		else:
			d_str = "▲ +%d" % delta
			d_color = "#d4a648"
	elif delta < 0:
		var abs_delta = abs(delta)
		if label in ["Suspicion", "Bishop's Proof"]:
			d_str = "▼ -%d" % abs_delta
			d_color = "#2ecc71"
		else:
			d_str = "▼ -%d" % abs_delta
			d_color = "#e74c3c"
			
	return "[cell]  [color=#bca89f]%s[/color][/cell][cell][center][color=#ffffff]%d[/color][/center][/cell][cell][right][color=%s]%s[/color]  [/right][/cell]" % [
		label, current, d_color, d_str
	]


func _on_restart_pressed() -> void:
	_night_song_triggered_day = -1
	if _active_banner:
		_active_banner.queue_free()
		_active_banner = null
	GameManager.reset_state()
	GameManager.begin_game()
	get_tree().reload_current_scene()


func _on_night_close_pressed() -> void:
	if GameManager.day == 4:
		_show_custom_banner(
			"You have only 2 more days!",
			["continue.."],
			func(): GameManager.close_night()
		)
	else:
		GameManager.close_night()


func play_song(song_name: String) -> void:
	var music_player: AudioStreamPlayer = get_node_or_null("%IntroMusic")
	if not music_player:
		return
		
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		
	var search_dirs = ["res://assets/audios/", "res://assets/audio/", "res://assets/music/"]
	var stream: AudioStream = null
	
	# Try the requested song name
	for dir in search_dirs:
		var test_path = dir + song_name
		if ResourceLoader.exists(test_path):
			stream = load(test_path)
			if stream:
				print("[Audio] Successfully loaded stream: ", test_path)
				break
				
	# If that failed, and it's reigen.mp3, try the known fallback gogoreigen.mp3!
	if not stream and song_name == "reigen.mp3":
		var fallbacks = [
			"res://assets/music/gogoreigen.mp3",
			"res://assets/audios/gogoreigen.mp3",
			"res://assets/audio/gogoreigen.mp3"
		]
		for fallback_path in fallbacks:
			if ResourceLoader.exists(fallback_path):
				stream = load(fallback_path)
				if stream:
					print("[Audio] Successfully loaded reigen fallback: ", fallback_path)
					break
					
	# Final fallback to default medieval song if everything else failed
	if not stream:
		var default_path = "res://assets/music/without_me_medieval.mp3"
		if ResourceLoader.exists(default_path):
			stream = load(default_path)
			if stream:
				print("[Audio] Falling back to default: ", default_path)
				
	if stream:
		music_player.stop()
		if "loop" in stream:
			stream.loop = true
		music_player.stream = stream
		music_player.volume_db = -15.0
		music_player.play()
	else:
		print("[Audio] ERROR: Failed to load any audio stream for: ", song_name)



func stop_song() -> void:
	var music_player: AudioStreamPlayer = get_node_or_null("%IntroMusic")
	if music_player and music_player.playing:
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()
		_fade_tween = create_tween()
		_fade_tween.tween_property(music_player, "volume_db", -80.0, 1.5)
		_fade_tween.finished.connect(func():
			music_player.stop()
			music_player.volume_db = -15.0
		)


func _show_custom_banner(text: String, button_options: Array[String], callback: Callable) -> void:
	if _active_banner:
		_active_banner.queue_free()
		_active_banner = null
		
	var banner := PanelContainer.new()
	banner.name = "CustomRpgBanner"
	_active_banner = banner
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.09, 0.08, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.83, 0.65, 0.28, 1)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.content_margin_left = 24
	panel_style.content_margin_top = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_bottom = 24
	banner.add_theme_stylebox_override("panel", panel_style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	banner.add_child(vbox)
	
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.text = "[center][font_size=18][color=#e5dcd5]%s[/color][/font_size][/center]" % text
	vbox.add_child(label)
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox)
	
	for btn_text in button_options:
		var btn := Button.new()
		btn.text = btn_text
		
		var btn_normal := StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.2, 0.15, 0.12, 1)
		btn_normal.border_width_left = 1
		btn_normal.border_width_top = 1
		btn_normal.border_width_right = 1
		btn_normal.border_width_bottom = 1
		btn_normal.border_color = Color(0.83, 0.65, 0.28, 1)
		btn_normal.corner_radius_top_left = 4
		btn_normal.corner_radius_top_right = 4
		btn_normal.corner_radius_bottom_right = 4
		btn_normal.corner_radius_bottom_left = 4
		btn_normal.content_margin_left = 15
		btn_normal.content_margin_right = 15
		btn_normal.content_margin_top = 8
		btn_normal.content_margin_bottom = 8
		
		var btn_hover := btn_normal.duplicate()
		btn_hover.bg_color = Color(0.28, 0.21, 0.17, 1)
		btn_hover.shadow_color = Color(0.83, 0.65, 0.28, 0.3)
		btn_hover.shadow_size = 4
		
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_normal)
		btn.add_theme_stylebox_override("focus", btn_normal)
		btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8, 1))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.9, 1))
		
		btn.pressed.connect(func():
			_active_banner.queue_free()
			_active_banner = null
			callback.call()
		)
		hbox.add_child(btn)
		
	add_child(banner)
	banner.anchors_preset = Control.PRESET_CENTER
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.custom_minimum_size = Vector2(400, 160)


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


func _on_drawer_toggle() -> void:
	_drawer_open = not _drawer_open
	var target_x = 16.0 if _drawer_open else -350.0
	var tween = create_tween()
	tween.tween_property(hud, "position:x", target_x, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _drawer_open:
		if hud.has_method("_refresh"):
			hud._refresh()
		if hud.has_method("start_polling"):
			hud.start_polling()
	else:
		if hud.has_method("stop_polling"):
			hud.stop_polling()
