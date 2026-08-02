class_name BattleCardView
extends Button

signal card_clicked
signal card_drag_started(screen_position: Vector2)
signal card_drag_moved(screen_position: Vector2)
signal card_drag_ended(screen_position: Vector2)

const BASE_SIZE := Vector2(192, 272)
const DRAG_THRESHOLD := 8.0
const STATUS_ICON_DIR := "res://assets/art/cards/status"

const STATUS_DEFINITIONS := {
	"shield": {
		"icon": "status_shield.png",
		"name": "护盾",
		"fallback": "盾",
	},
	"attack": {
		"icon": "status_attack_up.png",
		"name": "攻击提升",
		"fallback": "攻",
	},
	"pierce": {
		"icon": "status_pierce.png",
		"name": "穿刺",
		"fallback": "穿",
	},
	"combo": {
		"icon": "status_combo.png",
		"name": "连击",
		"fallback": "连",
	},
	"sealed": {
		"icon": "status_sealed.png",
		"name": "封禁",
		"fallback": "禁",
	},
	"burn": {
		"icon": "status_burn.png",
		"name": "燃烧",
		"fallback": "燃",
	},
	"frost": {
		"icon": "status_frost.png",
		"name": "冰寒",
		"fallback": "寒",
	},
	"frozen": {
		"icon": "status_frozen.png",
		"name": "冻结",
		"fallback": "冻",
	},
	"paralyzed": {
		"icon": "status_paralyzed.png",
		"name": "麻痹",
		"fallback": "麻",
	},
}

var card_data := {}
var runtime_state := {}

var _card_canvas: Control
var _art: TextureRect
var _frame: TextureRect
var _name_label: Label
var _description_label: Label
var _cost_label: Label
var _attack_label: Label
var _health_label: Label
var _use_count_badge: TextureRect
var _use_count_label: Label
var _status_bar: HBoxContainer
var _selection_outline: Panel
var _unavailable_overlay: ColorRect
var _nodes_bound := false
var _pointer_down := false
var _dragging := false
var _pointer_origin := Vector2.ZERO
var _drag_tween: Tween
var _feedback_tween: Tween
var _resting_z_index := 0
var _interactable := true
var _selected_state := false
var _focus_visual_active := false


func _ready() -> void:
	_bind_scene_nodes()
	resized.connect(_layout_canvas)
	_layout_canvas()


func configure(
	data: Dictionary,
	display_size: Vector2,
	state: Dictionary = {}
) -> void:
	_bind_scene_nodes()
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
	var is_function := str(card_data.get("card_type", "")) == "function"
	_art.texture = load(art_path) if ResourceLoader.exists(art_path) else null
	var frame_path := (
		"res://assets/art/cards/frames/function/card_frame_function_%d.png"
		% frame_index
		if is_function
		else "res://assets/art/cards/frames/%s" % frame_names[frame_index]
	)
	_frame.texture = load(frame_path)

	_name_label.text = str(card_data.get("card_name", "未知卡牌"))
	_description_label.text = _format_description(card_data)
	_cost_label.text = _value_text(card_data.get("cost"))
	_attack_label.text = _value_text(card_data.get("card_attack"))
	_attack_label.visible = not is_function
	_health_label.visible = not is_function
	tooltip_text = "%s\n%s" % [
		_name_label.text,
		_description_label.text,
	]
	update_runtime_state(state)
	_fit_name_font()
	_layout_canvas()


func update_runtime_state(state: Dictionary) -> void:
	_bind_scene_nodes()
	runtime_state = state
	_clear_status_bar()
	_update_use_count(state)
	if state.is_empty():
		if _health_label.visible:
			_health_label.text = _value_text(card_data.get("card_maxhp"))
		return

	if _health_label.visible:
		_health_label.text = str(int(state.get(
			"current_hp",
			card_data.get("card_maxhp", 0)
		)))
	var statuses: Array[Dictionary] = []
	var shield := int(state.get("shield", 0))
	var attack_bonus := (
		int(state.get("attack_bonus", 0))
		+ int(state.get("turn_attack_bonus", 0))
	)
	var burn := int(state.get("burn", 0))
	var frost := int(state.get("frost", 0))
	if shield > 0:
		statuses.append(_status_entry("shield", shield, "持续到被伤害消耗"))
	if attack_bonus > 0:
		statuses.append(_status_entry("attack", attack_bonus, "提高当前攻击力"))
	if bool(state.get("pierce", false)):
		statuses.append(_status_entry("pierce", 0, "本回合只攻击敌方本体"))
	var attack_count := 1 + int(state.get("extra_attacks", 0))
	if attack_count > 1:
		statuses.append(_status_entry(
			"combo",
			attack_count,
			"本回合连续攻击 %d 次" % attack_count
		))
	if bool(state.get("sealed", false)):
		statuses.append(_status_entry("sealed", 0, "跳过下一次攻击阶段"))
	if burn > 0:
		statuses.append(_status_entry("burn", burn, "回合结束时受到伤害并减少1层"))
	if frost > 0:
		statuses.append(_status_entry("frost", frost, "达到3层时触发冻结"))
	if bool(state.get("paralyzed", false)):
		statuses.append(_status_entry("paralyzed", 0, "攻击时有50%概率失败"))
	if bool(state.get("frozen", false)):
		statuses.append(_status_entry("frozen", 0, "本回合无法攻击"))
	_populate_status_bar(statuses)


