class_name BattleCardLayout
extends Node

signal layout_changed

@export_group("Hand Cards")
@export var card_size := Vector2(104, 147):
	set(value):
		card_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		layout_changed.emit()
@export_range(1.0, 1.5, 0.01) var hover_scale := 1.2:
	set(value):
		hover_scale = clampf(value, 1.0, 1.5)
		layout_changed.emit()
@export var cell_padding := Vector2(4, 4):
	set(value):
		cell_padding = Vector2(maxf(value.x, 0.0), maxf(value.y, 0.0))
		layout_changed.emit()

@export_group("Hero Slot Cards")
@export var slot_card_size := Vector2(126, 178):
	set(value):
		slot_card_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		layout_changed.emit()
@export var slot_card_offset := Vector2(5, 5):
	set(value):
		slot_card_offset = value
		layout_changed.emit()
