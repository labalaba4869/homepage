extends Control

const GameDataLoader = preload("res://scripts/game_data.gd")
const CardViewScene = preload("res://scripts/card_view.gd")

const SLOT_COUNT := 3
const OPENING_HAND_SIZE := 5
const HAND_LIMIT := 10
const HAND_CARD_SIZE := Vector2(104, 147)
const SLOT_CARD_SIZE := Vector2(126, 178)
const WORLD_SCENE := "res://scenes/world.tscn"

var _rng := RandomNumberGenerator.new()
var _cards := {}
var _qualities := {}
var _decks := {}
var _actors := {}
var _enemies := {}
var _player_data := {}
var _enemy_data := {}

var _player_hp := 0
var _enemy_hp := 0
var _player_energy := 0
var _enemy_energy := 0
var _player_turn_number := 0
var _enemy_turn_number := 0
var _player_deck: Array[int] = []
var _enemy_deck: Array[int] = []
var _player_hand: Array[Dictionary] = []
var _enemy_hand: Array[Dictionary] = []
var _player_board: Array = [null, null, null]
var _enemy_board: Array = [null, null, null]
var _next_instance_id := 1
var _selected_instance_id := -1
var _pending_overwrite_slot := -1
var _is_player_turn := true
var _phase := "setup"
var _battle_over := false

var _enemy_name_label: Label
var _enemy_hp_label: Label
var _enemy_hp_bar: ProgressBar
var _enemy_portrait: TextureRect
var _player_name_label: Label
var _player_hp_label: Label
var _player_hp_bar: ProgressBar
var _player_portrait: TextureRect
var _turn_label: Label
var _energy_label: Label
var _deck_label: Label
var _event_label: Label
var _log_label: RichTextLabel
var _hand_container: HBoxContainer
var _hand_scroll: ScrollContainer
var _end_turn_button: Button
var _retreat_button: Button
var _player_slot_buttons: Array[Button] = []
var _enemy_slot_buttons: Array[Button] = []
var _overwrite_overlay: ColorRect
var _overwrite_label: Label
var _result_overlay: ColorRect
var _result_title: Label
var _result_message: Label
var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _log_lines: Array[String] = []


func _ready() -> void:
	_rng.randomize()
	_build_interface()
	if not _load_tables_and_context():
		_show_fatal_error("无法读取战斗表格，请先运行打表工具。")
		return
	_setup_battle()


func _load_tables_and_context() -> bool:
	_cards = GameDataLoader.load_cards()
	_qualities = GameDataLoader.load_qualities()
	_decks = GameDataLoader.load_decks()
	_actors = GameDataLoader.load_actors()
	_enemies = GameDataLoader.load_enemies()

	var enemy_id := GameSession.current_enemy_id
	if enemy_id < 0:
		enemy_id = 1
	if not _actors.has(0) or not _enemies.has(enemy_id):
		push_error("Missing player or enemy row for battle.")
		return false

	_player_data = _actors[0]
	_enemy_data = _enemies[enemy_id]
	var player_deck_id := int(_player_data.get("deck_id", -1))
	var enemy_deck_id := int(_enemy_data.get("deck_id", -1))
	if not _decks.has(player_deck_id) or not _decks.has(enemy_deck_id):
		push_error("Missing deck row for battle.")
		return false

	_player_deck = _make_deck(_decks[player_deck_id])
	_enemy_deck = _make_deck(_decks[enemy_deck_id])
	return not _player_deck.is_empty() and not _enemy_deck.is_empty()


