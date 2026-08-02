class_name MerchantShop
extends Control

signal close_requested

const ITEM_SLOT_SCENE := preload(
	"res://scenes/ui/inventory/item_slot.tscn"
)
const CARD_VIEW_SCENE := preload("res://scenes/ui/card_view.tscn")

@onready var close_button: Button = %CloseButton
@onready var coins_label: Label = %CoinsLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var item_details: Label = %ItemDetails
@onready var sell_one_button: Button = %SellOneButton
@onready var sell_all_button: Button = %SellAllButton
@onready var multi_select_button: Button = %MultiSelectButton
@onready var sell_selected_button: Button = %SellSelectedButton
@onready var shop_grid: GridContainer = %ShopGrid
@onready var card_details: Label = %CardDetails
@onready var buy_button: Button = %BuyButton
@onready var status_label: Label = %StatusLabel
@onready var sell_confirmation: ConfirmationDialog = %SellConfirmation
@onready var _card_layout: MerchantCardLayout = %CardLayout

var _slot_views: Array[ItemSlotView] = []
var _selected_inventory_index := -1
var _multi_selected := {}
var _multi_mode := false
var _selected_card_id := -1
var _pending_sale_indices: Array[int] = []


func _ready() -> void:
	InventoryState.ensure_initialized()
	_card_layout.layout_changed.connect(_refresh_card_layout)
	close_button.pressed.connect(_request_close)
	sell_one_button.pressed.connect(_sell_one)
	sell_all_button.pressed.connect(_sell_all)
	multi_select_button.toggled.connect(_set_multi_mode)
	sell_selected_button.pressed.connect(_request_selected_sale)
	buy_button.pressed.connect(_buy_selected_card)
	sell_confirmation.confirmed.connect(_confirm_selected_sale)
	InventoryState.inventory_changed.connect(_refresh_all)
	_rebuild_item_slots()
	_rebuild_shop_cards()
	_refresh_all()


func _refresh_card_layout() -> void:
	if not is_node_ready():
		return
	_rebuild_shop_cards()
	_refresh_card_details()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not sell_confirmation.visible:
		_request_close()
		get_viewport().set_input_as_handled()


func _request_close() -> void:
	close_requested.emit()


func _rebuild_item_slots() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	_slot_views.clear()
	for index in InventoryState.inventory_capacity:
		var slot := ITEM_SLOT_SCENE.instantiate() as ItemSlotView
		item_grid.add_child(slot)
		slot.pressed.connect(_on_item_slot_pressed.bind(index))
		_slot_views.append(slot)


func _refresh_all() -> void:
	if not is_node_ready():
		return
	if _slot_views.size() != InventoryState.inventory_capacity:
		_rebuild_item_slots()
	coins_label.text = "%d" % InventoryState.player_coins
	for index in _slot_views.size():
		var stack = InventoryState.inventory_slots[index]
		if stack == null:
			_slot_views[index].configure_empty()
		else:
			_slot_views[index].configure_item(
				InventoryState.get_item(int(stack["item_id"])),
				stack
			)
		_slot_views[index].set_selected(
			_multi_selected.has(index)
			if _multi_mode
			else index == _selected_inventory_index
		)
	_refresh_item_details()
	_refresh_card_details()


func _on_item_slot_pressed(index: int) -> void:
	var stack = InventoryState.inventory_slots[index]
	if stack == null:
		return
	if _multi_mode:
		if _multi_selected.has(index):
			_multi_selected.erase(index)
		else:
			_multi_selected[index] = true
	else:
		_selected_inventory_index = index
	status_label.text = ""
	_refresh_all()


func _refresh_item_details() -> void:
	if _multi_mode:
		var totals := _selected_sale_totals()
		item_details.text = "已选择 %d 组 / %d 件\n预计获得 %d 金币" % [
			int(totals["stacks"]),
			int(totals["items"]),
			int(totals["value"]),
		]
		sell_one_button.disabled = true
		sell_all_button.disabled = true
		sell_selected_button.disabled = int(totals["stacks"]) == 0
		return

	var stack = _selected_stack()
	if stack == null:
		item_details.text = "选择背包中的物品查看售价与详情"
		sell_one_button.disabled = true
		sell_all_button.disabled = true
		sell_selected_button.disabled = true
		return
	var item := InventoryState.get_item(int(stack["item_id"]))
	var count := int(stack["count"])
	var unit_price := int(item.get("sell_price", 0))
	item_details.text = "%s ×%d\n单价 %d / 全部 %d\n%.2f kg\n%s" % [
		str(item.get("item_name", "物品")),
		count,
		unit_price,
		unit_price * count,
		InventoryState.get_item_weight(int(stack["item_id"])) * count,
		str(item.get("item_description", "")),
	]
	sell_one_button.disabled = false
	sell_all_button.disabled = false
	sell_selected_button.disabled = true


func _selected_stack() -> Variant:
	if (
		_selected_inventory_index < 0
		or _selected_inventory_index >= InventoryState.inventory_slots.size()
	):
		return null
	return InventoryState.inventory_slots[_selected_inventory_index]


