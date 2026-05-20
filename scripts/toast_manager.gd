extends Control

var vbox: VBoxContainer

func _ready() -> void:
	vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)


func show_toasts(delta: Dictionary, agent_id: String) -> void:
	# Parse Trust Delta
	if delta.has("trust_delta") and delta["trust_delta"] != null:
		var trust_delta = int(delta["trust_delta"])
		if trust_delta > 0:
			var agent_name := GameManager.get_agent_name(agent_id)
			create_toast("📈 %s Trust +%d" % [agent_name, trust_delta], Color(0.91, 0.84, 0.72, 1.0), Color(0.83, 0.65, 0.28, 1.0))
		elif trust_delta < 0:
			var agent_name := GameManager.get_agent_name(agent_id)
			create_toast("📉 %s Trust %d" % [agent_name, trust_delta], Color(0.95, 0.45, 0.45, 1.0), Color(0.83, 0.15, 0.15, 1.0))

	# Parse Fear Delta (for Father Edran / Priest)
	if delta.has("fear_delta") and delta["fear_delta"] != null:
		var fear_delta = int(delta["fear_delta"])
		if fear_delta > 0:
			create_toast("😨 Father Edran Fear +%d" % fear_delta, Color(0.55, 0.75, 0.95, 1.0), Color(0.2, 0.55, 0.85, 1.0))
		elif fear_delta < 0:
			create_toast("😌 Father Edran Fear %d" % fear_delta, Color(0.75, 0.95, 0.75, 1.0), Color(0.25, 0.75, 0.25, 1.0))

	# Parse Suspicion Delta
	var suspicion_delta = int(delta.get("suspicionDelta", delta.get("suspicion_delta", 0)))
	if suspicion_delta > 0:
		create_toast("👁️ Bishop Suspicion +%d" % suspicion_delta, Color(0.95, 0.55, 0.35, 1.0), Color(0.85, 0.45, 0.15, 1.0))
	elif suspicion_delta < 0:
		create_toast("🕊️ Bishop Suspicion %d" % suspicion_delta, Color(0.75, 0.95, 0.75, 1.0), Color(0.25, 0.75, 0.25, 1.0))

	# Parse Gossip Score
	var gossip_score = int(delta.get("gossip_score", 0))
	if gossip_score > 0:
		create_toast("🗣️ Whispers Spread +%d" % gossip_score, Color(0.91, 0.84, 0.72, 1.0), Color(0.83, 0.65, 0.28, 1.0))

	# Parse Proof Delta (Evidence)
	var proof_delta = int(delta.get("proof_delta", 0))
	if proof_delta > 0:
		create_toast("📜 Evidence Gathered +%d" % proof_delta, Color(0.95, 0.35, 0.35, 1.0), Color(0.85, 0.15, 0.15, 1.0))


func create_toast(text: String, theme_color: Color, border_color: Color) -> void:
	var panel := PanelContainer.new()
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.08, 0.96) # Rich dark medieval parchment theme
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	
	panel.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", theme_color)
	label.add_theme_font_size_override("font_size", 14)
	
	# Apply standard beautiful medieval fonts if exists, otherwise fallback
	var main_font = load("res://assets/fonts/Inter-Bold.ttf")
	if main_font:
		label.add_theme_font_override("font", main_font)
		
	panel.add_child(label)
	
	# Add to our vertical stack
	vbox.add_child(panel)
	
	# Animate float-in
	panel.modulate.a = 0.0
	panel.position.x = 80.0
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_property(panel, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Keep toast on screen for 3.5 seconds
	await get_tree().create_timer(3.5).timeout
	
	if not is_instance_valid(panel):
		return
		
	# Animate slide-out and fade-out
	var fade_out := create_tween().set_parallel(true)
	fade_out.tween_property(panel, "modulate:a", 0.0, 0.25)
	fade_out.tween_property(panel, "position:x", 120.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await fade_out.finished
	if is_instance_valid(panel):
		panel.queue_free()
