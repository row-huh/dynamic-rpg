class_name PlayerInputModal
extends Control

signal submitted(text: String)
signal cancelled

@onready var panel: PanelContainer = %Panel
@onready var input: LineEdit = %Input
@onready var send_btn: Button = %SendButton
@onready var cancel_btn: Button = %CancelButton


func _ready() -> void:
	visible = false
	send_btn.pressed.connect(_on_send)
	cancel_btn.pressed.connect(_on_cancel)
	input.text_submitted.connect(_on_text_submitted)


func open_modal(placeholder: String = "Whisper your words...") -> void:
	visible = true
	input.placeholder_text = placeholder
	input.text = ""
	await get_tree().process_frame
	input.grab_focus()


func close_modal() -> void:
	visible = false
	input.release_focus()


func _on_send() -> void:
	var text := input.text.strip_edges()
	if text.is_empty():
		return
	close_modal()
	submitted.emit(text)


func _on_cancel() -> void:
	close_modal()
	cancelled.emit()


func _on_text_submitted(_text: String) -> void:
	_on_send()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()