func set_selected_state(selected: bool) -> void:
	_bind_scene_nodes()
	_selected_state = selected
	_selection_outline.visible = selected or _focus_visual_active


func set_drag_active(active: bool) -> void:
	_set_focus_visual(active, 1.2)


func set_hover_active(active: bool) -> void:
	_set_focus_visual(active, 1.2)


func _set_focus_visual(active: bool, scale_factor: float) -> void:
	_bind_scene_nodes()
	if _drag_tween and _drag_tween.is_valid():
		_drag_tween.kill()
	pivot_offset = size * 0.5
	_focus_visual_active = active
	if active:
		_resting_z_index = z_index
		z_index = 30
		_selection_outline.visible = true
	else:
		z_index = _resting_z_index
		_selection_outline.visible = _selected_state
	_drag_tween = create_tween()
	_drag_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_drag_tween.tween_property(
		self,
		"scale",
		Vector2.ONE * (scale_factor if active else 1.0),
		0.1
	)


func play_invalid_feedback() -> void:
	_bind_scene_nodes()
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_selection_outline.visible = true
	_selection_outline.modulate = Color(1.0, 0.25, 0.2, 1.0)
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(
		_selection_outline,
		"modulate:a",
		0.25,
		0.12
	)
	_feedback_tween.tween_property(
		_selection_outline,
		"modulate:a",
		1.0,
		0.12
	)
	_feedback_tween.tween_callback(_finish_invalid_feedback)


func _finish_invalid_feedback() -> void:
	_selection_outline.modulate = Color.WHITE
	_selection_outline.visible = _selected_state or _focus_visual_active


func set_interactable(interactable: bool) -> void:
	_bind_scene_nodes()
	_interactable = interactable
	disabled = false
	_unavailable_overlay.visible = not interactable


func set_as_slot_content() -> void:
	_bind_scene_nodes()
	_interactable = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	disabled = true
	_unavailable_overlay.visible = false


func set_as_browse_content() -> void:
	_bind_scene_nodes()
	_interactable = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	disabled = false
	_unavailable_overlay.visible = false


func set_as_drag_proxy() -> void:
	_bind_scene_nodes()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	disabled = true
	_unavailable_overlay.visible = false
	_selection_outline.visible = true


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	var screen_position := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		screen_position = event.global_position
		if event.pressed:
			_begin_pointer_interaction(screen_position)
		else:
			_finish_pointer_interaction(screen_position)
		accept_event()
	elif event is InputEventMouseMotion and _pointer_down:
		screen_position = event.global_position
		_update_pointer_interaction(screen_position)
		accept_event()
	elif event is InputEventScreenTouch:
		screen_position = event.position
		if event.pressed:
			_begin_pointer_interaction(screen_position)
		else:
			_finish_pointer_interaction(screen_position)
		accept_event()
	elif event is InputEventScreenDrag and _pointer_down:
		screen_position = event.position
		_update_pointer_interaction(screen_position)
		accept_event()


func _begin_pointer_interaction(screen_position: Vector2) -> void:
	_pointer_down = true
	_dragging = false
	_pointer_origin = screen_position


func _update_pointer_interaction(screen_position: Vector2) -> void:
	if not _interactable:
		return
	if not _dragging and screen_position.distance_to(_pointer_origin) >= DRAG_THRESHOLD:
		_dragging = true
		card_drag_started.emit(screen_position)
	if _dragging:
		card_drag_moved.emit(screen_position)


func _finish_pointer_interaction(screen_position: Vector2) -> void:
	if not _pointer_down:
		return
	if _dragging:
		card_drag_ended.emit(screen_position)
	else:
		card_clicked.emit()
	_pointer_down = false
	_dragging = false


