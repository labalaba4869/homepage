extends Area2D

signal search_requested(
	container_instance_id: String,
	loot_group_id: int
)

@export var container_instance_id := ""
@export var loot_group_id := 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt: Label = $Prompt

var _player_nearby := false
var _has_animated_open := false
var _base_sprite_scale := Vector2.ONE


func _ready() -> void:
	if container_instance_id.is_empty():
		container_instance_id = str(get_path())
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_base_sprite_scale = animated_sprite.scale
	prompt.hide()

	if not InventoryState.get_container(container_instance_id).is_empty():
		animated_sprite.play(&"open")
		_has_animated_open = true
	refresh_state()


func _unhandled_input(event: InputEvent) -> void:
	if (
		_player_nearby
		and event.is_action_pressed("interact")
		and not InventoryState.is_container_looted(container_instance_id)
	):
		_request_search()
		get_viewport().set_input_as_handled()


func refresh_state() -> void:
	if not is_node_ready() or not _player_nearby:
		return
	if InventoryState.is_container_looted(container_instance_id):
		prompt.text = "已搜空"
	else:
		prompt.text = "E  搜索"
	prompt.show()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		refresh_state()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		prompt.hide()


func _request_search() -> void:
	if InventoryState.is_container_looted(container_instance_id):
		refresh_state()
		return
	if not _has_animated_open:
		_play_open_feedback()
	search_requested.emit(container_instance_id, loot_group_id)


func _play_open_feedback() -> void:
	_has_animated_open = true
	animated_sprite.play(&"open")
	var tween := create_tween()
	tween.tween_property(
		animated_sprite,
		"scale",
		_base_sprite_scale * Vector2(1.125, 0.875),
		0.08
	)
	tween.tween_property(
		animated_sprite,
		"scale",
		_base_sprite_scale,
		0.12
	)
