class_name SearchView
extends CanvasLayer

signal close_requested(container_instance_id: String)

const ITEM_SLOT_SCENE := preload(
	"res://scenes/ui/inventory/item_slot.tscn"
)

@onready var inventory_view: InventoryView = %InventoryView
@onready var container_title: Label = %ContainerTitle
@onready var search_state_label: Label = %SearchStateLabel
@onready var slot_count_label: Label = %SlotCountLabel
@onready var search_grid: GridContainer = %SearchGrid
@onready var status_label: Label = %StatusLabel
@onready var close_button: Button = %CloseButton

var _container_instance_id := ""
var _loot_group_id := -1
var _slot_views: Array[ItemSlotView] = []
var _closing := false


func _ready() -> void:
	inventory_view.configure_embedded(true)
	inventory_view.inventory_slot_pressed.connect(
		_on_inventory_slot_pressed
	)
	close_button.pressed.connect(_request_close)
	if not InventoryState.container_changed.is_connected(
		_on_container_changed
	):
		InventoryState.container_changed.connect(_on_container_changed)


func open_container(
	container_instance_id: String,
	loot_group_id: int
) -> void:
	_container_instance_id = container_instance_id
	_loot_group_id = loot_group_id
	var state := InventoryState.get_or_create_container(
		container_instance_id,
		loot_group_id
	)
	var group := InventoryState.get_loot_group(loot_group_id)
	container_title.text = str(
		group.get("loot_group_name", "搜索目标")
	)
	_rebuild_search_slots((state.get("slots", []) as Array).size())
	_refresh_all()


func _process(delta: float) -> void:
	if _container_instance_id.is_empty():
		return
	InventoryState.advance_search(_container_instance_id, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_request_close()
		get_viewport().set_input_as_handled()


func _rebuild_search_slots(slot_count: int) -> void:
	for child in search_grid.get_children():
		child.queue_free()
	_slot_views.clear()

	for index in slot_count:
		var slot := ITEM_SLOT_SCENE.instantiate() as ItemSlotView
		search_grid.add_child(slot)
		slot.pressed.connect(_on_search_slot_pressed.bind(index))
		_slot_views.append(slot)


func _refresh_all() -> void:
	_refresh_slots()
	_refresh_state()


func _refresh_slots() -> void:
	if _container_instance_id.is_empty():
		return
	var state := InventoryState.get_container(_container_instance_id)
	if state.is_empty():
		return
	var slots: Array = state.get("slots", [])
	var revealed: Array = state.get("revealed", [])
	var current_index := int(state.get("current_index", 0))
	var completed := bool(state.get("completed", false))
	if _slot_views.size() != slots.size():
		_rebuild_search_slots(slots.size())

	var occupied := 0
	for index in slots.size():
		var is_revealed := (
			index < revealed.size() and bool(revealed[index])
		)
		if is_revealed:
			var stack = slots[index]
			if stack == null:
				_slot_views[index].configure_empty()
			elif str(stack.get("content_type", "item")) == "card":
				occupied += 1
				_slot_views[index].configure_card(
					InventoryState.get_card(int(stack["card_id"])),
					stack
				)
			else:
				occupied += 1
				_slot_views[index].configure_item(
					InventoryState.get_item(int(stack["item_id"])),
					stack
				)
		elif index == current_index and not completed:
			_slot_views[index].configure_searching()
		else:
			_slot_views[index].configure_hidden()

	slot_count_label.text = "已发现 %d 件    容量 %d 格" % [
		occupied,
		slots.size(),
	]


func _refresh_state() -> void:
	if _container_instance_id.is_empty():
		return
	var state := InventoryState.get_container(_container_instance_id)
	if state.is_empty():
		return
	if bool(state.get("completed", false)):
		search_state_label.text = (
			"已搜空"
			if InventoryState.is_container_looted(
				_container_instance_id
			)
			else "搜索完成"
		)
	else:
		search_state_label.text = "正在搜索物资"


func _on_search_slot_pressed(index: int) -> void:
	var state := InventoryState.get_container(_container_instance_id)
	var slots: Array = state.get("slots", [])
	var was_card := (
		index >= 0
		and index < slots.size()
		and slots[index] != null
		and str(slots[index].get("content_type", "item")) == "card"
	)
	var result := InventoryState.transfer_container_to_inventory(
		_container_instance_id,
		index
	)
	status_label.text = (
		("卡牌已收入“获得卡牌”" if was_card else "物品已放入背包")
		if result.is_empty()
		else result
	)
	inventory_view.set_status(status_label.text)
	_refresh_all()


func _on_inventory_slot_pressed(index: int) -> void:
	var result := InventoryState.transfer_inventory_to_container(
		index,
		_container_instance_id
	)
	status_label.text = (
		"物品已放回搜索容器" if result.is_empty() else result
	)
	inventory_view.set_status(status_label.text)
	_refresh_all()


func _on_container_changed(container_instance_id: String) -> void:
	if container_instance_id == _container_instance_id:
		_refresh_all()


func _request_close() -> void:
	if _closing:
		return
	_closing = true
	close_requested.emit(_container_instance_id)
