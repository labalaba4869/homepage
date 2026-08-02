extends SceneTree

const CARD_SCENE := preload("res://scenes/ui/card_view.tscn")
const DETAIL_SCENE := preload("res://scenes/ui/card_detail_overlay.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var cards := GameData.load_cards()
	var function_card := _find_card(cards, "function")
	var hero_card := _find_card(cards, "battle_hero")
	_check(not function_card.is_empty(), "Missing function card data")
	_check(not hero_card.is_empty(), "Missing hero card data")

	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(stage)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("242b2a")
	stage.add_child(background)

	var function_view = CARD_SCENE.instantiate()
	stage.add_child(function_view)
	function_view.position = Vector2(74, 44)
	function_view.configure(
		function_card,
		Vector2(288, 408),
		{"remaining_uses": 8}
	)
	_check(not function_view.get_node("%AttackLabel").visible, "Function attack badge is visible")
	_check(not function_view.get_node("%HealthLabel").visible, "Function health badge is visible")
	_check(function_view.get_node("%UseCountBadge").visible, "Use badge is hidden")
	_check(function_view.get_node("%UseCountLabel").text == "8", "Use badge count is wrong")

	var hero_view = CARD_SCENE.instantiate()
	stage.add_child(hero_view)
	hero_view.position = Vector2(438, 44)
	hero_view.configure(
		hero_card,
		Vector2(288, 408),
		{"remaining_uses": -1}
	)
	_check(hero_view.get_node("%AttackLabel").visible, "Hero attack badge is hidden")
	_check(hero_view.get_node("%HealthLabel").visible, "Hero health badge is hidden")
	_check(hero_view.get_node("%UseCountLabel").text == "∞", "Infinite use badge is wrong")

	var detail = DETAIL_SCENE.instantiate()
	stage.add_child(detail)
	detail.show_card(function_card, {"remaining_uses": 8})
	_check(detail.visible, "Card detail overlay failed to open")
	await _click(Vector2(400, 250))
	_check(detail.visible, "Clicking the detail card closed the overlay")
	await _click(Vector2(12, 12))
	_check(not detail.visible, "Clicking the backdrop did not close the overlay")
	detail.show_card(function_card, {"remaining_uses": 8})
	await _press_escape()
	_check(not detail.visible, "Escape did not close the detail overlay")

	var inventory_state = get_root().get_node_or_null("InventoryState")
	_check(inventory_state != null, "InventoryState autoload is unavailable")
	if inventory_state != null:
		inventory_state.ensure_initialized()
	if inventory_state != null and not inventory_state.deck_cards.is_empty():
		var persistent: Dictionary = inventory_state.deck_cards[0]
		var before := int(persistent.get("remaining_uses", -1))
		var after: int = inventory_state.consume_card_use(
			int(persistent["instance_id"])
		)
		_check(before < 0 or after == before - 1, "Persistent card use did not decrement")

	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		var image := get_root().get_texture().get_image()
		image.save_png("D:/Homepage Dev/card_use_preview.png")
	quit(1 if _failed else 0)


func _find_card(cards: Dictionary, card_type: String) -> Dictionary:
	for card in cards.values():
		if str(card.get("card_type", "")) == card_type:
			return card
	return {}


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _press_escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
