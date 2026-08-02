class_name CardTargetOverlay
extends Control

@export_group("Arrow")
@export var arrow_width := 5.0
@export var dash_length := 13.0
@export var dash_gap := 8.0
@export var curve_height := 72.0
@export var arrow_head_size := 16.0
@export_group("Target")
@export var target_outline_width := 4.0
@export var target_outline_padding := 5.0
@export var friendly_color := Color("77d9ac")
@export var enemy_color := Color("e6756f")
@export var placement_color := Color("f1ca5f")
@export var invalid_color := Color("8b7d7d")

var _active := false
var _mode := ""
var _origin := Vector2.ZERO
var _pointer := Vector2.ZERO
var _arrow_end := Vector2.ZERO
var _target_rects: Array[Rect2] = []
var _target_valid := false
var _release_zone := Rect2()
var _release_zone_active := false
var _flash_rects: Array[Rect2] = []
var _flash_color := Color.WHITE
var _flash_alpha := 0.0

@onready var _feedback_label: Label = %FeedbackLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func begin_drag(
	origin: Vector2,
	mode: String
) -> void:
	cancel_immediately()
	_active = true
	_mode = mode
	_origin = origin
	_pointer = origin
	_arrow_end = origin
	_target_valid = false
	_release_zone_active = false
	_target_rects.clear()
	set_process(true)
	queue_redraw()


func update_drag(
	pointer: Vector2,
	target_rects: Array[Rect2],
	target_valid: bool,
	arrow_target: Vector2,
	release_zone: Rect2 = Rect2(),
	release_zone_active := false
) -> void:
	if not _active:
		return
	_pointer = pointer
	_target_rects = target_rects
	_target_valid = target_valid
	_arrow_end = arrow_target if target_valid else pointer
	_release_zone = release_zone
	_release_zone_active = release_zone_active
	queue_redraw()


func finish_success(
	target_rects: Array[Rect2],
	message: String
) -> void:
	if not _active:
		return
	var target := (
		target_rects[0].get_center()
		if not target_rects.is_empty()
		else _arrow_end
	)
	_active = false
	_target_rects.clear()
	_release_zone = Rect2()
	_flash_rects = target_rects.duplicate()
	_flash_color = _accent_color()
	_flash_alpha = 1.0
	_show_feedback(target, message, _flash_color)
	set_process(true)
	queue_redraw()


func cancel_drag() -> void:
	if not _active:
		return
	_active = false
	_target_rects.clear()
	_release_zone = Rect2()
	set_process(true)
	queue_redraw()


func cancel_immediately() -> void:
	_active = false
	_target_rects.clear()
	_release_zone = Rect2()
	queue_redraw()


func is_dragging() -> bool:
	return _active


func _process(delta: float) -> void:
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 2.8)
	if not _active and _flash_alpha <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _active:
		var color := _accent_color() if _target_valid else invalid_color
		_draw_dashed_curve(_origin, _arrow_end, color)
		for rect in _target_rects:
			_draw_target_rect(rect, color, 0.82)
		if not _release_zone.size.is_zero_approx():
			_draw_release_marker(
				_release_zone,
				_accent_color() if _release_zone_active else invalid_color
			)
	if _flash_alpha > 0.0:
		for rect in _flash_rects:
			_draw_target_rect(rect, _flash_color, _flash_alpha)


func _draw_dashed_curve(
	start: Vector2,
	end: Vector2,
	color: Color
) -> void:
	if start.distance_to(end) < 4.0:
		return
	var midpoint := (start + end) * 0.5
	var direction := (end - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var control := midpoint + normal * curve_height
	var previous := start
	var travelled := 0.0
	var dash_cycle := dash_length + dash_gap
	for index in range(1, 65):
		var t := float(index) / 64.0
		var point := _quadratic_bezier(start, control, end, t)
		var segment_length := previous.distance_to(point)
		var cycle_position := fmod(travelled, dash_cycle)
		if cycle_position < dash_length:
			draw_line(previous, point, color, arrow_width, true)
		travelled += segment_length
		previous = point
	var tangent := (end - control).normalized()
	var side := Vector2(-tangent.y, tangent.x)
	var base := end - tangent * arrow_head_size
	draw_colored_polygon(
		PackedVector2Array([
			end,
			base + side * arrow_head_size * 0.58,
			base - side * arrow_head_size * 0.58,
		]),
		color
	)


func _draw_target_rect(
	rect: Rect2,
	color: Color,
	alpha: float
) -> void:
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.009)
	var final_color := Color(color, color.a * alpha)
	draw_rect(
		rect.grow(target_outline_padding * pulse),
		final_color,
		false,
		target_outline_width,
		true
	)


func _draw_release_marker(rect: Rect2, color: Color) -> void:
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.13
	draw_circle(center, radius, Color(color, 0.1))
	draw_arc(center, radius, 0.0, TAU, 48, Color(color, 0.72), 3.0, true)
	draw_arc(
		center,
		radius - 8.0,
		-Time.get_ticks_msec() * 0.002,
		-Time.get_ticks_msec() * 0.002 + PI * 1.3,
		32,
		Color(color, 0.92),
		4.0,
		true
	)


func _show_feedback(
	position: Vector2,
	message: String,
	color: Color
) -> void:
	_feedback_label.text = message
	_feedback_label.add_theme_color_override("font_color", color)
	_feedback_label.position = position - Vector2(100, 12)
	_feedback_label.modulate.a = 1.0
	_feedback_label.show()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		_feedback_label,
		"position:y",
		_feedback_label.position.y - 28.0,
		0.65
	)
	tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.65)
	tween.finished.connect(_feedback_label.hide)


func _accent_color() -> Color:
	match _mode:
		"enemy_target":
			return enemy_color
		"hero_placement":
			return placement_color
		_:
			return friendly_color


func _quadratic_bezier(
	start: Vector2,
	control: Vector2,
	end: Vector2,
	t: float
) -> Vector2:
	var inverse := 1.0 - t
	return (
		inverse * inverse * start
		+ 2.0 * inverse * t * control
		+ t * t * end
	)
