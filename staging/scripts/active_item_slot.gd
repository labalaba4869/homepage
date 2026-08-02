class_name ActiveItemSlotView
extends Button

@onready var slot_number: Label = %SlotNumber
@onready var item_slot: ItemSlotView = %ItemSlot
@onready var target_outline: Panel = %TargetOutline
@onready var target_hover_outline: Panel = %TargetHoverOutline

var _target_available := false
var _hovered := false
var _pulse_time := 0.0


func _ready() -> void:
	item_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_process(_target_available)
	_refresh_highlight()


func _process(delta: float) -> void:
	if not is_instance_valid(target_outline):
		set_process(false)
		return
	_pulse_time += delta
	target_outline.modulate.a = 0.65 + sin(_pulse_time * 4.0) * 0.25


func configure(
	slot_index: int,
	item_data: Dictionary = {},
	count := 0
) -> void:
	slot_number.text = str(slot_index + 1)
	if item_data.is_empty() or count <= 0:
		item_slot.configure_empty()
	else:
		item_slot.configure_item(
			item_data,
			{"item_id": int(item_data["item_id"]), "count": count}
		)
	item_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_target_available(value: bool) -> void:
	_target_available = value
	_pulse_time = 0.0
	set_process(value)
	_refresh_highlight()


func _on_mouse_entered() -> void:
	_hovered = true
	_refresh_highlight()


func _on_mouse_exited() -> void:
	_hovered = false
	_refresh_highlight()


func _refresh_highlight() -> void:
	target_outline.visible = _target_available and not _hovered
	target_hover_outline.visible = _target_available and _hovered
	if not _target_available:
		target_outline.modulate.a = 1.0