func _bind_scene_nodes() -> void:
	if _nodes_bound:
		return
	_nodes_bound = true
	_card_canvas = get_node("%CardCanvas")
	_art = get_node("%CharacterArt")
	_frame = get_node("%QualityFrame")
	_name_label = get_node("%CardName")
	_description_label = get_node("%Description")
	_cost_label = get_node("%CostLabel")
	_attack_label = get_node("%AttackLabel")
	_health_label = get_node("%HealthLabel")
	_use_count_badge = get_node("%UseCountBadge")
	_use_count_label = get_node("%UseCountLabel")
	_status_bar = get_node("%StatusBar")
	_selection_outline = get_node("%SelectionOutline")
	_unavailable_overlay = get_node("%UnavailableOverlay")


func _layout_canvas() -> void:
	if not _nodes_bound or size.x <= 0.0 or size.y <= 0.0:
		return
	var canvas_scale := minf(
		size.x / BASE_SIZE.x,
		size.y / BASE_SIZE.y
	)
	var scaled_size := BASE_SIZE * canvas_scale
	_card_canvas.scale = Vector2.ONE * canvas_scale
	_card_canvas.position = (size - scaled_size) * 0.5
	pivot_offset = size * 0.5


func _update_use_count(state: Dictionary) -> void:
	var show_count := (
		state.has("remaining_uses")
		and bool(state.get("show_use_count", true))
	)
	_use_count_badge.visible = show_count
	_use_count_label.visible = show_count
	if not show_count:
		return
	var remaining := int(state.get("remaining_uses", -1))
	_use_count_label.text = "∞" if remaining < 0 else str(remaining)
	_use_count_badge.tooltip_text = (
		"剩余使用次数：无限"
		if remaining < 0
		else "剩余使用次数：%d" % remaining
	)


func _fit_name_font() -> void:
	var font := _name_label.get_theme_font("font")
	var font_size := 15
	var available_width := maxf(1.0, _name_label.size.x - 4.0)
	while font_size > 11:
		var text_width := font.get_string_size(
			_name_label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size
		).x
		if text_width <= available_width:
			break
		font_size -= 1
	_name_label.add_theme_font_size_override("font_size", font_size)


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


func _status_entry(
	status_id: String,
	value: int,
	detail: String
) -> Dictionary:
	return {
		"id": status_id,
		"value": value,
		"detail": detail,
	}


func _clear_status_bar() -> void:
	for child in _status_bar.get_children():
		_status_bar.remove_child(child)
		child.queue_free()
	_status_bar.visible = false


func _populate_status_bar(statuses: Array[Dictionary]) -> void:
	if statuses.is_empty():
		return
	_status_bar.visible = true
	var shown := mini(statuses.size(), 5)
	for index in shown:
		_status_bar.add_child(_create_status_badge(statuses[index]))
	if statuses.size() > shown:
		var overflow := Label.new()
		overflow.custom_minimum_size = Vector2(24, 24)
		overflow.text = "+%d" % (statuses.size() - shown)
		overflow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overflow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		overflow.add_theme_font_size_override("font_size", 10)
		overflow.add_theme_color_override("font_color", Color("fff1b8"))
		overflow.add_theme_color_override("font_outline_color", Color("102029"))
		overflow.add_theme_constant_override("outline_size", 3)
		overflow.tooltip_text = "还有 %d 个状态" % (statuses.size() - shown)
		_status_bar.add_child(overflow)


func _create_status_badge(status: Dictionary) -> Control:
	var status_id := str(status["id"])
	var definition: Dictionary = STATUS_DEFINITIONS[status_id]
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(24, 24)
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	badge.tooltip_text = "%s：%s" % [
		str(definition["name"]),
		str(status["detail"]),
	]

	var icon_path := "%s/%s" % [STATUS_ICON_DIR, definition["icon"]]
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.texture = load(icon_path) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(icon)
	else:
		var fallback := Label.new()
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.text = str(definition["fallback"])
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 10)
		fallback.add_theme_color_override("font_color", Color.WHITE)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(fallback)

	var value := int(status["value"])
	if value > 0:
		var value_label := Label.new()
		value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		value_label.offset_left = 10.0
		value_label.offset_top = 10.0
		value_label.text = str(value)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		value_label.add_theme_font_size_override("font_size", 9)
		value_label.add_theme_color_override("font_color", Color.WHITE)
		value_label.add_theme_color_override(
			"font_outline_color",
			Color("102029")
		)
		value_label.add_theme_constant_override("outline_size", 3)
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(value_label)
	return badge