func _make_deck(deck_record: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for card_id in deck_record.get("card_type", []):
		var parsed_id := int(card_id)
		if _cards.has(parsed_id):
			result.append(parsed_id)
	result.shuffle()
	return result


func _setup_battle() -> void:
	_player_hp = int(_player_data.get("max_hp", 1))
	_enemy_hp = int(_enemy_data.get("max_hp", 1))
	_set_actor_panels()
	for draw_index in OPENING_HAND_SIZE:
		_draw_card(true, false)
		_draw_card(false, false)
	_write_log("遭遇 %s。双方各抽取 5 张起始手牌。" % _enemy_data["name"])
	_refresh_all()
	_start_player_turn()
	_start_music()


func _start_player_turn() -> void:
	if _battle_over:
		return
	_is_player_turn = true
	_player_turn_number += 1
	_phase = "player_input"
	_selected_instance_id = -1
	if _player_turn_number == 1:
		_player_energy = int(_player_data.get("initial_energy", 6))
	else:
		_player_energy = _rng.randi_range(1, 10)
		_draw_card(true)
	_event_label.text = "你的回合"
	_write_log("你的第 %d 回合：获得 %d 点能量。" % [
		_player_turn_number,
		_player_energy,
	])
	_refresh_all()


func _start_enemy_turn() -> void:
	if _battle_over:
		return
	_is_player_turn = false
	_enemy_turn_number += 1
	_phase = "enemy_input"
	if _enemy_turn_number == 1:
		_enemy_energy = int(_enemy_data.get("initial_energy", 6))
	else:
		_enemy_energy = _rng.randi_range(1, 10)
		_draw_card(false)
	_event_label.text = "敌方回合"
	_write_log("%s 获得 %d 点能量。" % [
		_enemy_data["name"],
		_enemy_energy,
	])
	_refresh_all()
	await _enemy_play_cards()
	if _battle_over:
		return
	await _resolve_attack_phase(false)
	if _battle_over:
		return
	await _resolve_end_of_turn_statuses(false)
	if _battle_over:
		return
	_enemy_energy = 0
	_start_player_turn()


func _draw_card(for_player: bool, announce := true) -> bool:
	var hand := _player_hand if for_player else _enemy_hand
	var deck := _player_deck if for_player else _enemy_deck
	var owner_name := "你" if for_player else str(_enemy_data.get("name", "敌方"))
	if hand.size() >= HAND_LIMIT:
		if announce:
			_write_log("%s的手牌已达到 10 张，本回合跳过抽牌。" % owner_name)
		return false
	if deck.is_empty():
		if announce:
			_write_log("%s的牌库已空。" % owner_name)
		return false

	var card_id: int = int(deck.pop_back())
	hand.append({
		"instance_id": _next_instance_id,
		"card_id": card_id,
	})
	_next_instance_id += 1
	if announce:
		_write_log("%s抽取了 1 张卡。" % owner_name)
	return true


func _on_hand_card_pressed(instance_id: int) -> void:
	if not _is_player_turn or _phase != "player_input":
		return
	_selected_instance_id = (
		-1 if _selected_instance_id == instance_id else instance_id
	)
	if _selected_instance_id >= 0:
		var hand_index := _find_hand_index(_player_hand, instance_id)
		if hand_index >= 0:
			var card: Dictionary = _cards[
				int(_player_hand[hand_index]["card_id"])
			]
			_event_label.text = "已选择：%s" % card["card_name"]
	else:
		_event_label.text = "你的回合"
	_refresh_hand()


func _on_player_slot_pressed(slot_index: int) -> void:
	if (
		not _is_player_turn
		or _phase != "player_input"
		or _selected_instance_id < 0
	):
		return
	var hand_index := _find_hand_index(
		_player_hand,
		_selected_instance_id
	)
	if hand_index < 0:
		return
	var card: Dictionary = _cards[
		int(_player_hand[hand_index]["card_id"])
	]
	if int(card.get("cost", 0)) > _player_energy:
		_write_log("能量不足，无法使用 %s。" % card["card_name"])
		return
	if str(card.get("card_type", "")) != "battle_hero":
		_write_log("当前战斗原型暂不支持功能卡。")
		return

	if _player_board[slot_index] != null:
		_pending_overwrite_slot = slot_index
		_overwrite_label.text = (
			"%d号槽已有 %s。\n覆盖后旧英雄将立即死亡且本局不再返回牌库。"
			% [
				slot_index + 1,
				_cards[int(_player_board[slot_index]["card_id"])]["card_name"],
			]
		)
		_overwrite_overlay.show()
		_phase = "confirm_overwrite"
		_refresh_hand()
		return

	_play_player_card(slot_index)


func _play_player_card(slot_index: int) -> void:
	var hand_index := _find_hand_index(
		_player_hand,
		_selected_instance_id
	)
	if hand_index < 0:
		return
	var hand_card: Dictionary = _player_hand[hand_index]
	var card: Dictionary = _cards[int(hand_card["card_id"])]
	var cost := int(card.get("cost", 0))
	if cost > _player_energy:
		return

	_player_energy -= cost
	_player_hand.remove_at(hand_index)
	_player_board[slot_index] = _create_hero_state(int(card["card_id"]))
	_write_log("你将 %s 放入 %d号槽，消耗 %d 点能量。" % [
		card["card_name"],
		slot_index + 1,
		cost,
	])
	_selected_instance_id = -1
	_event_label.text = "你的回合"
	_play_sfx("menu_select")
	_refresh_all()


func _confirm_overwrite() -> void:
	var slot_index := _pending_overwrite_slot
	_pending_overwrite_slot = -1
	_overwrite_overlay.hide()
	_phase = "player_input"
	if slot_index < 0:
		return
	_player_board[slot_index] = null
	_play_player_card(slot_index)


func _cancel_overwrite() -> void:
	_pending_overwrite_slot = -1
	_overwrite_overlay.hide()
	_phase = "player_input"
	_refresh_all()


func _on_end_turn_pressed() -> void:
	if not _is_player_turn or _phase != "player_input" or _battle_over:
		return
	_selected_instance_id = -1
	_phase = "resolving"
	_player_energy = 0
	_event_label.text = "英雄依次攻击"
	_refresh_all()
	await _resolve_attack_phase(true)
	if _battle_over:
		return
	await _resolve_end_of_turn_statuses(true)
	if _battle_over:
		return
	await _start_enemy_turn()


func _enemy_play_cards() -> void:
	for slot_index in SLOT_COUNT:
		if _enemy_board[slot_index] != null:
			continue
		var hand_index := _choose_enemy_card()
		if hand_index < 0:
			continue
		var hand_card: Dictionary = _enemy_hand[hand_index]
		var card: Dictionary = _cards[int(hand_card["card_id"])]
		var cost := int(card.get("cost", 0))
		_enemy_energy -= cost
		_enemy_hand.remove_at(hand_index)
		_enemy_board[slot_index] = _create_hero_state(int(card["card_id"]))
		_write_log("%s将 %s 放入 %d号槽。" % [
			_enemy_data["name"],
			card["card_name"],
			slot_index + 1,
		])
		_play_sfx("menu_select")
		_refresh_all()
		await get_tree().create_timer(0.28).timeout


func _choose_enemy_card() -> int:
	var best_index := -1
	var best_cost := -1
	for index in _enemy_hand.size():
		var card: Dictionary = _cards[
			int(_enemy_hand[index]["card_id"])
		]
		if str(card.get("card_type", "")) != "battle_hero":
			continue
		var cost := int(card.get("cost", 0))
		if cost <= _enemy_energy and cost > best_cost:
			best_index = index
			best_cost = cost
	return best_index


func _resolve_attack_phase(player_attacking: bool) -> void:
	var attackers := _player_board if player_attacking else _enemy_board
	var defenders := _enemy_board if player_attacking else _player_board
	var attacker_name := "我方" if player_attacking else "敌方"

	for slot_index in SLOT_COUNT:
		if _battle_over:
			return
		var hero: Variant = attackers[slot_index]
		if hero == null:
			continue
		var card: Dictionary = _cards[int(hero["card_id"])]

		if bool(hero.get("frozen", false)):
			_write_log("%s%d号槽的 %s 已冻结，本回合无法攻击。" % [
				attacker_name,
				slot_index + 1,
				card["card_name"],
			])
			await get_tree().create_timer(0.24).timeout
			continue
		if (
			bool(hero.get("paralyzed", false))
			and _rng.randf() < 0.5
		):
			_write_log("%s%d号槽的 %s 因麻痹攻击失败。" % [
				attacker_name,
				slot_index + 1,
				card["card_name"],
			])
			await get_tree().create_timer(0.24).timeout
			continue

		await _animate_attack(player_attacking, slot_index)
		var damage := int(card.get("card_attack", 0))
		var target: Variant = defenders[slot_index]
		if target == null:
			if player_attacking:
				_enemy_hp = maxi(0, _enemy_hp - damage)
				_write_log("%s越过空槽，对敌人造成 %d 点伤害。" % [
					card["card_name"],
					damage,
				])
			else:
				_player_hp = maxi(0, _player_hp - damage)
				_write_log("%s越过空槽，对你造成 %d 点伤害。" % [
					card["card_name"],
					damage,
				])
			_play_sfx("hurt")
		else:
			var target_card: Dictionary = _cards[int(target["card_id"])]
			var damage_result := _damage_hero(target, damage)
			_write_log("%s攻击 %s：护盾抵挡 %d，生命损失 %d。" % [
				card["card_name"],
				target_card["card_name"],
				damage_result["blocked"],
				damage_result["health_damage"],
			])
			_play_sfx("hit")
			if int(target["current_hp"]) <= 0:
				_write_log("%s 被击败并移出本局。" % target_card["card_name"])
				defenders[slot_index] = null
				_play_sfx("enemy_die")
			else:
				_apply_target_attack_effect(card, target)

		_apply_self_attack_effect(card, hero, player_attacking)
		_refresh_all()
		if _check_battle_end():
			return
		await get_tree().create_timer(0.22).timeout


func _resolve_end_of_turn_statuses(for_player: bool) -> void:
	var board := _player_board if for_player else _enemy_board
	var owner_name := "我方" if for_player else "敌方"
	for slot_index in SLOT_COUNT:
		var hero: Variant = board[slot_index]
		if hero == null:
			continue
		var card: Dictionary = _cards[int(hero["card_id"])]
		var burn_stacks := int(hero.get("burn", 0))
		if burn_stacks > 0:
			var result := _damage_hero(hero, burn_stacks)
			hero["burn"] = maxi(0, burn_stacks - 1)
			_write_log("%s%d号槽的 %s 受到 %d 点燃烧伤害。" % [
				owner_name,
				slot_index + 1,
				card["card_name"],
				result["health_damage"],
			])
			if int(hero["current_hp"]) <= 0:
				_write_log("%s 被燃烧击败并移出本局。" % card["card_name"])
				board[slot_index] = null
				_play_sfx("enemy_die")
		if board[slot_index] != null:
			board[slot_index]["frozen"] = false
		_refresh_all()
		await get_tree().create_timer(0.18).timeout
		if _check_battle_end():
			return


func _apply_target_attack_effect(
	attacker_card: Dictionary,
	target: Dictionary
) -> void:
	var card_id := int(attacker_card["card_id"])
	var params := _card_params(attacker_card)
	match card_id:
		200:
			if _roll_percent(_param(params, 0, 50)):
				var amount := _param(params, 1, 1)
				target["burn"] = int(target.get("burn", 0)) + amount
				_write_log("火史莱姆施加了 %d 层燃烧。" % amount)
		201:
			if _roll_percent(_param(params, 0, 50)):
				var amount := _param(params, 1, 1)
				target["frost"] = int(target.get("frost", 0)) + amount
				_write_log("冰史莱姆施加了 %d 层冰寒。" % amount)
				if int(target["frost"]) >= 3:
					target["frost"] = 0
					target["frozen"] = true
					_write_log("冰寒达到 3 层，目标本回合被冻结。")
		202:
			if _roll_percent(_param(params, 0, 20)):
				target["paralyzed"] = true
				_write_log("电史莱姆使目标陷入麻痹。")


func _apply_self_attack_effect(
	card: Dictionary,
	hero: Dictionary,
	for_player: bool
) -> void:
	var card_id := int(card["card_id"])
	var params := _card_params(card)
	match card_id:
		203:
			if _roll_percent(_param(params, 0, 30)):
				var amount := _param(params, 1, 1)
				var old_hp := int(hero["current_hp"])
				hero["current_hp"] = mini(
					int(card["card_maxhp"]),
					old_hp + amount
				)
				_write_log("草史莱姆恢复了 %d 点生命。" % (
					int(hero["current_hp"]) - old_hp
				))
		204:
			if _roll_percent(_param(params, 0, 50)):
				var amount := _param(params, 1, 1)
				hero["shield"] = int(hero.get("shield", 0)) + amount
				_write_log("岩史莱姆获得了 %d 点护盾。" % amount)
		205:
			var draw_count := _param(params, 0, 1)
			for draw_index in draw_count:
				_draw_card(for_player)


func _damage_hero(hero: Dictionary, damage: int) -> Dictionary:
	var shield := int(hero.get("shield", 0))
	var blocked := mini(shield, damage)
	var health_damage := maxi(0, damage - blocked)
	hero["shield"] = shield - blocked
	hero["current_hp"] = maxi(
		0,
		int(hero.get("current_hp", 0)) - health_damage
	)
	return {
		"blocked": blocked,
		"health_damage": health_damage,
	}


func _create_hero_state(card_id: int) -> Dictionary:
	var card: Dictionary = _cards[card_id]
	return {
		"card_id": card_id,
		"current_hp": int(card.get("card_maxhp", 1)),
		"shield": 0,
		"burn": 0,
		"frost": 0,
		"paralyzed": false,
		"frozen": false,
	}


func _card_params(card: Dictionary) -> Array:
	var params: Variant = card.get("description_params", [])
	return params if params is Array else []


func _param(params: Array, index: int, fallback: int) -> int:
	return int(params[index]) if index < params.size() else fallback


func _roll_percent(chance: int) -> bool:
	return _rng.randi_range(1, 100) <= chance


func _find_hand_index(hand: Array[Dictionary], instance_id: int) -> int:
	for index in hand.size():
		if int(hand[index]["instance_id"]) == instance_id:
			return index
	return -1


func _check_battle_end() -> bool:
	if _enemy_hp <= 0:
		_end_battle("victory")
		return true
	if _player_hp <= 0:
		_end_battle("defeat")
		return true
	return false


func _end_battle(result: String) -> void:
	if _battle_over:
		return
	_battle_over = true
	_phase = "ended"
	_selected_instance_id = -1
	GameSession.finish_battle(result)
	if result == "victory":
		_result_title.text = "战斗胜利"
		_result_message.text = "%s 已被击败，返回世界后将从场景中移除。" % (
			_enemy_data["name"]
		)
	else:
		_result_title.text = "战斗失败"
		_result_message.text = "你已被迫返回起点，下一场战斗会重新构建牌库。"
	_result_overlay.show()
	_refresh_all()


func _on_retreat_pressed() -> void:
	if _battle_over:
		return
	_battle_over = true
	_phase = "ended"
	GameSession.finish_battle("retreat")
	get_tree().change_scene_to_file(WORLD_SCENE)


func _return_to_world() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _refresh_all() -> void:
	_refresh_actor_stats()
	_refresh_board()
	_refresh_hand()
	_turn_label.text = (
		"玩家回合" if _is_player_turn else "%s的回合" % _enemy_data.get(
			"name",
			"敌方"
		)
	)
	_energy_label.text = "当前能量  %d" % (
		_player_energy if _is_player_turn else _enemy_energy
	)
	_deck_label.text = "我方牌库 %d / 手牌 %d    敌方牌库 %d / 手牌 %d" % [
		_player_deck.size(),
		_player_hand.size(),
		_enemy_deck.size(),
		_enemy_hand.size(),
	]
	_end_turn_button.disabled = (
		not _is_player_turn
		or _phase != "player_input"
		or _battle_over
	)
	_retreat_button.disabled = _battle_over


func _refresh_actor_stats() -> void:
	_player_hp_label.text = "%d / %d" % [
		_player_hp,
		int(_player_data.get("max_hp", 1)),
	]
	_enemy_hp_label.text = "%d / %d" % [
		_enemy_hp,
		int(_enemy_data.get("max_hp", 1)),
	]
	_player_hp_bar.value = _player_hp
	_enemy_hp_bar.value = _enemy_hp


func _refresh_board() -> void:
	for slot_index in SLOT_COUNT:
		_render_slot(
			_player_slot_buttons[slot_index],
			_player_board[slot_index],
			slot_index,
			true
		)
		_render_slot(
			_enemy_slot_buttons[slot_index],
			_enemy_board[slot_index],
			slot_index,
			false
		)


func _render_slot(
	button: Button,
	hero: Variant,
	slot_index: int,
	is_player_slot: bool
) -> void:
	for child in button.get_children():
		button.remove_child(child)
		child.queue_free()

	if hero == null:
		var empty_label := Label.new()
		empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty_label.text = "%d号槽\n空" % (slot_index + 1)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override(
			"font_color",
			Color("82958c") if is_player_slot else Color("9b8787")
		)
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(empty_label)
		return

	var card_id := int(hero["card_id"])
	var card_view = CardViewScene.new()
	button.add_child(card_view)
	card_view.configure(_cards[card_id], SLOT_CARD_SIZE, hero)
	card_view.position = Vector2(5, 5)
	card_view.set_as_slot_content()


func _refresh_hand() -> void:
	for child in _hand_container.get_children():
		_hand_container.remove_child(child)
		child.queue_free()

	for hand_card in _player_hand:
		var card_id := int(hand_card["card_id"])
		var card: Dictionary = _cards[card_id]
		var card_view = CardViewScene.new()
		_hand_container.add_child(card_view)
		card_view.configure(card, HAND_CARD_SIZE)
		var instance_id := int(hand_card["instance_id"])
		var can_play := (
			_is_player_turn
			and _phase == "player_input"
			and not _battle_over
			and str(card.get("card_type", "")) == "battle_hero"
			and int(card.get("cost", 0)) <= _player_energy
		)
		card_view.set_interactable(can_play)
		card_view.set_selected_state(instance_id == _selected_instance_id)
		card_view.pressed.connect(
			_on_hand_card_pressed.bind(instance_id)
		)


func _animate_attack(player_attacking: bool, slot_index: int) -> void:
	var buttons := (
		_player_slot_buttons if player_attacking else _enemy_slot_buttons
	)
	var button := buttons[slot_index]
	var card_view := button.get_node_or_null("BattleCardView")
	if card_view == null:
		card_view = button.get_child(0) if button.get_child_count() > 0 else null
	if card_view == null:
		return
	var original_position: Vector2 = card_view.position
	var direction := Vector2(0, -14 if player_attacking else 14)
	var tween := create_tween()
	tween.tween_property(card_view, "position", original_position + direction, 0.11)
	tween.tween_property(card_view, "position", original_position, 0.12)
	_play_sfx("swipe")
	await tween.finished


func _write_log(message: String) -> void:
	_log_lines.append(message)
	while _log_lines.size() > 12:
		_log_lines.pop_front()
	if _log_label:
		_log_label.text = "\n".join(_log_lines)
		_log_label.scroll_to_line(maxi(0, _log_lines.size() - 1))


func _build_interface() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load(
		"res://assets/art/scene/world/grass_background.png"
	)
	background.stretch_mode = TextureRect.STRETCH_TILE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.modulate = Color("78947f")
	add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.055, 0.048, 0.74)
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 14)
	margin.add_child(main_row)

	var left_panel := _make_panel(Color(0.035, 0.075, 0.07, 0.94))
	left_panel.custom_minimum_size = Vector2(214, 0)
	main_row.add_child(left_panel)
	var left_content := VBoxContainer.new()
	left_content.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_content)
	_build_actor_panel(left_content, true)
	var left_spacer := Control.new()
	left_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_content.add_child(left_spacer)
	_build_actor_panel(left_content, false)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 5)
	main_row.add_child(center)

	var enemy_header := _make_heading("敌方英雄槽", 16, Color("f0b7a9"))
	center.add_child(enemy_header)
	var enemy_slots := HBoxContainer.new()
	enemy_slots.custom_minimum_size = Vector2(0, 187)
	enemy_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_slots.add_theme_constant_override("separation", 12)
	center.add_child(enemy_slots)
	for index in SLOT_COUNT:
		var enemy_slot := _make_slot_button(false, index)
		enemy_slots.add_child(enemy_slot)
		_enemy_slot_buttons.append(enemy_slot)

	var event_panel := _make_panel(Color(0.07, 0.105, 0.09, 0.96))
	event_panel.custom_minimum_size = Vector2(0, 55)
	center.add_child(event_panel)
	_event_label = _make_heading("准备战斗", 19, Color("f4d68a"))
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_panel.add_child(_event_label)

	var player_header := _make_heading("我方英雄槽", 16, Color("a9d9c5"))
	center.add_child(player_header)
	var player_slots := HBoxContainer.new()
	player_slots.custom_minimum_size = Vector2(0, 187)
	player_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	player_slots.add_theme_constant_override("separation", 12)
	center.add_child(player_slots)
	for index in SLOT_COUNT:
		var player_slot := _make_slot_button(true, index)
		player_slot.pressed.connect(_on_player_slot_pressed.bind(index))
		player_slots.add_child(player_slot)
		_player_slot_buttons.append(player_slot)

	var hand_header_row := HBoxContainer.new()
	center.add_child(hand_header_row)
	var hand_header := _make_heading("手牌", 16, Color("f1e4bd"))
	hand_header_row.add_child(hand_header)
	var hand_hint := Label.new()
	hand_hint.text = "点击卡牌高亮，再点击我方槽位上场"
	hand_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hand_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_hint.add_theme_color_override("font_color", Color("aebbb4"))
	hand_header_row.add_child(hand_hint)

	_hand_scroll = ScrollContainer.new()
	_hand_scroll.custom_minimum_size = Vector2(0, 158)
	_hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(_hand_scroll)
	_hand_container = HBoxContainer.new()
	_hand_container.add_theme_constant_override("separation", 8)
	_hand_scroll.add_child(_hand_container)

	var right_panel := _make_panel(Color(0.04, 0.07, 0.075, 0.95))
	right_panel.custom_minimum_size = Vector2(260, 0)
	main_row.add_child(right_panel)
	var right_content := VBoxContainer.new()
	right_content.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_content)

	right_content.add_child(_make_heading(
		"回合控制",
		22,
		Color("f4d68a")
	))
	_turn_label = _make_heading("玩家回合", 18, Color("d6eee2"))
	right_content.add_child(_turn_label)
	_energy_label = _make_heading("当前能量  0", 22, Color("79c9ff"))
	right_content.add_child(_energy_label)
	_deck_label = Label.new()
	_deck_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deck_label.add_theme_color_override("font_color", Color("b7c5c0"))
	right_content.add_child(_deck_label)

	var log_title := _make_heading("战斗记录", 15, Color("d3d9d6"))
	right_content.add_child(log_title)
	_log_label = RichTextLabel.new()
	_log_label.custom_minimum_size = Vector2(0, 235)
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.fit_content = false
	_log_label.scroll_active = true
	_log_label.add_theme_font_size_override("normal_font_size", 13)
	_log_label.add_theme_color_override("default_color", Color("c9d3cf"))
	right_content.add_child(_log_label)

	_end_turn_button = _make_command_button(
		"结束回合",
		Color("3d8d6b"),
		"我方英雄将按 1、2、3 号槽从左到右依次攻击"
	)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	right_content.add_child(_end_turn_button)
	_retreat_button = _make_command_button(
		"撤退",
		Color("8f5148"),
		"无代价返回世界，2 秒内不会再次触发该怪物"
	)
	_retreat_button.pressed.connect(_on_retreat_pressed)
	right_content.add_child(_retreat_button)

	_build_overwrite_modal()
	_build_result_modal()
	_build_audio()


