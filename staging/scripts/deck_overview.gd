class_name DeckOverview
extends Control

signal close_requested

const CARD_VIEW_SCENE := preload("res://scenes/ui/card_view.tscn")

@export_group("卡牌布局")
@export var card_display_size := Vector2(120, 171):
	set(value):
		card_display_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_queue_card_layout_refresh()
@export_range(1.0, 1.5, 0.01) var card_hover_scale := 1.2:
	set(value):
		card_hover_scale = clampf(value, 1.0, 1.5)
		_queue_card_layout_refresh()
@export var card_slot_padding := Vector2(4, 4):
	set(value):
		card_slot_padding = Vector2(maxf(value.x, 0.0), maxf(value.y, 0.0))
		_queue_card_layout_refresh()

@onready var close_button: Button = %CloseButton
@onready var hint: Label = %Hint
@onready var owned_count: Label = %OwnedCount
@onready var deck_count: Label = %DeckCount
@onready var owned_grid: GridContainer = %OwnedGrid
@onready var deck_grid: GridContainer = %DeckGrid
@onready var edit_button: Button = %EditButton
@onready var save_button: Button = %SaveButton
@onready var deck_status: Label = %DeckStatus
@onready var limit_dialog: AcceptDialog = %DeckLimitDialog
@onready var card_detail_overlay: CardDetailOverlay = %CardDetailOverlay

var _editing := false
var _draft_owned_cards: Array[Dictionary] = []
var _draft_deck_cards: Array[Dictionary] = []


func _ready() -> void:
	InventoryState.ensure_initialized()
	close_button.pressed.connect(_request_close)
	edit_button.pressed.connect(_begin_edit)
	save_button.pressed.connect(_save_edit)
	InventoryState.inventory_changed.connect(_on_inventory_changed)
	_refresh_view()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if card_detail_overlay.visible:
		card_detail_overlay.close()
	elif _editing:
		_discard_edit()
	else:
		close_requested.emit()
	get_viewport().set_input_as_handled()


func _request_close() -> void:
	if _editing:
		_discard_edit()
	close_requested.emit()


func _on_inventory_changed() -> void:
	if not _editing:
		_refresh_view()


func _begin_edit() -> void:
	if _editing:
		return
	_editing = true
	_draft_owned_cards = _duplicate_cards(InventoryState.owned_cards)
	_draft_deck_cards = _duplicate_cards(InventoryState.deck_cards)
	deck_status.text = "编辑中：右侧红框卡牌点击后移入左侧卡牌包"
	_refresh_view()


func _discard_edit() -> void:
	_editing = false
	_draft_owned_cards.clear()
	_draft_deck_cards.clear()
	deck_status.text = "未保存的编辑已放弃"
	_refresh_view()


func _save_edit() -> void:
	var result := InventoryState.apply_deck_configuration(
		_draft_owned_cards,
		_draft_deck_cards
	)
	if not bool(result.get("ok", false)):
		_show_limit_notice(str(result.get("message", "卡组无法保存")))
		return
	_editing = false
	_draft_owned_cards.clear()
	_draft_deck_cards.clear()
	deck_status.text = str(result.get("message", "卡组已保存"))
	_refresh_view()


func _refresh_view() -> void:
	if not is_node_ready():
		return
	var left_cards := (
		_draft_owned_cards if _editing else InventoryState.owned_cards
	)
	var right_cards := (
		_draft_deck_cards if _editing else InventoryState.deck_cards
	)
	owned_count.text = "卡牌包 %d 张" % left_cards.size()
	deck_count.text = "当前卡组 %d / %d 张" % [
		right_cards.size(),
		InventoryState.MAX_DECK_CARD_COUNT,
	]
	hint.text = (
		"编辑中：点击卡牌可在两侧移动，卡组需保持 10–20 张"
		if _editing
		else "点击编辑后可调整当前卡组"
	)
	edit_button.disabled = _editing
	save_button.disabled = not _editing
	_clear_children(owned_grid)
	_clear_children(deck_grid)
	for card_instance in left_cards:
		_add_card(owned_grid, card_instance, false)
	for card_instance in right_cards:
		_add_card(deck_grid, card_instance, true)


func _add_card(
	grid: GridContainer,
	card_instance: Dictionary,
	in_deck: bool
) -> void:
	var card_data := InventoryState.get_card(int(card_instance.get("card_id", 0)))
	if card_data.is_empty():
		return
	var cell := CenterContainer.new()
	cell.custom_minimum_size = (
		card_display_size * card_hover_scale + card_slot_padding
	)
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_child(cell)
	var card := CARD_VIEW_SCENE.instantiate() as BattleCardView
	cell.add_child(card)
	card.configure(card_data, card_display_size, card_instance)
	card.set_as_browse_content()
	card.set_browse_hover_scale(card_hover_scale)
	card.set_edit_removal_target(_editing and in_deck)
	card.mouse_entered.connect(_on_card_hover.bind(card, true))
	card.mouse_exited.connect(_on_card_hover.bind(card, false))
	card.card_clicked.connect(
		_on_card_pressed.bind(card, card_data, card_instance, in_deck)
	)


func _on_card_hover(card: BattleCardView, active: bool) -> void:
	if not is_instance_valid(card):
		return
	if active and card_detail_overlay.visible:
		return
	card.set_hover_active(active)


func _on_card_pressed(
	card: BattleCardView,
	card_data: Dictionary,
	card_instance: Dictionary,
	in_deck: bool
) -> void:
	if not _editing:
		card.set_hover_active(false)
		card_detail_overlay.show_card(card_data, card_instance)
		return
	var instance_id := int(card_instance.get("instance_id", -1))
	if in_deck:
		if _draft_deck_cards.size() <= InventoryState.MIN_DECK_CARD_COUNT:
			_show_limit_notice(
				"卡组数量不得小于%d张" % InventoryState.MIN_DECK_CARD_COUNT
			)
			return
		var removed := _remove_card_instance(_draft_deck_cards, instance_id)
		if not removed.is_empty():
			_draft_owned_cards.append(removed)
	else:
		if _draft_deck_cards.size() >= InventoryState.MAX_DECK_CARD_COUNT:
			_show_limit_notice(
				"卡组数量不得大于%d张" % InventoryState.MAX_DECK_CARD_COUNT
			)
			return
		var added := _remove_card_instance(_draft_owned_cards, instance_id)
		if not added.is_empty():
			_draft_deck_cards.append(added)
	_refresh_view()


func _show_limit_notice(message: String) -> void:
	deck_status.text = message
	limit_dialog.dialog_text = message
	limit_dialog.popup_centered(Vector2i(360, 150))


func _remove_card_instance(
	collection: Array[Dictionary],
	instance_id: int
) -> Dictionary:
	for index in collection.size():
		if int(collection[index].get("instance_id", -1)) == instance_id:
			var result := collection[index]
			collection.remove_at(index)
			return result
	return {}


func _duplicate_cards(source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card_instance in source:
		result.append(card_instance.duplicate(true))
	return result


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _queue_card_layout_refresh() -> void:
	if is_node_ready():
		call_deferred("_refresh_view")
