extends Control

const VIDEO_PATH := "res://assets/videos/obra_letra.ogv"

@onready var video_player: VideoStreamPlayer = %VideoPlayer
@onready var music_player: AudioStreamPlayer = %IntroMusic
@onready var skip_button: Button = %SkipIntroButton

var _active: bool = false
var _seq_id: int = 0


func _ready() -> void:
	if video_player.stream == null:
		video_player.stream = load(VIDEO_PATH) as VideoStream

	video_player.volume_db = -80.0
	video_player.finished.connect(_on_video_finished)
	skip_button.pressed.connect(_on_skip_pressed)

	music_player.stream = load("res://assets/music/without_me_medieval.mp3")

	GameManager.state_changed.connect(_on_state_changed)

	if GameManager.status == "intro" and visible:
		_start_playback()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_stop_playback(GameManager.status == "playing")


func _on_state_changed() -> void:
	if GameManager.status == "intro" and visible:
		_start_playback()


func stop_music() -> void:
	if music_player.playing:
		music_player.stop()


func _stop_playback(keep_music_for_game: bool = false) -> void:
	_seq_id += 1
	_active = false
	video_player.stop()
	skip_button.visible = false

	if not keep_music_for_game:
		stop_music()


func _start_playback() -> void:
	if _active:
		return

	if video_player.stream == null:
		push_error("Intro video missing: %s" % VIDEO_PATH)
		music_player.play()
		GameManager.begin_game()
		return

	_seq_id += 1
	var my_id := _seq_id
	_active = true
	skip_button.visible = true

	video_player.stop()
	music_player.stop()
	music_player.volume_db = 0.0
	video_player.play()

	await get_tree().create_timer(1.0).timeout
	if my_id != _seq_id or not _active:
		return
	music_player.play()


func _on_skip_pressed() -> void:
	_finish_intro()


func _on_video_finished() -> void:
	if not _active:
		return
	_finish_intro()


func _finish_intro() -> void:
	if GameManager.status != "intro":
		return
	_seq_id += 1
	_active = false
	video_player.stop()
	skip_button.visible = false
	music_player.volume_db = -15.0
	GameManager.begin_game()
