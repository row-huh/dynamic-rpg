extends Camera2D

## Child of the player — follows automatically. Offset centers on the sprite visual.

@export var follow_offset: Vector2 = Vector2(8, -7)
@export var desktop_zoom: Vector2 = Vector2(2, 2)
@export var mobile_zoom: Vector2 = Vector2(2, 2)
@export var smoothing_speed: float = 10.0


func _ready() -> void:
	position = follow_offset
	make_current()
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
	_apply_zoom_for_screen()


func _apply_zoom_for_screen() -> void:
	var screen := DisplayServer.window_get_size()
	if screen.x < 900 or OS.has_feature("mobile"):
		zoom = mobile_zoom
	else:
		zoom = desktop_zoom
