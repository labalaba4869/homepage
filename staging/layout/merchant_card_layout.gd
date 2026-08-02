class_name MerchantCardLayout
extends Node

signal layout_changed

@export_group("Shop Cards")
@export var card_size := Vector2(88, 125):
	set(value):
		card_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		layout_changed.emit()
@export_range(1.0, 1.5, 0.01) var hover_scale := 1.2:
	set(value):
		hover_scale = clampf(value, 1.0, 1.5)
		layout_changed.emit()

@export_group("Card Cell")
@export var cell_size := Vector2(108, 160):
	set(value):
		cell_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		layout_changed.emit()
@export var preview_area_size := Vector2(108, 132):
	set(value):
		preview_area_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		layout_changed.emit()
@export_range(8, 32, 1) var price_font_size := 13:
	set(value):
		price_font_size = clampi(value, 8, 32)
		layout_changed.emit()
