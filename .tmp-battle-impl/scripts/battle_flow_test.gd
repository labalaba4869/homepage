extends Control


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var battle := $Battle
	var opening_hand: Array = battle.get("_player_hand")
	assert(opening_hand.size() == 5, "Player must draw five opening cards")
	assert(int(battle.get("_player_energy")) == 6, "First energy must use table")

	var chosen: Dictionary = opening_hand[0]
	battle.call("_on_hand_card_pressed", int(chosen["instance_id"]))
	assert(
		int(battle.get("_selected_instance_id")) == int(chosen["instance_id"]),
		"Clicking a hand card must select it"
	)
	battle.call("_on_player_slot_pressed", 0)
	await get_tree().process_frame
	var player_board: Array = battle.get("_player_board")
	assert(player_board[0] != null, "Selected card must enter slot one")
	assert(
		(battle.get("_player_hand") as Array).size() == 4,
		"Played card must leave the hand"
	)

	battle.call("_on_end_turn_pressed")
	await get_tree().create_timer(3.5).timeout
	assert(
		int(battle.get("_enemy_turn_number")) == 1,
		"Enemy must complete its first turn"
	)
	assert(
		int(battle.get("_player_turn_number")) == 2,
		"Control must return to player turn two"
	)
	assert(
		str(battle.get("_phase")) == "player_input",
		"Player input must be restored after enemy attack"
	)
	var enemy_board: Array = battle.get("_enemy_board")
	assert(
		enemy_board.any(func(hero: Variant) -> bool: return hero != null),
		"Enemy AI must place at least one affordable hero"
	)
	print("BATTLE_FLOW_TEST_PASS")
	get_tree().quit()
