class_name SaveSlotPicker
extends Control

signal slot_selected(slot_index: int, occupied: bool, load_mode: bool)
signal delete_requested(slot_index: int)

@onready var title_label: Label = %TitleLabel
@onready var slots_container: VBoxContainer = %SlotsContainer
@onready var close_button: Button = %CloseButton

var _load_mode := false


func _ready() -> void:
	close_button.pressed.connect(hide)
	for entry in slots_container.get_children():
		if entry is SaveSlotEntry:
			entry.slot_pressed.connect(_on_slot_pressed)
			entry.delete_pressed.connect(_on_delete_pressed)
	hide()


func open_picker(load_mode: bool) -> void:
	_load_mode = load_mode
	title_label.text = "读取存档" if load_mode else "新游戏"
	_refresh_slots()
	show()


func refresh_picker() -> void:
	if visible:
		_refresh_slots()


func _refresh_slots() -> void:
	var summaries := SaveSystem.get_slot_summaries()
	for index in mini(slots_container.get_child_count(), summaries.size()):
		var entry := slots_container.get_child(index) as SaveSlotEntry
		if entry != null:
			entry.configure(summaries[index], _load_mode)


func _on_slot_pressed(slot_index: int, occupied: bool) -> void:
	slot_selected.emit(slot_index, occupied, _load_mode)


func _on_delete_pressed(slot_index: int) -> void:
	delete_requested.emit(slot_index)
