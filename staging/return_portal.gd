class_name ReturnPortal
extends Area2D

@export_file("*.tscn") var destination_scene := "res://Tscn/Scene/base.tscn"
@export var activation_delay := 0.35
@export var pulse_speed := 2.4

@onready var portal_art: Sprite2D = %PortalArt
@onready var rune_ring: Sprite2D = %RuneRing
@onready var prompt: Label = %Prompt

var _elapsed := 0.0
var _transitioning := false
var _portal_base_scale := Vector2.ONE
var _ring_base_scale := Vector2.ONE


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	prompt.hide()
	_portal_base_scale = portal_art.scale
	_ring_base_scale = rune_ring.scale


func _process(delta: float) -> void:
	_elapsed += delta
	var pulse := 1.0 + sin(_elapsed * pulse_speed) * 0.045
	portal_art.scale = _portal_base_scale * pulse
	rune_ring.scale = _ring_base_scale * (1.0 + sin(_elapsed * (pulse_speed * 0.72)) * 0.025)
	rune_ring.rotation += delta * 0.32


func _on_body_entered(body: Node2D) -> void:
	if _transitioning or not body.is_in_group("player"):
		return
	_transitioning = true
	prompt.show()
	if body.has_method("set_input_locked"):
		body.set_input_locked(true)
	await get_tree().create_timer(activation_delay).timeout
	SaveSystem.save_now()
	get_tree().change_scene_to_file(destination_scene)
