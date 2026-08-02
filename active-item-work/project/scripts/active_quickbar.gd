class_name ActiveQuickbar
extends Control

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var status_label: Label = %StatusLabel
@onready var status_timer: Timer = %StatusTimer
@onready var slot_1: ActiveItemSlotView = %Slot1
@onready var slot_2: ActiveItemSlotView = %Slot2
@onready var slot_3: ActiveItemSlotView = %Slot3

var _slots: Array[ActiveItemSlotView] = []
var _interaction_enabled := true


func _ready() -> void:
	_slots = [slot_1, slot_2, slot_3]
	for index in _slots.size():
		_slots[index].pressed.connect(_use_slot.bind(index))
		_slots[index].set_target_available(false)
	status_timer.timeout.connect(_clear_status)
	if not InventoryState.inventory_changed.is_connected(_refresh):
		InventoryState.inventory_changed.connect(_refresh)
	if not InventoryState.active_bindings_changed.is_connected(_refresh):
		InventoryState.active_bindings_changed.connect(_refresh)
	if not GameSession.player_health_changed.is_connected(_refresh_health):
		GameSession.player_health_changed.connect(_refresh_health)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if (
		not _interaction_enabled
		or not event is InputEventKey
		or not event.pressed
		or event.echo
	):
		return
	var slot_index := -1
	match event.keycode:
		KEY_1:
			slot_index = 0
		KEY_2:
			slot_index = 1
		KEY_3:
			slot_index = 2
	if slot_index >= 0:
		_use_slot(slot_index)
		get_viewport().set_input_as_handled()


func set_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value
	for slot in _slots:
		slot.disabled = not value


func show_status(message: String) -> void:
	status_label.text = message
	status_timer.start()


func _use_slot(slot_index: int) -> void:
	if not _interaction_enabled:
		return
	var result := InventoryState.use_active_binding(slot_index)
	show_status(str(result.get("message", "")))
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	for index in _slots.size():
		var item_id = InventoryState.active_bindings[index]
		if item_id == null:
			_slots[index].configure(index)
		else:
			_slots[index].configure(
				index,
				InventoryState.get_item(int(item_id)),
				InventoryState.get_inventory_item_count(int(item_id))
			)
		_slots[index].set_target_available(false)
	_refresh_health(GameSession.player_hp, GameSession.player_max_hp)


func _refresh_health(current_hp: int, max_hp: int) -> void:
	if not is_node_ready():
		return
	health_bar.max_value = maxi(max_hp, 1)
	health_bar.value = clampi(current_hp, 0, max_hp)
	health_label.text = "%d / %d" % [current_hp, max_hp]


func _clear_status() -> void:
	status_label.text = ""
