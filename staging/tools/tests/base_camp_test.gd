extends Node

const BASE_SCENE := preload("res://scenes/base.tscn")
const DECK_SCENE := preload("res://scenes/ui/base/deck_overview.tscn")
const PREVIEW_PATH := "D:/Homepage Dev/tmp/base_camp_preview.png"
const SHOP_PREVIEW_PATH := "D:/Homepage Dev/tmp/merchant_shop_preview.png"

var _failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InventoryState.ensure_initialized()
	var base := BASE_SCENE.instantiate()
	get_tree().root.add_child(base)
	await get_tree().process_frame
	await get_tree().process_frame

	var ground := base.get_node("TileLayers/GroundLayer") as TileMapLayer
	var road := base.get_node("TileLayers/RoadLayer") as TileMapLayer
	_check(ground.get_used_cells().size() == 640, "ground has 32x20 cells")
	_check(road.get_used_cells().size() > 100, "road clearing is painted")
	_check(base.get_node_or_null("Actors/Player") != null, "player exists")
	_check(base.get_node_or_null("Environment/Merchant") != null, "merchant exists")
	_check(base.get_node_or_null("Environment/Campfire") != null, "campfire exists")

	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		_check(image.save_png(PREVIEW_PATH) == OK, "runtime preview was saved")

	base._open_shop()
	var shop := base.get("_active_ui") as MerchantShop
	for index in 4:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		var shop_image := get_viewport().get_texture().get_image()
		_check(
			shop_image.save_png(SHOP_PREVIEW_PATH) == OK,
			"shop preview was saved"
		)
	_check(shop.get_node("%ShopGrid").get_child_count() > 0, "shop has cards")
	var selected_card := -1
	for card_value in InventoryState.cards.values():
		var card: Dictionary = card_value
		if int(card.get("shop_enabled", 0)) == 1:
			selected_card = int(card["card_id"])
			break
	_check(selected_card >= 0, "shop table has an enabled card")
	if selected_card >= 0:
		var owned_before := InventoryState.owned_cards.size()
		var price := int(InventoryState.get_card(selected_card).get("buy_price", 0))
		InventoryState.player_coins = price
		var purchase := InventoryState.purchase_shop_card(selected_card)
		_check(bool(purchase.get("ok", false)), "card purchase succeeds")
		_check(InventoryState.player_coins == 0, "card purchase deducts coins")
		_check(
			InventoryState.owned_cards.size() == owned_before + 1,
			"purchased card enters owned cards"
		)
	base._close_active_ui()
	await get_tree().process_frame

	var sale_indices: Array[int] = []
	var expected_sale := 0
	for index in InventoryState.inventory_slots.size():
		var stack = InventoryState.inventory_slots[index]
		if stack == null:
			continue
		sale_indices.append(index)
		expected_sale += InventoryState.get_stack_sell_value(stack)
		if sale_indices.size() >= 2:
			break
	if not sale_indices.is_empty():
		var sale_result := InventoryState.sell_inventory_stacks(sale_indices)
		_check(
			int(sale_result.get("earned", -1)) == expected_sale,
			"bulk sale pays the expected total"
		)

	var deck := DECK_SCENE.instantiate() as DeckOverview
	get_tree().root.add_child(deck)
	await get_tree().process_frame
	_check(deck.get_node_or_null("%DeckGrid") != null, "deck overview loads")

	base.queue_free()
	deck.queue_free()
	await get_tree().process_frame
	print("BASE_CAMP_TEST_PASS")
	get_tree().quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
