class_name BattleCardView
extends Button

const BASE_SIZE := Vector2(192, 272)

var card_data := {}
var runtime_state := {}

var _art: TextureRect
var _frame: TextureRect
var _name_label: Label
var _description_label: Label
var _cost_label: Label
var _attack_label: Label
var _health_label: Label
var _status_label: Label
var _selection_panel: Panel
var _unavailable_overlay: ColorRect
var _built := false


func _ready() -> void:
	_ensure_ui()
	resized.connect(_layout_children)
	_layout_children()


func configure(
	data: Dictionary,
	display_size: Vector2,
	state: Dictionary = {}
) -> void:
	_ensure_ui()
	card_data = data
	runtime_state = state
	custom_minimum_size = display_size
	size = display_size

	var card_id := int(card_data.get("card_id", 0))
	var quality := int(card_data.get("card_equality", 0))
	var art_path := (
		"res://assets/art/cards/characters/card_art_%d.png" % card_id
	)
	var frame_names := [
		"card_frame_0_white.png",
		"card_frame_1_green.png",
		"card_frame_2_blue.png",
		"card_frame_3_purple.png",
		"card_frame_4_gold.png",
	]
	var frame_index := clampi(quality, 0, frame_names.size() - 1)
	_art.texture = load(art_path) if ResourceLoader.exists(art_path) else null
	_frame.texture = load(
		"res://assets/art/cards/frames/%s" % frame_names[frame_index]
	)

	_name_label.text = str(card_data.get("card_name", "未知卡牌"))
	_description_label.text = _format_description(card_data)
	_cost_label.text = _value_text(card_data.get("cost"))
	_attack_label.text = _value_text(card_data.get("card_attack"))
	tooltip_text = "%s\n%s" % [
		_name_label.text,
		_description_label.text,
	]
	update_runtime_state(state)
	_layout_children()


func update_runtime_state(state: Dictionary) -> void:
	runtime_state = state
	if state.is_empty():
		_health_label.text = _value_text(card_data.get("card_maxhp"))
		_status_label.text = ""
		return

	_health_label.text = str(int(state.get(
		"current_hp",
		card_data.get("card_maxhp", 0)
	)))
	var statuses: Array[String] = []
	var shield := int(state.get("shield", 0))
	var burn := int(state.get("burn", 0))
	var frost := int(state.get("frost", 0))
	if shield > 0:
		statuses.append("盾%d" % shield)
	if burn > 0:
		statuses.append("燃%d" % burn)
	if frost > 0:
		statuses.append("寒%d" % frost)
	if bool(state.get("paralyzed", false)):
		statuses.append("麻")
	if bool(state.get("frozen", false)):
		statuses.append("冻")
	_status_label.text = " ".join(statuses)


func set_selected_state(selected: bool) -> void:
	_ensure_ui()
	_selection_panel.visible = selected


func set_interactable(interactable: bool) -> void:
	_ensure_ui()
	disabled = not interactable
	_unavailable_overlay.visible = not interactable


func set_as_slot_content() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	disabled = true
	_unavailable_overlay.visible = false


