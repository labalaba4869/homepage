extends Area2D

signal opened(reward_text: String)

@export var reward_text := "Field supplies"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt: Label = $Prompt

var _player_nearby := false
var _is_open := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.hide()


func _process(_delta: float) -> void:
	if (
		_player_nearby
		and not _is_open
		and Input.is_action_just_pressed("interact")
	):
		_open_chest()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	var direct_e_press := (
		key_event != null
		and key_event.pressed
		and not key_event.echo
		and (
			key_event.keycode == KEY_E
			or key_event.physical_keycode == KEY_E
		)
	)
	if (
		_player_nearby
		and not _is_open
		and (event.is_action_pressed("interact") or direct_e_press)
	):
		_open_chest()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		if not _is_open:
			prompt.text = "E  Open"
			prompt.show()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		prompt.hide()


func _open_chest() -> void:
	_is_open = true
	animated_sprite.play(&"open")
	prompt.text = "Opened"
	opened.emit(reward_text)

	var tween := create_tween()
	tween.tween_property(
		animated_sprite, "scale", Vector2(2.25, 1.75), 0.08
	)
	tween.tween_property(
		animated_sprite, "scale", Vector2(2, 2), 0.12
	)
	await get_tree().create_timer(0.65).timeout
	prompt.hide()