func _sell_one() -> void:
	if _selected_stack() == null:
		return
	var earned := InventoryState.sell_inventory_stack(
		_selected_inventory_index,
		1
	)
	status_label.text = "出售成功，获得 %d 金币" % earned
	if _selected_stack() == null:
		_selected_inventory_index = -1
	_refresh_all()


func _sell_all() -> void:
	if _selected_stack() == null:
		return
	var earned := InventoryState.sell_inventory_stack(
		_selected_inventory_index
	)
	_selected_inventory_index = -1
	status_label.text = "整组出售，获得 %d 金币" % earned
	_refresh_all()


func _set_multi_mode(enabled: bool) -> void:
	_multi_mode = enabled
	_selected_inventory_index = -1
	_multi_selected.clear()
	multi_select_button.text = "退出多选" if enabled else "多选"
	status_label.text = "点击物品格进行多选" if enabled else ""
	_refresh_all()


func _selected_sale_totals() -> Dictionary:
	var stacks := 0
	var items := 0
	var value := 0
	for index_value in _multi_selected.keys():
		var index := int(index_value)
		if index < 0 or index >= InventoryState.inventory_slots.size():
			continue
		var stack = InventoryState.inventory_slots[index]
		if stack == null:
			continue
		stacks += 1
		items += int(stack["count"])
		value += InventoryState.get_stack_sell_value(stack)
	return {"stacks": stacks, "items": items, "value": value}


func _request_selected_sale() -> void:
	var totals := _selected_sale_totals()
	if int(totals["stacks"]) == 0:
		return
	_pending_sale_indices.clear()
	for index_value in _multi_selected.keys():
		_pending_sale_indices.append(int(index_value))
	sell_confirmation.dialog_text = (
		"确认出售 %d 组、%d 件物品？\n将获得 %d 金币。"
		% [totals["stacks"], totals["items"], totals["value"]]
	)
	sell_confirmation.popup_centered(Vector2i(430, 190))


func _confirm_selected_sale() -> void:
	var result := InventoryState.sell_inventory_stacks(_pending_sale_indices)
	_multi_selected.clear()
	_pending_sale_indices.clear()
	status_label.text = "批量出售完成，获得 %d 金币" % int(result["earned"])
	_refresh_all()


func _rebuild_shop_cards() -> void:
	for child in shop_grid.get_children():
		child.queue_free()
	var shop_cards: Array[Dictionary] = []
	for value in InventoryState.cards.values():
		var card: Dictionary = value
		if int(card.get("shop_enabled", 0)) == 1:
			shop_cards.append(card)
	shop_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var quality_a := int(a.get("card_equality", 0))
		var quality_b := int(b.get("card_equality", 0))
		return (
			int(a.get("card_id", 0)) < int(b.get("card_id", 0))
			if quality_a == quality_b
			else quality_a > quality_b
		)
	)
	for card in shop_cards:
		_add_shop_card(card)


func _add_shop_card(card_data: Dictionary) -> void:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = _card_layout.cell_size
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_grid.add_child(cell)
	var center := CenterContainer.new()
	center.custom_minimum_size = _card_layout.preview_area_size
	cell.add_child(center)
	var card := CARD_VIEW_SCENE.instantiate() as BattleCardView
	center.add_child(card)
	card.configure(card_data, _card_layout.card_size)
	card.set_as_browse_content()
	card.set_browse_hover_scale(_card_layout.hover_scale)
	card.mouse_entered.connect(card.set_hover_active.bind(true))
	card.mouse_exited.connect(card.set_hover_active.bind(false))
	card.card_clicked.connect(
		_select_shop_card.bind(int(card_data["card_id"]))
	)
	var price := Label.new()
	price.text = "金币 %d" % int(card_data.get("buy_price", 0))
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_color_override("font_color", Color("f2c85b"))
	price.add_theme_font_size_override("font_size", _card_layout.price_font_size)
	cell.add_child(price)


func _select_shop_card(card_id: int) -> void:
	_selected_card_id = card_id
	status_label.text = ""
	_refresh_card_details()


func _refresh_card_details() -> void:
	var card := InventoryState.get_card(_selected_card_id)
	if card.is_empty():
		card_details.text = "选择右侧卡牌查看详情"
		buy_button.disabled = true
		buy_button.text = "购买"
		return
	var price := int(card.get("buy_price", 0))
	card_details.text = "%s · %s\n费用 %s\n%s\n购买后进入“获得卡牌”" % [
		str(card.get("card_name", "卡牌")),
		_quality_name(int(card.get("card_equality", 0))),
		str(card.get("cost", "-")),
		str(card.get("card_description", "")),
	]
	buy_button.disabled = InventoryState.player_coins < price
	buy_button.text = (
		"金币不足（差 %d）" % (price - InventoryState.player_coins)
		if buy_button.disabled
		else "购买 · %d" % price
	)


func _buy_selected_card() -> void:
	if _selected_card_id < 0:
		return
	var result := InventoryState.purchase_shop_card(_selected_card_id)
	status_label.text = str(result.get("message", "购买失败"))
	_refresh_all()


func _quality_name(quality: int) -> String:
	var names := ["白", "绿", "蓝", "紫", "金"]
	return "%s色品质" % names[clampi(quality, 0, names.size() - 1)]
