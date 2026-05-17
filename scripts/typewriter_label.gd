class_name TypewriterLabel
extends RichTextLabel

signal reveal_finished

@export var chars_per_second: float = 42.0
@export var blip_every_n_chars: int = 2

var _full_text: String = ""
var _visible_chars: int = 0
var _accum: float = 0.0
var _playing: bool = false
var _skipped: bool = false

var _blip_player: AudioStreamPlayer


func _ready() -> void:
	bbcode_enabled = true
	scroll_active = false
	fit_content = true


func set_blip_player(player: AudioStreamPlayer) -> void:
	_blip_player = player


func show_text(message: String, instant: bool = false) -> void:
	_full_text = message
	_visible_chars = 0
	_accum = 0.0
	_skipped = false
	_playing = not instant
	if instant:
		_finish()
	else:
		_update_visible()
		set_process(true)


func skip() -> void:
	if not _playing:
		return
	_skipped = true
	_finish()


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if not _playing:
		return
	_accum += delta * chars_per_second
	while _accum >= 1.0 and _visible_chars < _full_text.length():
		_accum -= 1.0
		_visible_chars += 1
		if _blip_player and _blip_player.stream and _visible_chars % blip_every_n_chars == 0:
			_blip_player.play()
		_update_visible()
	if _visible_chars >= _full_text.length():
		_finish()


func _update_visible() -> void:
	text = _full_text.substr(0, _visible_chars)


func _finish() -> void:
	_playing = false
	set_process(false)
	_visible_chars = _full_text.length()
	text = _full_text
	reveal_finished.emit()
