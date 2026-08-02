class_name SaveSlotEntry
extends Control

signal slot_pressed(slot_index: int, occupied: bool)
signal delete_pressed(slot_index: int)

@onready var slot_button: Button = %SlotButton
@onready var slot_title: Label = %SlotTitle
@onready var status_label: Label = %StatusLabel
@onready var info_label: Label = %InfoLabel
@onready var delete_button: Button = %DeleteButton

var _slot_index := -1


func _ready() -> void:
	slot_button.pressed.connect(_on_slot_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)


func configure(summary: Dictionary, load_mode: bool) -> void:
	_slot_index = int(summary.get("slot_index", -1))
	var occupied := bool(summary.get("occupied", false))
	slot_title.text = "存档 %d" % (_slot_index + 1)
	if not occupied:
		status_label.text = "空存档"
		info_label.text = ""
		slot_button.disabled = load_mode
		delete_button.visible = false
		return

	status_label.text = str(summary.get("scene_name", "夜幕营地"))
	info_label.text = "%s    金币 %d    %s" % [
		_format_time(int(summary.get("play_time_seconds", 0))),
		int(summary.get("coins", 0)),
		_format_date(int(summary.get("saved_at_unix", 0))),
	]
	slot_button.disabled = false
	delete_button.visible = load_mode


func _on_slot_button_pressed() -> void:
	slot_pressed.emit(_slot_index, status_label.text != "空存档")


func _on_delete_button_pressed() -> void:
	delete_pressed.emit(_slot_index)


func _format_time(total_seconds: int) -> String:
	var hours := total_seconds / 3600
	var minutes := (total_seconds % 3600) / 60
	return "%02d:%02d" % [hours, minutes]


func _format_date(unix_time: int) -> String:
	if unix_time <= 0:
		return ""
	var date := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%02d/%02d %02d:%02d" % [
		int(date.get("month", 0)),
		int(date.get("day", 0)),
		int(date.get("hour", 0)),
		int(date.get("minute", 0)),
	]
