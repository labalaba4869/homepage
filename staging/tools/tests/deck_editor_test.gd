extends Node

const DECK_OVERVIEW_SCENE := preload("res://scenes/ui/base/deck_overview.tscn")
const PREVIEW_PATH := "D:/Homepage Dev/tmp/deck_editor_preview.png"

var _failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InventoryState.ensure_initialized()
	var shop_card_id := _first_shop_card_id()
	var price := int(InventoryState.get_card(shop_card_id).get("buy_price", 0))
	InventoryState.player_coins = price * 12
	for index in 12:
		var purchase := InventoryState.purchase_shop_card(shop_card_id)
		_check(bool(purchase.get("ok", false)), "shop card %d was granted" % index)

	var overview := DECK_OVERVIEW_SCENE.instantiate() as DeckOverview
	get_tree().root.add_child(overview)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(InventoryState.deck_cards.size() == 10, "starting deck has 10 cards")

	var initial_deck_card := _card_at(overview.deck_grid, 0)
	initial_deck_card.set_hover_active(true)
	await get_tree().create_timer(0.16).timeout
	initial_deck_card.set_hover_active(true)
	await get_tree().create_timer(0.16).timeout
	_check(
		initial_deck_card.scale.is_equal_approx(Vector2.ONE * 1.2),
		"hover remains enlarged while still active"
	)
	initial_deck_card.set_hover_active(false)
	await get_tree().create_timer(0.16).timeout
	_check(initial_deck_card.scale.is_equal_approx(Vector2.ONE), "hover returns to normal")

	# Exported values must refresh the dynamically generated card cells at runtime.
	overview.card_display_size = Vector2(140, 200)
	overview.card_hover_scale = 1.1
	overview.card_slot_padding = Vector2(6, 7)
	await get_tree().process_frame
	await get_tree().process_frame
	var resized_card := _card_at(overview.deck_grid, 0)
	var resized_cell := overview.deck_grid.get_child(0) as CenterContainer
	_check(resized_card.size.is_equal_approx(Vector2(140, 200)), "exported card size refreshes at runtime")
	_check(
		resized_cell.custom_minimum_size.is_equal_approx(Vector2(160, 227)),
		"exported hover scale and slot padding refresh at runtime"
	)

	overview._begin_edit()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		_check(image.save_png(PREVIEW_PATH) == OK, "deck editor preview was saved")
	_check(overview._editing, "edit mode starts")
	var removal_card := _card_at(overview.deck_grid, 0)
	var outline := removal_card.get_node("CardCanvas/SelectionOutline") as Panel
	_check(outline.visible and outline.modulate.r > outline.modulate.g, "deck card has red edit outline")

	for index in 10:
		var deck_card := _card_at(overview.deck_grid, 0)
		deck_card.card_clicked.emit()
		await get_tree().process_frame
	_check(overview._draft_deck_cards.size() == 10, "cannot remove below 10 cards")
	_check(overview.limit_dialog.visible, "minimum deck count opens a notice")
	overview.limit_dialog.hide()

	for index in 10:
		var owned_card := _card_at(overview.owned_grid, 0)
		owned_card.card_clicked.emit()
		await get_tree().process_frame
	_check(overview._draft_deck_cards.size() == 20, "cards can be added up to 20")
	var extra_owned_card := _card_at(overview.owned_grid, 0)
	extra_owned_card.card_clicked.emit()
	await get_tree().process_frame
	_check(overview._draft_deck_cards.size() == 20, "cannot add above 20 cards")
	_check(overview.limit_dialog.visible, "maximum deck count opens a notice")
	overview.limit_dialog.hide()

	overview._save_edit()
	await get_tree().process_frame
	_check(not overview._editing, "save closes edit mode")
	_check(InventoryState.deck_cards.size() == 20, "save writes the deck draft")

	overview._begin_edit()
	await get_tree().process_frame
	var card_to_discard := _card_at(overview.deck_grid, 0)
	card_to_discard.card_clicked.emit()
	await get_tree().process_frame
	_check(overview._draft_deck_cards.size() == 19, "draft removal is visible")
	overview._discard_edit()
	await get_tree().process_frame
	_check(InventoryState.deck_cards.size() == 20, "discard keeps the saved deck")

	overview.queue_free()
	await get_tree().process_frame
	print("DECK_EDITOR_TEST_PASS")
	get_tree().quit(1 if _failed else 0)


func _first_shop_card_id() -> int:
	for value in InventoryState.cards.values():
		var card: Dictionary = value
		if int(card.get("shop_enabled", 0)) == 1:
			return int(card["card_id"])
	return -1


func _card_at(grid: GridContainer, index: int) -> BattleCardView:
	var cell := grid.get_child(index) as CenterContainer
	return cell.get_child(0) as BattleCardView


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
