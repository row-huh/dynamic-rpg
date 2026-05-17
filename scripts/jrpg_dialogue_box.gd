class_name JrpgDialogueBox
extends Control

signal line_finished
signal continue_pressed
signal close_pressed

@onready var dim_overlay: ColorRect = %DimOverlay
@onready var portrait: TextureRect = %Portrait
@onready var portrait_back: TextureRect = %PortraitBack
@onready var name_label: Label = %NameLabel
@onready var dialogue_label = %DialogueLabel
@onready var continue_btn: Button = %ContinueButton
@onready var close_btn: Button = %CloseButton
@onready var status_label: Label = %StatusLabel
@onready var blip_player: AudioStreamPlayer = %BlipPlayer

var _current_agent: String = ""
var _current_mood: String = "neutral"
var _portrait_tween: Tween


func _ready() -> void:
	visible = false
	continue_btn.pressed.connect(_on_continue)
	close_btn.pressed.connect(_on_close)
	dialogue_label.reveal_finished.connect(_on_line_finished)
	dialogue_label.set_blip_player(blip_player)
	_apply_mobile_layout()
	_apply_theme()
	hide_box()


func _apply_theme() -> void:
	var nameplate: PanelContainer = get_node_or_null("Root/HBox/TextColumn/Nameplate")
	if nameplate:
		nameplate.add_theme_stylebox_override("panel", JrpgUiTheme.make_nameplate_style())
	continue_btn.add_theme_stylebox_override("normal", JrpgUiTheme.make_button_style())
	close_btn.add_theme_stylebox_override("normal", JrpgUiTheme.make_button_style())


func _apply_mobile_layout() -> void:
	var root: Control = get_node_or_null("Root") as Control
	if root == null:
		return
	var screen := get_viewport_rect().size
	if screen.x < 900 or OS.has_feature("mobile"):
		root.offset_top = -220.0
		root.offset_bottom = -88.0
	else:
		root.offset_top = -200.0
		root.offset_bottom = -72.0


func hide_box() -> void:
	visible = false
	continue_btn.visible = false


func show_box() -> void:
	visible = true


func show_thinking() -> void:
	show_box()
	continue_btn.visible = false
	name_label.text = "..."
	dialogue_label.show_text("...", false)


func show_line(agent_id: String, speaker_name: String, text: String, mood: String = "neutral", instant: bool = false) -> void:
	show_box()
	_current_agent = agent_id
	continue_btn.visible = false
	name_label.text = speaker_name
	status_label.text = "Day %d · %d turns" % [GameManager.day, GameManager.turns_left]
	_set_portrait(agent_id, mood)
	dialogue_label.show_text(text, instant)


func _set_portrait(agent_id: String, mood: String) -> void:
	var tex := PortraitLibrary.get_texture(agent_id, mood)
	if tex == null:
		return
	if mood == _current_mood and portrait.texture == tex:
		return
	_current_mood = mood
	if _portrait_tween and _portrait_tween.is_valid():
		_portrait_tween.kill()
	portrait_back.texture = portrait.texture if portrait.texture else tex
	portrait.texture = tex
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.modulate.a = 0.0
	portrait_back.modulate.a = 1.0
	_portrait_tween = create_tween()
	_portrait_tween.set_parallel(true)
	_portrait_tween.tween_property(portrait, "modulate:a", 1.0, 0.15)
	_portrait_tween.tween_property(portrait_back, "modulate:a", 0.0, 0.15)


func _on_line_finished() -> void:
	continue_btn.visible = true
	line_finished.emit()


func _on_continue() -> void:
	continue_pressed.emit()


func _on_close() -> void:
	close_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		if dialogue_label.is_playing():
			dialogue_label.skip()
		elif continue_btn.visible:
			_on_continue()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
