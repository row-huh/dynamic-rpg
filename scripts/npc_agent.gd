# SpriteFrames on each NPC scene must define: idle_down/left/right/up,
# walking_down/left/right/up (empty animations are allowed).
class_name NpcAgent
extends CharacterBody2D

enum BehaviorState { IDLE, WANDER, RETURN_HOME, TALKING }

@export var agent_id: String = "commander"
@export var wander_radius: float = 160.0
@export var wander_zone: Rect2 = Rect2()
@export var move_speed: float = 90.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interactable: Interactable = $InteractArea
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var home_position: Vector2
var _state: BehaviorState = BehaviorState.IDLE
var _wait_timer: float = 0.0
var _wander_timeout: float = 0.0
var _stuck_timer: float = 0.0
var _path_failures: int = 0
var last_direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	add_to_group("npc_agents")
	home_position = global_position
	collision_layer = PhysicsLayers.NPC
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLAYER | PhysicsLayers.NPC
	_update_name_label()
	interactable.interacted.connect(_on_interacted)
	GameManager.dialogue_requested.connect(_on_dialogue_requested)
	GameManager.dialogue_closed.connect(_on_dialogue_closed)
	_state = BehaviorState.IDLE
	_wait_timer = randf_range(0.5, 2.0) # Rest slightly before starting to wander
	call_deferred("_setup_navigation")


func _setup_navigation() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame # Ensure navigation server map synchronizes
	if nav_agent:
		var map := nav_agent.get_navigation_map()
		var closest := NavigationServer2D.map_get_closest_point(map, global_position)
		if closest != Vector2.ZERO:
			global_position = closest
			home_position = closest
		nav_agent.target_position = global_position


func _update_name_label() -> void:
	var label := get_node_or_null("NameLabel") as Label
	if label:
		label.text = GameManager.get_agent_name(agent_id)


func _physics_process(delta: float) -> void:
	if GameManager.dialogue_open and GameManager.active_agent == agent_id:
		_state = BehaviorState.TALKING
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO)
		return

	if _state == BehaviorState.TALKING:
		_state = BehaviorState.IDLE
		_wait_timer = 1.5
		return

	# State Machine Updates
	if _state == BehaviorState.IDLE:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_state = BehaviorState.WANDER
			_pick_next_target()
	elif _state == BehaviorState.WANDER:
		_wander_timeout -= delta
		if wander_zone == Rect2() and global_position.distance_to(home_position) > wander_radius * 1.5:
			_state = BehaviorState.RETURN_HOME
			if nav_agent:
				nav_agent.target_position = home_position
		elif nav_agent == null or nav_agent.is_navigation_finished() or _wander_timeout <= 0.0:
			_state = BehaviorState.IDLE
			_wait_timer = randf_range(1.0, 3.0)
			if nav_agent:
				nav_agent.target_position = global_position
	elif _state == BehaviorState.RETURN_HOME:
		if nav_agent:
			nav_agent.target_position = home_position
		if global_position.distance_to(home_position) < 12.0 or (nav_agent and nav_agent.is_navigation_finished()):
			_state = BehaviorState.IDLE
			_wait_timer = 2.0
			_path_failures = 0

	if nav_agent and not nav_agent.is_navigation_finished():
		var next_pos := nav_agent.get_next_path_position()
		var dir := global_position.direction_to(next_pos)
		if dir.length_squared() > 0.001:
			velocity = dir * move_speed
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	var pos_before := global_position
	move_and_slide()
	_update_animation(velocity)

	# Displacement-based stuck detection:
	# If we are supposed to be moving but actual distance moved is extremely small,
	# we increment a timer. If stuck for > 0.8 seconds, recover.
	if _state == BehaviorState.WANDER and velocity.length_squared() > 10.0:
		var distance_moved := pos_before.distance_to(global_position)
		var expected_movement := move_speed * delta
		if distance_moved < expected_movement * 0.2:
			_stuck_timer += delta
			if _stuck_timer >= 0.8:
				_state = BehaviorState.IDLE
				_wait_timer = randf_range(0.5, 1.5)
				_stuck_timer = 0.0
				if nav_agent:
					nav_agent.target_position = global_position
		else:
			_stuck_timer = maxf(0.0, _stuck_timer - delta)
	else:
		_stuck_timer = 0.0


func _pick_next_target() -> void:
	if nav_agent == null:
		return
	
	var candidate := Vector2.ZERO
	if wander_zone.has_area():
		candidate = Vector2(
			randf_range(wander_zone.position.x, wander_zone.end.x),
			randf_range(wander_zone.position.y, wander_zone.end.y)
		)
	else:
		var angle := randf() * TAU
		var dist := randf_range(40.0, wander_radius)
		candidate = home_position + Vector2(cos(angle), sin(angle)) * dist
		
	nav_agent.target_position = candidate
	_wander_timeout = randf_range(5.0, 8.0)


func _update_animation(direction: Vector2) -> void:
	if sprite == null:
		return
	var anim := ""
	var prefix := "idle"
	if direction.length_squared() > 4.0:
		prefix = "walking"
		if absf(direction.x) > absf(direction.y):
			last_direction = Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
		else:
			last_direction = Vector2.DOWN if direction.y > 0 else Vector2.UP

	if last_direction.x > 0:
		anim = prefix + "_right"
	elif last_direction.x < 0:
		anim = prefix + "_left"
	elif last_direction.y < 0:
		anim = prefix + "_up"
	else:
		anim = prefix + "_down"

	if sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


func _on_interacted(_player: Node2D) -> void:
	GameManager.open_dialogue(agent_id)


func _on_dialogue_requested(id: String) -> void:
	if id == agent_id:
		_state = BehaviorState.TALKING


func _on_dialogue_closed() -> void:
	if _state == BehaviorState.TALKING:
		_state = BehaviorState.IDLE
		_wait_timer = 1.0


func get_prompt() -> String:
	return "Press E — speak with %s" % GameManager.get_agent_name(agent_id)
