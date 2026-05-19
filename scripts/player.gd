extends CharacterBody2D

signal nearby_interactable_changed(npc: NpcAgent)

@export var speed: float = 200

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: Vector2 = Vector2.DOWN
var nearby_interactable: Interactable = null
var movement_locked: bool = false


func _ready() -> void:
	add_to_group("player")
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.NPC
	GameManager.dialogue_requested.connect(_on_dialogue_lock)
	GameManager.dialogue_closed.connect(_on_dialogue_unlock)
	GameManager.state_changed.connect(_on_state_changed)


func _on_dialogue_lock(_id: String) -> void:
	movement_locked = true
	velocity = Vector2.ZERO


func _on_dialogue_unlock() -> void:
	movement_locked = false


func _on_state_changed() -> void:
	movement_locked = GameManager.dialogue_open or GameManager.status != "playing"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and nearby_interactable and nearby_interactable.can_interact():
		nearby_interactable.interact(self)


func register_interactable(area: Interactable) -> void:
	if nearby_interactable == area:
		return
	nearby_interactable = area
	var npc := area.get_parent() as NpcAgent
	nearby_interactable_changed.emit(npc)


func unregister_interactable(area: Interactable) -> void:
	if nearby_interactable != area:
		return
	nearby_interactable = null
	nearby_interactable_changed.emit(null)


func _update_animation(direction: Vector2) -> void:
	var anim := ""
	var prefix := "idle"
	if direction != Vector2.ZERO:
		prefix = "walking"

	if last_direction.x > 0:
		anim = prefix + "_right"
	elif last_direction.x < 0:
		anim = prefix + "_left"
	elif last_direction.y < 0:
		anim = prefix + "_up"
	else:
		anim = prefix + "_down"

	if sprite.animation != anim:
		sprite.play(anim)


func _physics_process(_delta: float) -> void:
	if movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO)
		return

	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		direction.y = 0
	elif Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down"):
		direction.x = 0
	elif (
		Input.is_action_pressed("ui_right")
		or Input.is_action_pressed("ui_left")
		or Input.is_action_pressed("ui_up")
		or Input.is_action_pressed("ui_down")
	):
		if Input.is_action_pressed("ui_right") or Input.is_action_pressed("ui_left"):
			direction.y = 0
		elif Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down"):
			direction.x = 0
	else:
		direction = Vector2.ZERO

	direction = direction.normalized()
	velocity = direction * speed
	move_and_slide()

	# --- DEBUG: log what the player is colliding with ---
	if direction != Vector2.ZERO and get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var col := get_slide_collision(i)
			var collider := col.get_collider()
			if collider:
				var parent_name := ""
				if collider.get_parent():
					parent_name = str(collider.get_parent().name)
					if collider.get_parent().get_parent():
						parent_name = str(collider.get_parent().get_parent().name) + "/" + parent_name
				print("PLAYER BLOCKED at (%d,%d) by '%s' (parent: %s) at collider_pos=(%d,%d)" % [
					int(global_position.x), int(global_position.y),
					collider.name, parent_name,
					int(collider.global_position.x), int(collider.global_position.y)])
	# --- END DEBUG ---

	if direction != Vector2.ZERO:
		last_direction = direction

	_update_animation(direction)
