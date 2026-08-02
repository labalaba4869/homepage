class_name MerchantNpc
extends Area2D

signal trade_requested

@onready var sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var prompt: Label = %Prompt

var _player: Node2D
var _player_nearby := false
var _interaction_enabled := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.hide()
	sprite.play(&"front")


func _process(_delta: float) -> void:
	if _player_nearby and is_instance_valid(_player):
		_face_player()


func _unhandled_input(event: InputEvent) -> void:
	if (
		_player_nearby
		and _interaction_enabled
		and event.is_action_pressed("interact")
	):
		trade_requested.emit()
		get_viewport().set_input_as_handled()


func set_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value
	prompt.visible = value and _player_nearby


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player = body
	_player_nearby = true
	prompt.visible = _interaction_enabled
	_face_player()


func _on_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	_player = null
	_player_nearby = false
	prompt.hide()
	sprite.flip_h = false
	sprite.play(&"front")


func _face_player() -> void:
	var delta := _player.global_position - global_position
	if absf(delta.x) > absf(delta.y):
		sprite.flip_h = delta.x < 0.0
		sprite.play(&"side")
	elif delta.y < 0.0:
		sprite.flip_h = false
		sprite.play(&"back")
	else:
		sprite.flip_h = false
		sprite.play(&"front")
