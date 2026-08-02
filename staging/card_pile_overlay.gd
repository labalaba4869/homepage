class_name CardPileOverlay
extends Control

signal card_detail_requested(card_data: Dictionary, runtime_state: Dictionary)

const CARD_VIEW_SCENE := preload("res://scenes/ui/card_view.tscn")
const CARD_SIZE := Vector2(112, 159)
const CARD_HOVER_SCALE := 1.2

@onready var _backdrop: ColorRect = %Backdrop
@onready var _title: Label = %Title
@onready var _grid: GridContainer = %PileGrid
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	_backdrop.gui_input.connect(_on_backdrop_input)
	%CloseButton.pressed.connect(close)
	hide()


func show_pile(
	pile_name: String,
	card_instances: Array[Dictionary],
	cards: Dictionary
) -> void:
	_clear_cards()
	_title.text = "%s  %d 张" % [pile_name, card_instances.size()]
	_empty_label.visible = card_instances.is_empty()
	for card_instance in card_instances:
		var card_id := int(card_instance.get("card_id", -1))
		if not cards.has(card_id):
			continue
		_add_card(cards[card_id], card_instance)
	show()


func close() -> void:
	if not visible:
		return
	hide()
	_clear_cards()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _add_card(card_data: Dictionary, card_instance: Dictionary) -> void:
	var cell := CenterContainer.new()
	cell.custom_minimum_size = CARD_SIZE * CARD_HOVER_SCALE + Vector2(6, 6)
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid.add_child(cell)
	var card := CARD_VIEW_SCENE.instantiate() as BattleCardView
	cell.add_child(card)
	card.configure(card_data, CARD_SIZE, card_instance)
	card.set_as_browse_content()
	card.set_browse_hover_scale(CARD_HOVER_SCALE)
	card.mouse_entered.connect(_on_card_hover.bind(card, true))
	card.mouse_exited.connect(_on_card_hover.bind(card, false))
	card.card_clicked.connect(
		_on_card_clicked.bind(card, card_data, card_instance)
	)


func _on_card_hover(card: BattleCardView, active: bool) -> void:
	if is_instance_valid(card):
		card.set_hover_active(active)


func _on_card_clicked(
	card: BattleCardView,
	card_data: Dictionary,
	card_instance: Dictionary
) -> void:
	card.set_hover_active(false)
	card_detail_requested.emit(card_data, card_instance)


func _on_backdrop_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		close()
		accept_event()


func _clear_cards() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
