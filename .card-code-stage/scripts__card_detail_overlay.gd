class_name CardDetailOverlay
extends Control

signal closed

const CARD_VIEW_SCENE := preload("res://scenes/ui/card_view.tscn")
const DETAIL_CARD_SIZE := Vector2(384, 544)

@onready var _backdrop: ColorRect = %Backdrop
@onready var _card_holder: Control = %CardHolder


func _ready() -> void:
	_backdrop.gui_input.connect(_on_backdrop_input)
	hide()


func show_card(card_data: Dictionary, runtime_state: Dictionary = {}) -> void:
	_clear_card()
	var card := CARD_VIEW_SCENE.instantiate() as BattleCardView
	_card_holder.add_child(card)
	card.configure(card_data, DETAIL_CARD_SIZE, runtime_state)
	card.set_as_slot_content()
	card.position = Vector2.ZERO
	show()


func close() -> void:
	if not visible:
		return
	hide()
	_clear_card()
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		close()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		close()
		accept_event()


func _clear_card() -> void:
	for child in _card_holder.get_children():
		_card_holder.remove_child(child)
		child.queue_free()