func _ensure_ui() -> void:
	if _built:
		return
	_built = true
	focus_mode = Control.FOCUS_NONE
	flat = true
	clip_contents = false

	_art = TextureRect.new()
	_art.name = "CharacterArt"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	_frame = TextureRect.new()
	_frame.name = "QualityFrame"
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_name_label = _make_label(13, Color("20252b"))
	_name_label.name = "CardName"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_name_label)

	_description_label = _make_label(9, Color("31363d"))
	_description_label.name = "Description"
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_description_label)

	_cost_label = _make_stat_label(Color("f3f7ff"))
	_attack_label = _make_stat_label(Color("f8f4dc"))
	_health_label = _make_stat_label(Color("fff3ed"))
	add_child(_cost_label)
	add_child(_attack_label)
	add_child(_health_label)

	_status_label = _make_label(9, Color("ffffff"))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_color_override("font_outline_color", Color("14202b"))
	_status_label.add_theme_constant_override("outline_size", 3)
	add_child(_status_label)

	_unavailable_overlay = ColorRect.new()
	_unavailable_overlay.color = Color(0.04, 0.06, 0.08, 0.54)
	_unavailable_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_unavailable_overlay)

	_selection_panel = Panel.new()
	_selection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var selection_style := StyleBoxFlat.new()
	selection_style.bg_color = Color(1, 0.82, 0.25, 0.08)
	selection_style.border_width_left = 4
	selection_style.border_width_top = 4
	selection_style.border_width_right = 4
	selection_style.border_width_bottom = 4
	selection_style.border_color = Color("ffd45d")
	selection_style.corner_radius_top_left = 4
	selection_style.corner_radius_top_right = 4
	selection_style.corner_radius_bottom_left = 4
	selection_style.corner_radius_bottom_right = 4
	selection_style.shadow_color = Color(1, 0.72, 0.15, 0.55)
	selection_style.shadow_size = 7
	_selection_panel.add_theme_stylebox_override("panel", selection_style)
	_selection_panel.visible = false
	add_child(_selection_panel)


func _layout_children() -> void:
	if not _built or size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_x := size.x / BASE_SIZE.x
	var scale_y := size.y / BASE_SIZE.y

	_art.position = Vector2(16.0 * scale_x, 14.0 * scale_y)
	_art.size = Vector2(160.0 * scale_x, 150.0 * scale_y)
	_frame.position = Vector2.ZERO
	_frame.size = size

	_name_label.position = Vector2(31.0 * scale_x, 164.0 * scale_y)
	_name_label.size = Vector2(130.0 * scale_x, 25.0 * scale_y)
	_description_label.position = Vector2(25.0 * scale_x, 192.0 * scale_y)
	_description_label.size = Vector2(142.0 * scale_x, 54.0 * scale_y)

	_cost_label.position = Vector2(3.0 * scale_x, 12.0 * scale_y)
	_cost_label.size = Vector2(42.0 * scale_x, 42.0 * scale_y)
	_attack_label.position = Vector2(3.0 * scale_x, 225.0 * scale_y)
	_attack_label.size = Vector2(43.0 * scale_x, 43.0 * scale_y)
	_health_label.position = Vector2(146.0 * scale_x, 225.0 * scale_y)
	_health_label.size = Vector2(43.0 * scale_x, 43.0 * scale_y)
	_status_label.position = Vector2(62.0 * scale_x, 18.0 * scale_y)
	_status_label.size = Vector2(112.0 * scale_x, 24.0 * scale_y)

	_unavailable_overlay.position = Vector2.ZERO
	_unavailable_overlay.size = size
	_selection_panel.position = Vector2(-2, -2)
	_selection_panel.size = size + Vector2(4, 4)

	var base_font := maxi(8, int(round(13.0 * minf(scale_x, scale_y))))
	_name_label.add_theme_font_size_override("font_size", base_font)
	_description_label.add_theme_font_size_override(
		"font_size",
		maxi(7, base_font - 4)
	)
	_status_label.add_theme_font_size_override(
		"font_size",
		maxi(7, base_font - 4)
	)
	for label in [_cost_label, _attack_label, _health_label]:
		label.add_theme_font_size_override(
			"font_size",
			maxi(13, base_font + 5)
		)


func _make_label(font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label


func _make_stat_label(font_color: Color) -> Label:
	var label := _make_label(18, font_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color("15202a"))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _value_text(value: Variant) -> String:
	return "" if value == null else str(int(value))


func _format_description(data: Dictionary) -> String:
	var raw_description: Variant = data.get("card_description", "")
	if raw_description == null:
		return "基础英雄"
	var description := str(raw_description)
	if description.is_empty():
		return "基础英雄"
	var raw_params: Variant = data.get("description_params", [])
	var params: Array = raw_params if raw_params is Array else []
	for index in 8:
		var token := "{%d}" % index
		if not description.contains(token):
			continue
		if index < params.size():
			description = description.replace(token, str(params[index]))
		elif params.size() == 1:
			description = description.replace(token, str(params[0]))
	return description
