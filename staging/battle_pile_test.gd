extends Node

const BATTLE_SCENE := preload("res://scenes/battle.tscn")

var _failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InventoryState.ensure_initialized()
	var inventory_snapshot := InventoryState.get_save_data()
	var battle = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame

	var persistent_card: Dictionary = InventoryState.get_deck_card_instances()[0]
	battle.set("_player_deck", [])
	battle.set("_player_discard_pile", [persistent_card.duplicate(true)])
	battle.set("_player_hand", [])
	_check(battle._draw_card(true, false), "Empty draw pile did not shuffle discard pile")
	var hand: Array = battle.get("_player_hand")
	_check(hand.size() == 1, "Draw after discard shuffle did not add a hand card")
	_check(
		(battle.get("_player_discard_pile") as Array).is_empty(),
		"Discard pile was not emptied after shuffle"
	)

	var instance_id := int(persistent_card["instance_id"])
	var before := int(persistent_card["remaining_uses"])
	battle._mark_player_card_used(hand[0])
	battle._mark_player_card_used(hand[0])
	battle._settle_player_card_uses()
	var after := _find_remaining_uses(instance_id)
	_check(after == before - 1, "A card used repeatedly in one battle lost more than one use")

	battle.queue_free()
	InventoryState.apply_save_data(inventory_snapshot)
	get_tree().quit(1 if _failed else 0)


func _find_remaining_uses(instance_id: int) -> int:
	for card_instance in InventoryState.deck_cards:
		if int(card_instance.get("instance_id", -1)) == instance_id:
			return int(card_instance.get("remaining_uses", -1))
	for card_instance in InventoryState.owned_cards:
		if int(card_instance.get("instance_id", -1)) == instance_id:
			return int(card_instance.get("remaining_uses", -1))
	return -1


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
