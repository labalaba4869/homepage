class_name ItemSlotView
extends Button

const TOOLTIP_SCENE := preload(
	"res://scenes/ui/inventory/item_tooltip.tscn"
)

@export_group("Search Motion")
@export_range(0.0, 24.0, 0.5) var search_orbit_radius := 8.0
@export_range(0.2, 4.0, 0.05) var search_orbit_duration := 1.1
@export_range(-180.0, 180.0, 1.0) var search_icon_angle := -12.0

@onready var icon_background: ColorRect = %IconBackground
@onready var quality_frame: TextureRect = %QualityFrame
@onready var item_icon: TextureRect = %ItemIcon
@onready var placeholder_label: Label = %PlaceholderLabel
@onready var name_label: Label = %NameLabel
@onready var count_label: Label = %CountLabel
@onready var hidden_overlay: ColorRect = %HiddenOverlay
@onready var hidden_label: Label = %HiddenLabel
@onready var magnifier: TextureRect = %Magnifier
@onready var base_outline: Panel = %BaseOutline
@onready var hover_outline: Panel = %HoverOutline
@onready var selection_outline: Panel = %SelectionOutline

var _item_data: Dictionary = {}
var _stack: Dictionary = {}
var _searching := false
var _selected := false
var _is_card := false
var _search_orbit_angle := 0.0
var _magnifier_origin := Vector2.ZERO


func _ready() -> void:
	_magnifier_origin = magnifier.position
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _process(delta: float) -> void:
	if _searching:
		var duration := maxf(search_orbit_duration, 0.05)
		_search_orbit_angle = fmod(
			_search_orbit_angle + delta * TAU / duration,
			TAU
		)
		magnifier.position = _magnifier_origin + Vector2(
			cos(_search_orbit_angle),
			sin(_search_orbit_angle)
		) * search_orbit_radius
		magnifier.rotation = deg_to_rad(search_icon_angle)


func configure_empty() -> void:
	_reset_content()
	disabled = false
	icon_background.color = Color(0.035, 0.06, 0.05, 0.98)
	base_outline.show()


func configure_hidden() -> void:
	_reset_content()
	disabled = true
	icon_background.color = Color(0.025, 0.045, 0.038, 0.98)
	hidden_label.text = "?"
	hidden_label.show()
	hidden_overlay.show()
	base_outline.show()


func configure_searching() -> void:
	_reset_content()
	disabled = true
	_searching = true
	icon_background.color = Color(0.025, 0.045, 0.038, 0.98)
	hidden_label.hide()
	_search_orbit_angle = 0.0
	magnifier.position = _magnifier_origin + Vector2(
		search_orbit_radius,
		0.0
	)
	magnifier.rotation = deg_to_rad(search_icon_angle)
	magnifier.show()
	hidden_overlay.show()
	base_outline.show()


func configure_item(item_data: Dictionary, stack: Dictionary) -> void:
	_reset_content()
	_item_data = item_data
	_stack = stack
	disabled = false
	var quality := int(item_data.get("item_equality", 0))
	var count := int(stack.get("count", 1))
	var frame_path := InventoryState.get_item_frame_path(quality)
	var item_name := _safe_text(item_data.get("item_name"), "未知物品")

	icon_background.color = Color(0.035, 0.055, 0.05, 1.0)
	quality_frame.texture = (
		load(frame_path) as Texture2D
		if ResourceLoader.exists(frame_path)
		else null
	)
	item_icon.texture = _load_icon(_safe_text(item_data.get("icon_path")))
	placeholder_label.text = "" if item_icon.texture else _item_mark(item_name)
	name_label.text = item_name
	count_label.text = "×%d" % count if count > 1 else ""
	tooltip_text = "item"
	base_outline.hide()


func configure_card(card_data: Dictionary, stack: Dictionary) -> void:
	_reset_content()
	_is_card = true
	_stack = stack
	disabled = false
	var quality := int(card_data.get("card_equality", 0))
	var card_id := int(card_data.get("card_id", 0))
	var card_name := _safe_text(card_data.get("card_name"), "未知卡牌")
	var frame_path := InventoryState.get_item_frame_path(quality)
	var art_path := (
		"res://assets/art/cards/characters/card_art_%d.png" % card_id
	)

	icon_background.color = Color(0.045, 0.055, 0.07, 1.0)
	quality_frame.texture = (
		load(frame_path) as Texture2D
		if ResourceLoader.exists(frame_path)
		else null
	)
	item_icon.texture = (
		load(art_path) as Texture2D
		if ResourceLoader.exists(art_path)
		else null
	)
	placeholder_label.text = "卡" if item_icon.texture == null else ""
	name_label.text = card_name
	count_label.text = ""
	tooltip_text = "%s\n%s" % [
		card_name,
		_safe_text(card_data.get("card_description")),
	]
	base_outline.hide()


func set_selected(selected: bool) -> void:
	_selected = selected
	selection_outline.visible = selected
	if selected:
		hover_outline.hide()


func _make_custom_tooltip(_for_text: String) -> Object:
	if _is_card:
		return null
	if _item_data.is_empty() or _stack.is_empty():
		return null
	var tooltip := TOOLTIP_SCENE.instantiate() as ItemTooltip
	tooltip.configure(_item_data, _stack)
	return tooltip


func _reset_content() -> void:
	_item_data = {}
	_stack = {}
	_searching = false
	_search_orbit_angle = 0.0
	_selected = false
	_is_card = false
	tooltip_text = ""
	quality_frame.texture = null
	item_icon.texture = null
	placeholder_label.text = ""
	name_label.text = ""
	count_label.text = ""
	hidden_label.hide()
	magnifier.position = _magnifier_origin
	magnifier.rotation = deg_to_rad(search_icon_angle)
	magnifier.hide()
	hidden_overlay.hide()
	base_outline.show()
	hover_outline.hide()
	selection_outline.hide()


func _on_mouse_entered() -> void:
	if not disabled and not _selected:
		hover_outline.show()


func _on_mouse_exited() -> void:
	hover_outline.hide()


func _load_icon(icon_path: String) -> Texture2D:
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D


func _safe_text(value: Variant, fallback := "") -> String:
	if value == null:
		return fallback
	return str(value)


func _item_mark(item_name: String) -> String:
	return "物" if item_name.is_empty() else item_name.substr(0, 1)
