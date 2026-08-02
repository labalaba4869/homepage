class_name InventoryView
extends Control

signal close_requested
signal inventory_slot_pressed(slot_index: int)

const ITEM_SLOT_SCENE := preload(
	"res://scenes/ui/inventory/item_slot.tscn"
)
const CARD_VIEW_SCENE := preload(
	"res://scenes/ui/card_view.tscn"
)

@export var embedded := false

@onready var background_shade: ColorRect = %BackgroundShade
@onready var inventory_panel: PanelContainer = %InventoryPanel
@onready var close_button: Button = %CloseButton
@onready var item_tab: Button = %ItemTab
@onready var card_tab: Button = %CardTab
@onready var deck_tab: Button = %DeckTab
@onready var item_page: VBoxContainer = %ItemPage
@onready var card_page: VBoxContainer = %CardPage
@onready var deck_page: VBoxContainer = %DeckPage
@onready var capacity_label: Label = %CapacityLabel
@onready var weight_bar: ProgressBar = %WeightBar
@onready var weight_label: Label = %WeightLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var card_grid: GridContainer = %CardGrid
@onready var deck_grid: GridContainer = %DeckGrid
@onready var card_empty_label: Label = %CardEmptyLabel
@onready var details_label: Label = %DetailsLabel
@onready var status_label: Label = %StatusLabel
@onready var active_slot_1: ActiveItemSlotView = %ActiveSlot1
@onready var active_slot_2: ActiveItemSlotView = %ActiveSlot2
@onready var active_slot_3: ActiveItemSlotView = %ActiveSlot3

var _slot_views: Array[ItemSlotView] = []
var _active_slot_views: Array[ActiveItemSlotView] = []
var _selected_inventory_index := -1
var _current_tab := 0


func _ready() -> void:
	InventoryState.ensure_initialized()
	_active_slot_views = [active_slot_1, active_slot_2, active_slot_3]
	close_button.pressed.connect(_request_close)
	item_tab.pressed.connect(_show_tab.bind(0))
	card_tab.pressed.connect(_show_tab.bind(1))
	deck_tab.pressed.connect(_show_tab.bind(2))
	for index in _active_slot_views.size():
		_active_slot_views[index].pressed.connect(
			_on_active_slot_pressed.bind(index)
		)
	if not InventoryState.inventory_changed.is_connected(_refresh):
		InventoryState.inventory_changed.connect(_refresh)
	if not InventoryState.active_bindings_changed.is_connected(
		_refresh_active_slots
	):
		InventoryState.active_bindings_changed.connect(_refresh_active_slots)
	_rebuild_slots()
	_rebuild_card_pages()
	configure_embedded(embedded)
	_show_tab(0)
	_refresh()


func configure_embedded(value: bool) -> void:
	embedded = value
	if not is_node_ready():
		return
	background_shade.visible = not embedded
	close_button.visible = not embedded
	inventory_panel.custom_minimum_size = (
		Vector2(420, 500) if embedded else Vector2(460, 520)
	)


func set_status(message: String) -> void:
	status_label.text = message


func _unhandled_input(event: InputEvent) -> void:
	if embedded:
		return
	if (
		event.is_action_pressed("ui_cancel")
		or event.is_action_pressed("inventory")
	):
		_request_close()
		get_viewport().set_input_as_handled()


func _request_close() -> void:
	close_requested.emit()


func _show_tab(tab_index: int) -> void:
	_current_tab = tab_index
	item_page.visible = tab_index == 0
	card_page.visible = tab_index == 1
	deck_page.visible = tab_index == 2
	item_tab.button_pressed = tab_index == 0
	card_tab.button_pressed = tab_index == 1
	deck_tab.button_pressed = tab_index == 2
	status_label.text = ""


func _rebuild_slots() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	_slot_views.clear()
	for index in InventoryState.inventory_capacity:
		var slot := ITEM_SLOT_SCENE.instantiate() as ItemSlotView
		item_grid.add_child(slot)
		slot.pressed.connect(_on_slot_pressed.bind(index))
		_slot_views.append(slot)


