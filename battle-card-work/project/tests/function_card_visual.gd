extends Node

const BATTLE_SCENE := preload("res://scenes/battle.tscn")


func _ready() -> void:
	GameSession.ensure_player_state()
	GameSession.current_enemy_id = 1
	var battle = BATTLE_SCENE.instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame

	battle._phase = "player_input"
	battle._is_player_turn = true
	battle._battle_over = false
	battle._player_energy = 99
	battle._player_board = [
		battle._create_hero_state(100, true),
		battle._create_hero_state(101, true),
		battle._create_hero_state(102, true),
	]
	battle._enemy_board = [
		battle._create_hero_state(200, false),
		battle._create_hero_state(201, false),
		battle._create_hero_state(202, false),
	]
	battle._player_board[0]["shield"] = 2
	battle._player_board[0]["turn_attack_bonus"] = 1
	battle._player_board[0]["extra_attacks"] = 1
	battle._player_board[1]["pierce"] = true
	battle._enemy_board[0]["sealed"] = true
	battle._enemy_board[1]["burn"] = 2
	battle._enemy_board[2]["frost"] = 2
	var hand: Array[Dictionary] = [
		{"instance_id": 8101, "card_id": 5},
		{"instance_id": 8102, "card_id": 8},
		{"instance_id": 8103, "card_id": 10},
		{"instance_id": 8104, "card_id": 12},
		{"instance_id": 8105, "card_id": 100},
	]
	battle._player_hand = hand
	battle._refresh_all()
	await get_tree().process_frame
	await get_tree().process_frame

	var card_view = battle._hand_container.get_child(0)
	var target_rect: Rect2 = battle._player_slot_buttons[0].get_global_rect()
	var target_rects: Array[Rect2] = [target_rect]
	battle._target_overlay.begin_drag(
		battle._cards[5],
		card_view.get_global_rect().get_center(),
		"friendly_target",
		battle.hand_card_size
	)
	battle._target_overlay.update_drag(
		target_rect.get_center(),
		target_rects,
		true,
		target_rect.get_center()
	)

	await get_tree().create_timer(0.8).timeout
	battle._target_overlay.cancel_immediately()
	await get_tree().process_frame
	var global_card_view = battle._hand_container.get_child(1)
	var release_rect: Rect2 = battle._battlefield_release_rect()
	var global_target_rects: Array[Rect2] = battle._global_target_rects(8)
	battle._target_overlay.begin_drag(
		battle._cards[8],
		global_card_view.get_global_rect().get_center(),
		"global_target",
		battle.hand_card_size
	)
	battle._target_overlay.update_drag(
		release_rect.get_center(),
		global_target_rects,
		true,
		release_rect.get_center(),
		release_rect,
		true
	)

	await get_tree().create_timer(1.2).timeout
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
