extends CharacterBody2D

const WORLD_MAP_SIZE := Vector2(1536, 1024)

@export var speed: float = 220.0
@export var visual_scale: float = 2.0
@export var fallback_attack_duration: float = 0.35
@export var lock_movement_during_attack := true

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var whitebox_visual: Control = get_node_or_null("Visual") as Control
@onready var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D

var _facing := "front"
var _is_attacking := false
var _attack_timer := 0.0
var _using_fallback_attack := false
var _base_visual_scale := Vector2.ONE
var _input_locked := false

func _ready() -> void:
	add_to_group("player")
	get_viewport().size_changed.connect(_update_camera_for_viewport)
	_update_camera_for_viewport()

	if animated_sprite:
		animated_sprite.scale = Vector2.ONE * visual_scale
		_base_visual_scale = animated_sprite.scale
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
	elif whitebox_visual:
		whitebox_visual.scale = Vector2.ONE * visual_scale
		_base_visual_scale = whitebox_visual.scale

	_play_idle()


func _update_camera_for_viewport() -> void:
	if not camera:
		return
	var viewport_size := get_viewport_rect().size
	var map_fit_zoom := maxf(
		viewport_size.x / WORLD_MAP_SIZE.x,
		viewport_size.y / WORLD_MAP_SIZE.y
	)
	var target_zoom := maxf(1.0, map_fit_zoom)
	camera.zoom = Vector2.ONE * target_zoom

func _physics_process(delta: float) -> void:
	if _input_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		if not _is_attacking:
			_play_idle()
		return

	var direction := _get_move_direction()
	var current_speed := speed * GameSession.get_move_speed_multiplier()

	if direction != Vector2.ZERO and not _is_attacking:
		_update_facing(direction)

	if Input.is_action_just_pressed("attack") and not _is_attacking:
		if direction != Vector2.ZERO:
			_update_facing(direction)
		_start_attack()

	if _is_attacking:
		velocity = (
			Vector2.ZERO
			if lock_movement_during_attack
			else direction * current_speed
		)
		if _using_fallback_attack:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_finish_attack()
	else:
		velocity = direction * current_speed

	move_and_slide()

	if not _is_attacking:
		if direction == Vector2.ZERO:
			_play_idle()
		else:
			_play_walk()

func _get_move_direction() -> Vector2:
	var direction := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if direction.length() > 1.0:
		return direction.normalized()
	return direction

func _update_facing(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		_facing = "left" if direction.x < 0.0 else "right"
	elif direction.y < 0.0:
		_facing = "back"
	else:
		_facing = "front"

func _play_idle() -> void:
	_play_directional_animation("idle")

func _play_walk() -> void:
	_play_directional_animation("walk")

func _start_attack() -> void:
	_is_attacking = true
	_using_fallback_attack = false

	if _play_directional_animation("attack", true):
		return

	_using_fallback_attack = true
	_attack_timer = fallback_attack_duration
	_play_idle()
	_apply_placeholder_attack_feedback(true)

func _finish_attack() -> void:
	_is_attacking = false
	_using_fallback_attack = false
	_apply_placeholder_attack_feedback(false)
	_play_idle()

func _on_animation_finished() -> void:
	if not _is_attacking or not animated_sprite:
		return

	var current_animation := String(animated_sprite.animation)
	if current_animation.begins_with("attack"):
		_finish_attack()

func _play_directional_animation(prefix: String, restart := false) -> bool:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return false

	var animation_name := _find_directional_animation(prefix)
	if animation_name == "":
		return false

	_apply_flip_for_animation(animation_name)
	if restart or animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)
		if restart:
			animated_sprite.set_frame_and_progress(0, 0.0)

	return true

func _find_directional_animation(prefix: String) -> String:
	var exact_name := "%s_%s" % [prefix, _facing]
	if animated_sprite.sprite_frames.has_animation(exact_name):
		return exact_name

	if _facing == "left":
		var mirrored_name := "%s_right" % prefix
		if animated_sprite.sprite_frames.has_animation(mirrored_name):
			return mirrored_name

	return ""

func _apply_flip_for_animation(animation_name: String) -> void:
	if animated_sprite:
		animated_sprite.flip_h = _facing == "left" and animation_name.ends_with("_right")

func _apply_placeholder_attack_feedback(enabled: bool) -> void:
	var scale_value := _base_visual_scale * (Vector2(1.18, 0.88) if enabled else Vector2.ONE)
	if animated_sprite:
		animated_sprite.scale = scale_value
	elif whitebox_visual:
		whitebox_visual.scale = scale_value


func set_input_locked(value: bool) -> void:
	_input_locked = value
	if _input_locked:
		velocity = Vector2.ZERO
		if _is_attacking:
			_finish_attack()
		else:
			_play_idle()