func _rebuild_card_pages() -> void:
	_clear_children(card_grid)
	_clear_children(deck_grid)
	for card_instance in InventoryState.owned_cards:
		_add_card_view(card_grid, card_instance)
	for card_instance in InventoryState.deck_cards:
		_add_card_view(deck_grid, card_instance)
	card_empty_label.visible = InventoryState.owned_cards.is_empty()


func _add_card_view(grid: GridContainer, card_instance: Dictionary) -> void:
	var card_id := int(card_instance.get("card_id", 0))
	var data := InventoryState.get_card(card_id)
	if data.is_empty():
		return
	var card := CARD_VIEW_SCENE.instantiate() as BattleCardView
	grid.add_child(card)
	card.configure(data, Vector2(104, 148), card_instance)
	card.set_as_slot_content()


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _refresh() -> void:
	if not is_node_ready():
		return
	if _slot_views.size() != InventoryState.inventory_capacity:
		_rebuild_slots()

	for index in _slot_views.size():
		var stack = InventoryState.inventory_slots[index]
		if stack == null:
			_slot_views[index].configure_empty()
		else:
			_slot_views[index].configure_item(
				InventoryState.get_item(int(stack["item_id"])),
				stack
			)
		_slot_views[index].set_selected(index == _selected_inventory_index)

	var used := InventoryState.get_inventory_used_slots()
	var capacity := InventoryState.inventory_capacity
	var weight := InventoryState.get_inventory_weight()
	var max_weight := InventoryState.max_carry_weight
	capacity_label.text = "背包  %d / %d 格" % [used, capacity]
	weight_bar.max_value = max_weight
	weight_bar.value = weight
	weight_label.text = "%.2f / %.2f kg" % [weight, max_weight]
	_rebuild_card_pages()
	_refresh_active_slots()


func _refresh_active_slots() -> void:
	if not is_node_ready():
		return
	var can_bind := _selected_item_is_active()
	for index in _active_slot_views.size():
		var item_id = InventoryState.active_bindings[index]
		if item_id == null:
			_active_slot_views[index].configure(index)
		else:
			var count := InventoryState.get_inventory_item_count(int(item_id))
			_active_slot_views[index].configure(
				index,
				InventoryState.get_item(int(item_id)),
				count
			)
		_active_slot_views[index].set_target_available(can_bind)


func _on_slot_pressed(index: int) -> void:
	var stack = InventoryState.inventory_slots[index]
	if embedded:
		inventory_slot_pressed.emit(index)
		return

	if stack == null:
		_clear_selection()
		details_label.text = "空物品格"
		return

	var item := InventoryState.get_item(int(stack["item_id"]))
	details_label.text = "%s  ×%d\n%s" % [
		str(item.get("item_name", "未知物品")),
		int(stack["count"]),
		str(item.get("item_description", "")),
	]
	if not bool(item.get("is_active", false)):
		_clear_selection()
		status_label.text = "该物品不是主动道具，不能放入主动栏"
		return

	_selected_inventory_index = index
	status_label.text = "已选择主动道具，请点击上方栏位完成绑定"
	_refresh()


func _on_active_slot_pressed(slot_index: int) -> void:
	if _selected_item_is_active():
		var stack = InventoryState.inventory_slots[_selected_inventory_index]
		var result := InventoryState.bind_active_item(
			slot_index,
			int(stack["item_id"])
		)
		status_label.text = "主动道具栏已更新" if result.is_empty() else result
		_clear_selection(false)
		_refresh()
		return

	if InventoryState.active_bindings[slot_index] != null:
		InventoryState.clear_active_binding(slot_index)
		status_label.text = "已解除主动道具绑定"
	else:
		status_label.text = "请先选择背包中的主动道具"


func _selected_item_is_active() -> bool:
	if (
		_selected_inventory_index < 0
		or _selected_inventory_index >= InventoryState.inventory_slots.size()
	):
		return false
	var stack = InventoryState.inventory_slots[_selected_inventory_index]
	return (
		stack != null
		and InventoryState.is_active_item(int(stack["item_id"]))
	)


func _clear_selection(refresh_view := true) -> void:
	_selected_inventory_index = -1
	if refresh_view:
		_refresh()
