extends Node


func _ready() -> void:
	await get_tree().process_frame
	InventoryState.ensure_initialized()
	GameSession.ensure_player_state()

	_assert(InventoryState.cards.size() == 44, "expected 44 cards")
	_assert(InventoryState.items.size() == 57, "expected 42 items + 15 active items")
	_assert(InventoryState.loot_groups.size() == 2, "expected two loot groups")

	var bandage_count := InventoryState.get_inventory_item_count(10000)
	_assert(bandage_count == 2, "player should start with two bandages")
	_assert(
		InventoryState.bind_active_item(0, 10000).is_empty(),
		"bandage should bind"
	)
	var full_result := InventoryState.use_active_binding(0)
	_assert(not bool(full_result["ok"]), "full health use must fail")
	_assert(
		InventoryState.get_inventory_item_count(10000) == bandage_count,
		"failed use must not consume"
	)

	GameSession.set_player_hp(10)
	var heal_result := InventoryState.use_active_binding(0)
	_assert(bool(heal_result["ok"]), "bandage use should succeed")
	_assert(GameSession.player_hp == 12, "10% max health should heal two")
	_assert(
		InventoryState.get_inventory_item_count(10000) == bandage_count - 1,
		"successful use should consume one"
	)

	_give_active_item(10013)
	_assert(
		InventoryState.bind_active_item(1, 10013).is_empty(),
		"card book should bind"
	)
	var card_book_result := InventoryState.use_active_binding(1)
	_assert(bool(card_book_result["ok"]), "card book should activate")
	var guaranteed := InventoryState.get_or_create_container(
		"smoke_guaranteed_card",
		1
	)
	_assert(_has_card(guaranteed["slots"]), "card book must guarantee a card")

	_give_active_item(10006)
	_assert(
		InventoryState.bind_active_item(2, 10006).is_empty(),
		"wish slip should bind"
	)
	var wish_result := InventoryState.use_active_binding(2)
	_assert(bool(wish_result["ok"]), "wish slip should activate")
	var filled := InventoryState.get_or_create_container(
		"smoke_full_container",
		2
	)
	for entry in filled["slots"]:
		_assert(entry != null, "wish slip must fill every slot")
		_assert(
			str(entry.get("content_type", "item")) in ["item", "card"],
			"container entry type must be valid"
		)

	var owned_before := InventoryState.owned_cards.size()
	var slots: Array = guaranteed["slots"]
	var revealed: Array = guaranteed["revealed"]
	var card_index := _first_card_index(slots)
	revealed[card_index] = true
	var transfer_error := InventoryState.transfer_container_to_inventory(
		"smoke_guaranteed_card",
		card_index
	)
	_assert(transfer_error.is_empty(), "card transfer should succeed")
	_assert(
		InventoryState.owned_cards.size() == owned_before + 1,
		"card transfer should add one owned card"
	)

	GameSession.start_new_expedition()
	_assert(
		GameSession.queue_next_battle_attack_bonus(1).is_empty(),
		"battle attack bonus should queue"
	)
	_assert(
		not GameSession.queue_next_battle_attack_bonus(1).is_empty(),
		"equal battle attack bonus should be rejected"
	)
	GameSession.begin_battle(1, Vector2.ZERO)
	_assert(
		GameSession.active_battle_attack_bonus == 1,
		"queued attack bonus should activate on battle entry"
	)
	GameSession.set_player_hp(7)
	GameSession.finish_battle("retreat")
	_assert(GameSession.player_hp == 7, "retreat should preserve health")

	_assert(
		GameSession.queue_instant_normal_kill().is_empty(),
		"instant kill should queue"
	)
	_assert(
		not GameSession.try_instant_enemy_defeat(1000, "boss"),
		"instant kill must not affect a boss"
	)
	_assert(
		GameSession.try_instant_enemy_defeat(1, "normal"),
		"instant kill should affect the next normal enemy"
	)

	_assert(
		GameSession.queue_move_speed_buff(10, 20).is_empty(),
		"speed buff should activate"
	)
	_assert(
		not GameSession.queue_move_speed_buff(10, 30).is_empty(),
		"equal speed buff should be rejected"
	)
	_assert(
		GameSession.queue_move_speed_buff(30, 30).is_empty(),
		"stronger speed buff should replace the old effect"
	)
	_assert(
		is_equal_approx(GameSession.get_move_speed_multiplier(), 1.3),
		"speed multiplier should match configured percent"
	)

	print("ACTIVE_ITEM_SMOKE_OK")
	get_tree().quit(0)


func _give_active_item(item_id: int) -> void:
	for index in InventoryState.inventory_slots.size():
		if InventoryState.inventory_slots[index] == null:
			InventoryState.inventory_slots[index] = {
				"item_id": item_id,
				"count": 1,
			}
			InventoryState.inventory_changed.emit()
			return
	_assert(false, "no free inventory slot for smoke test")


func _has_card(slots: Array) -> bool:
	return _first_card_index(slots) >= 0


func _first_card_index(slots: Array) -> int:
	for index in slots.size():
		var entry = slots[index]
		if (
			entry != null
			and str(entry.get("content_type", "item")) == "card"
		):
			return index
	return -1


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("ACTIVE_ITEM_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