func _build_actor_panel(parent: VBoxContainer, enemy: bool) -> void:
	var title := _make_heading(
		"遭遇目标" if enemy else "玩家",
		14,
		Color("d9c99d")
	)
	parent.add_child(title)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(104, 86)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(portrait)
	var name_label := _make_heading("读取中", 20, Color("f2f0e6"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(name_label)
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 18)
	hp_bar.show_percentage = false
	parent.add_child(hp_bar)
	var hp_label := _make_heading("0 / 0", 15, Color("ffb8aa"))
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(hp_label)
	if enemy:
		_enemy_portrait = portrait
		_enemy_name_label = name_label
		_enemy_hp_bar = hp_bar
		_enemy_hp_label = hp_label
	else:
		_player_portrait = portrait
		_player_name_label = name_label
		_player_hp_bar = hp_bar
		_player_hp_label = hp_label


func _set_actor_panels() -> void:
	_player_name_label.text = str(_player_data["name"])
	_enemy_name_label.text = str(_enemy_data["name"])
	_player_hp_bar.max_value = int(_player_data["max_hp"])
	_enemy_hp_bar.max_value = int(_enemy_data["max_hp"])
	_player_portrait.texture = _atlas_texture(
		load("res://assets/art/character/player/player.png"),
		Rect2(1152, 0, 64, 64)
	)
	_enemy_portrait.texture = _enemy_portrait_texture(
		str(_enemy_data.get("resource_type", "bat"))
	)


func _enemy_portrait_texture(resource_type: String) -> AtlasTexture:
	var texture_path := (
		"res://assets/art/character/animals/%s.png" % resource_type
	)
	var frame_size := Vector2i(16, 16)
	if resource_type == "bat":
		frame_size = Vector2i(16, 24)
	elif resource_type.contains("cow"):
		frame_size = Vector2i(32, 32)
	return _atlas_texture(
		load(texture_path),
		Rect2(Vector2.ZERO, Vector2(frame_size))
	)


func _atlas_texture(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas


func _make_slot_button(player_slot: bool, slot_index: int) -> Button:
	var button := Button.new()
	button.name = (
		"PlayerSlot%d" % (slot_index + 1)
		if player_slot
		else "EnemySlot%d" % (slot_index + 1)
	)
	button.custom_minimum_size = Vector2(136, 187)
	button.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.04, 0.04, 0.62)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = (
		Color("5fa684") if player_slot else Color("a36a65")
	)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.border_color = Color("f3d47b")
	hover.bg_color = Color(0.08, 0.11, 0.09, 0.78)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button


func _make_panel(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.45, 0.58, 0.51, 0.55)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_heading(text_value: String, size_value: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	return label


func _make_command_button(
	text_value: String,
	color: Color,
	tooltip: String
) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 48)
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.12)
	button.add_theme_stylebox_override("pressed", pressed)
	return button


