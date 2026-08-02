extends Node

const INVENTORY_SCENE := preload(
	"res://scenes/ui/inventory/inventory_view.tscn"
)


func _ready() -> void:
	InventoryState.ensure_initialized()
	InventoryState.inventory_slots.fill(null)
	for index in mini(15, InventoryState.inventory_slots.size()):
		InventoryState.inventory_slots[index] = {
			"item_id": 10000 + index,
			"count": 1,
		}
	InventoryState.active_bindings[0] = 10000
	InventoryState.active_bindings[1] = 10005
	InventoryState.active_bindings[2] = 10009

	var inventory := INVENTORY_SCENE.instantiate() as InventoryView
	add_child(inventory)
	InventoryState.inventory_changed.emit()
	InventoryState.active_bindings_changed.emit()
