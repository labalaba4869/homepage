extends Node

const BATTLE_SCENE := preload("res://scenes/battle.tscn")

var _battle: Control
var _instance_id := 9000
var _failed := false


func _ready() -> void:
	GameSession.ensure_player_state()
	GameSession.current_enemy_id = 1
	_battle = BATTLE_SCENE.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame

	_battle._phase = "player_input"
	_battle._is_player_turn = true
	_battle._battle_over = false
	_battle._player_energy = 99
	_battle._player_hp = int(_battle._player_data["max_hp"])
	_battle._enemy_hp = 99
	_battle._player_board = [null, null, null]
	_battle._enemy_board = [null, null, null]

	_test_failed_heal_is_free()
	if _failed:
		return
	_test_player_heal()
	if _failed:
		return
	_test_targeted_and_global_effects()
	if _failed:
		return
	_test_draw()
	if _failed:
		return
	await _test_pierce_attack()
	if _failed:
		return
	await _test_combo_attack()
	if _failed:
		return
	await _test_seal_skip()
	if _failed:
		return

	print("FUNCTION_CARD_SMOKE_OK")
	_battle.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _test_failed_heal_is_free() -> void:
	var energy_before: int = _battle._player_energy
	var instance_id := _set_hand_card(1)
	_battle._play_function_card(instance_id, -1, _no_target_rects())
	_assert(_battle._player_hand.size() == 1, "full-health heal must stay in hand")
	_assert(_battle._player_energy == energy_before, "failed heal must not cost energy")


func _test_player_heal() -> void:
	_battle._player_hp = 10
	var instance_id := _set_hand_card(1)
	var energy_before: int = _battle._player_energy
	_battle._play_function_card(instance_id, -1, _no_target_rects())
	_assert(_battle._player_hp == 12, "bandage should restore 10% max health")
	_assert(_battle._player_hand.is_empty(), "successful heal must leave hand")
	_assert(
		_battle._player_energy == energy_before - int(_battle._cards[1]["cost"]),
		"successful heal must cost configured energy"
	)


func _test_targeted_and_global_effects() -> void:
	_battle._player_board = [
		_battle._create_hero_state(100, true),
		_battle._create_hero_state(101, true),
		null,
	]
	_battle._enemy_board = [
		_battle._create_hero_state(100, false),
		null,
		null,
	]

	_play_on_slot(5, 0)
	_assert(_battle._player_board[0]["shield"] == 1, "guard should add shield")
	_play_on_slot(5, 0)
	_assert(_battle._player_board[0]["shield"] == 2, "shield should stack")

	_play_on_slot(6, 0)
	_assert(
		_battle._player_board[0]["turn_attack_bonus"] == 1,
		"excite should add turn attack"
	)

	_battle._player_board[0]["current_hp"] = 1
	_play_on_slot(7, 0)
	_assert(_battle._player_board[0]["current_hp"] == 2, "target heal should heal one")

	_play_on_slot(8, -1)
	_assert(
		_battle._player_board[0]["turn_attack_bonus"] == 2,
		"global attack buff should include first hero"
	)
	_assert(
		_battle._player_board[1]["turn_attack_bonus"] == 1,
		"global attack buff should include second hero"
	)

	_play_on_slot(10, 0)
	_assert(_battle._player_board[0]["pierce"], "pierce flag should be set")

	_play_on_slot(11, 0)
	_play_on_slot(11, 0)
	_assert(
		_battle._player_board[0]["extra_attacks"] == 2,
		"two combo cards should add two extra attacks"
	)

	_play_on_slot(12, 0)
	_assert(_battle._enemy_board[0]["sealed"], "seal should mark enemy hero")


func _test_draw() -> void:
	var deck: Array[int] = [100]
	_battle._player_deck = deck
	var instance_id := _set_hand_card(9)
	_battle._play_function_card(instance_id, -1, _no_target_rects())
	_assert(_battle._player_hand.size() == 1, "draw card should replace itself")
	_assert(_battle._player_hand[0]["card_id"] == 100, "draw should use player deck")


func _test_pierce_attack() -> void:
	_battle._battle_over = false
	_battle._enemy_hp = 99
	_battle._player_board = [
		_battle._create_hero_state(100, true),
		null,
		null,
	]
	_battle._enemy_board = [
		_battle._create_hero_state(100, false),
		null,
		null,
	]
	_battle._player_board[0]["pierce"] = true
	var target_hp: int = _battle._enemy_board[0]["current_hp"]
	await _battle._resolve_attack_phase(true)
	_assert(_battle._enemy_hp == 98, "pierce should damage enemy body")
	_assert(
		_battle._enemy_board[0]["current_hp"] == target_hp,
		"pierce must not damage opposing hero"
	)
	_assert(not _battle._player_board[0]["pierce"], "pierce should clear after attack")


func _test_combo_attack() -> void:
	_battle._battle_over = false
	_battle._enemy_hp = 99
	_battle._player_board = [
		_battle._create_hero_state(100, true),
		null,
		null,
	]
	_battle._enemy_board = [
		_battle._create_hero_state(100, false),
		null,
		null,
	]
	_battle._player_board[0]["extra_attacks"] = 1
	await _battle._resolve_attack_phase(true)
	_assert(
		_battle._enemy_board[0]["current_hp"] == 1,
		"combo should resolve two consecutive attacks in one slot"
	)
	_assert(
		_battle._player_board[0]["extra_attacks"] == 0,
		"combo should clear after player attack phase"
	)


func _test_seal_skip() -> void:
	_battle._battle_over = false
	_battle._player_hp = 20
	_battle._enemy_board = [
		_battle._create_hero_state(100, false),
		null,
		null,
	]
	_battle._player_board = [null, null, null]
	_battle._enemy_board[0]["sealed"] = true
	await _battle._resolve_attack_phase(false)
	_assert(_battle._player_hp == 20, "sealed hero must skip its attack")
	_assert(not _battle._enemy_board[0]["sealed"], "seal should clear after skipped attack")


func _play_on_slot(card_id: int, slot_index: int) -> void:
	var instance_id := _set_hand_card(card_id)
	_battle._play_function_card(instance_id, slot_index, _no_target_rects())
	_assert(_battle._player_hand.is_empty(), "card %d should be consumed" % card_id)


func _set_hand_card(card_id: int) -> int:
	_instance_id += 1
	var hand: Array[Dictionary] = [{
		"instance_id": _instance_id,
		"card_id": card_id,
	}]
	_battle._player_hand = hand
	_battle._player_energy = 99
	return _instance_id


func _no_target_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	return rects


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FUNCTION_CARD_SMOKE_FAILED: %s" % message)
	get_tree().quit(1)