func _build_overwrite_modal() -> void:
	_overwrite_overlay = ColorRect.new()
	_overwrite_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overwrite_overlay.color = Color(0, 0, 0, 0.72)
	_overwrite_overlay.hide()
	add_child(_overwrite_overlay)
	var panel := _make_panel(Color("17221f"))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220, -100)
	panel.size = Vector2(440, 200)
	_overwrite_overlay.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	content.add_child(_make_heading("确认覆盖英雄", 22, Color("f4d68a")))
	_overwrite_label = Label.new()
	_overwrite_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overwrite_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overwrite_label.add_theme_font_size_override("font_size", 15)
	content.add_child(_overwrite_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(buttons)
	var cancel := _make_command_button("取消", Color("52625c"), "")
	cancel.custom_minimum_size = Vector2(110, 42)
	cancel.pressed.connect(_cancel_overwrite)
	buttons.add_child(cancel)
	var confirm := _make_command_button("确认覆盖", Color("9b5e45"), "")
	confirm.custom_minimum_size = Vector2(130, 42)
	confirm.pressed.connect(_confirm_overwrite)
	buttons.add_child(confirm)


func _build_result_modal() -> void:
	_result_overlay = ColorRect.new()
	_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.color = Color(0, 0, 0, 0.76)
	_result_overlay.hide()
	add_child(_result_overlay)
	var panel := _make_panel(Color("14251f"))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-230, -125)
	panel.size = Vector2(460, 250)
	_result_overlay.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	_result_title = _make_heading("战斗结束", 30, Color("f4d68a"))
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_result_title)
	_result_message = Label.new()
	_result_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_message.add_theme_font_size_override("font_size", 16)
	content.add_child(_result_message)
	var return_button := _make_command_button(
		"返回世界",
		Color("3d8d6b"),
		""
	)
	return_button.pressed.connect(_return_to_world)
	content.add_child(return_button)


func _build_audio() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -18.0
	add_child(_music_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = -7.0
	add_child(_sfx_player)


func _start_music() -> void:
	var music := load("res://assets/art/music_and_sounds/music.mp3")
	if music:
		_music_player.stream = music
		_music_player.play()


func _play_sfx(sound_name: String) -> void:
	var path := (
		"res://assets/art/music_and_sounds/%s.wav" % sound_name
	)
	if ResourceLoader.exists(path):
		_sfx_player.stream = load(path)
		_sfx_player.play()


func _show_fatal_error(message: String) -> void:
	_battle_over = true
	_result_title.text = "战斗数据错误"
	_result_message.text = message
	_result_overlay.show()
