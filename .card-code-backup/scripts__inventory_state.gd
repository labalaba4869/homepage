extends Node

signal inventory_changed
signal container_changed(container_instance_id: String)
signal active_bindings_changed
signal search_effects_changed

const GameDataScript = preload("res://scripts/game_data.gd")
const ACTIVE_SLOT_COUNT := 3

var items: Dictionary = {}
var item_qualities: Dictionary = {}
var loot_groups: Dictionary = {}
var cards: Dictionary = {}

var inventory_slots: Array = []
var inventory_capacity := 20
var max_carry_weight := 30.0
var active_bindings: Array = []
var owned_cards: Array[int] = []
var deck_cards: Array[int] = []
var player_coins := 0
var pending_quality_upgrade_percent := 0
var pending_card_chance_boost_percent := 0
var pending_guaranteed_card := false
var pending_force_filled_slots := false

var _containers: Dictionary = {}
var _initialized := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return

	items = _build_unified_item_table()
	item_qualities = GameDataScript.load_item_qualities()
	loot_groups = GameDataScript.load_loot_groups()
	cards = GameDataScript.load_cards()

	var actors := GameDataScript.load_actors()
	var player_data: Dictionary = actors.get(0, {})
	inventory_capacity = maxi(int(player_data.get("inventory_slots", 20)), 1)
	max_carry_weight = maxf(
		float(player_data.get("max_carry_weight", 30.0)),
		0.0
	)
	inventory_slots.resize(inventory_capacity)
	inventory_slots.fill(null)
	active_bindings.resize(ACTIVE_SLOT_COUNT)
	active_bindings.fill(null)
	_initialized = true

	var initial_ids: Array = player_data.get("initial_item_ids", [])
	var initial_counts: Array = player_data.get("initial_item_counts", [])
	for index in mini(initial_ids.size(), initial_counts.size()):
		_add_stack_to_slots(
			inventory_slots,
			int(initial_ids[index]),
			int(initial_counts[index]),
			inventory_capacity
		)

	var decks := GameDataScript.load_decks()
	var deck_id := int(player_data.get("deck_id", -1))
	var deck_data: Dictionary = decks.get(deck_id, {})
	var configured_cards: Array = deck_data.get("card_type", [])
	for card_id in configured_cards:
		deck_cards.append(int(card_id))

	inventory_changed.emit()


func get_item(item_id: int) -> Dictionary:
	ensure_initialized()
	return items.get(item_id, {})


func get_card(card_id: int) -> Dictionary:
	ensure_initialized()
	return cards.get(card_id, {})


func get_loot_group(loot_group_id: int) -> Dictionary:
	ensure_initialized()
	return loot_groups.get(loot_group_id, {})


func get_item_quality(quality_id: int) -> Dictionary:
	ensure_initialized()
	return item_qualities.get(quality_id, {})


func get_item_frame_path(quality_id: int) -> String:
	return str(
		get_item_quality(quality_id).get(
			"frame_path",
			"res://assets/art/items/frames/item_frame_0_white.png"
		)
	)


func get_item_search_time(item_id: int) -> float:
	var item := get_item(item_id)
	var quality := int(item.get("item_equality", 0))
	return maxf(
		float(get_item_quality(quality).get("search_time", 0.5)),
		0.05
	)


func get_entry_search_time(entry: Variant) -> float:
	if entry == null:
		return maxf(
			float(get_item_quality(0).get("search_time", 0.5)),
			0.05
		)
	var quality := 0
	if str(entry.get("content_type", "item")) == "card":
		quality = int(
			get_card(int(entry.get("card_id", 0))).get(
				"card_equality",
				0
			)
		)
	else:
		quality = int(
			get_item(int(entry.get("item_id", 0))).get(
				"item_equality",
				0
			)
		)
	return maxf(
		float(get_item_quality(quality).get("search_time", 0.5)),
		0.05
	)


func reset_expedition() -> void:
	_containers.clear()
	pending_quality_upgrade_percent = 0
	pending_card_chance_boost_percent = 0
	pending_guaranteed_card = false
	pending_force_filled_slots = false
	search_effects_changed.emit()


func get_or_create_container(
	container_instance_id: String,
	loot_group_id: int
) -> Dictionary:
	ensure_initialized()
	if _containers.has(container_instance_id):
		return _containers[container_instance_id]

	var group: Dictionary = get_loot_group(loot_group_id)
	if group.is_empty():
		push_error("Unknown loot group: %d" % loot_group_id)
		return {}

	var slot_count := maxi(int(group.get("slot_count", 1)), 1)
	var slots: Array = []
	slots.resize(slot_count)
	slots.fill(null)
	_generate_container_contents(slots, group)

	var revealed: Array[bool] = []
	revealed.resize(slot_count)
	revealed.fill(false)
	var state := {
		"loot_group_id": loot_group_id,
		"slots": slots,
		"revealed": revealed,
		"current_index": 0,
		"current_slot_progress": 0.0,
		"completed": false,
	}
	_containers[container_instance_id] = state
	container_changed.emit(container_instance_id)
	return state


func get_container(container_instance_id: String) -> Dictionary:
	ensure_initialized()
	return _containers.get(container_instance_id, {})


func advance_search(container_instance_id: String, delta: float) -> void:
	var state := get_container(container_instance_id)
	if state.is_empty() or bool(state.get("completed", false)):
		return

	var slots: Array = state["slots"]
	var remaining_delta := maxf(delta, 0.0)
	var changed := false
	while remaining_delta > 0.0 and not bool(state["completed"]):
		var current_index := int(state["current_index"])
		if current_index >= slots.size():
			state["completed"] = true
			break

		var stack = slots[current_index]
		var duration := get_entry_search_time(stack)
		var needed := duration - float(state["current_slot_progress"])
		var consumed := minf(remaining_delta, needed)
		state["current_slot_progress"] = (
			float(state["current_slot_progress"]) + consumed
		)
		remaining_delta -= consumed

		if float(state["current_slot_progress"]) + 0.0001 < duration:
			break

		state["revealed"][current_index] = true
		state["current_index"] = current_index + 1
		state["current_slot_progress"] = 0.0
		changed = true
		if int(state["current_index"]) >= slots.size():
			state["completed"] = true

	if changed:
		container_changed.emit(container_instance_id)


func is_container_slot_revealed(
	container_instance_id: String,
	slot_index: int
) -> bool:
	var state := get_container(container_instance_id)
	if state.is_empty():
		return false
	var revealed: Array = state["revealed"]
	return (
		slot_index >= 0
		and slot_index < revealed.size()
		and bool(revealed[slot_index])
	)


func get_container_current_index(container_instance_id: String) -> int:
	var state := get_container(container_instance_id)
	return -1 if state.is_empty() else int(state.get("current_index", -1))


func transfer_container_to_inventory(
	container_instance_id: String,
	slot_index: int
) -> String:
	var state := get_container(container_instance_id)
	if state.is_empty():
		return "搜索容器不存在"

	var slots: Array = state["slots"]
	if slot_index < 0 or slot_index >= slots.size():
		return "物品格不存在"
	if not is_container_slot_revealed(container_instance_id, slot_index):
		return "该物品尚未搜索完成"

	var stack = slots[slot_index]
	if stack == null:
		return "该物品格为空"
	if str(stack.get("content_type", "item")) == "card":
		var card_id := int(stack.get("card_id", 0))
		if get_card(card_id).is_empty():
			return "卡牌配置不存在"
		owned_cards.append(card_id)
		slots[slot_index] = null
		_notify_inventory_changed()
		container_changed.emit(container_instance_id)
		return ""

	var item_id := int(stack["item_id"])
	var count := int(stack["count"])
	var added_weight := get_item_weight(item_id) * count
	if get_inventory_weight() + added_weight > max_carry_weight + 0.0001:
		return "背包已超出最大负重"
	if _inventory_available_space(item_id) < count:
		if is_active_item(item_id):
			return "该主动道具已达到最大携带数量"
		return "背包没有足够空间"

	_add_stack_to_slots(inventory_slots, item_id, count, inventory_capacity)
	slots[slot_index] = null
	_notify_inventory_changed()
	container_changed.emit(container_instance_id)
	return ""


func use_active_binding(slot_index: int) -> Dictionary:
	ensure_initialized()
	if slot_index < 0 or slot_index >= active_bindings.size():
		return _use_result(false, "主动道具栏不存在")
	var bound_item = active_bindings[slot_index]
	if bound_item == null:
		return _use_result(false, "该主动道具栏为空")

	var item_id := int(bound_item)
	var item := get_item(item_id)
	if item.is_empty() or not is_active_item(item_id):
		return _use_result(false, "主动道具配置不存在")
	if get_inventory_item_count(item_id) <= 0:
		_notify_inventory_changed()
		return _use_result(false, "背包中没有该主动道具")

	var raw_params: Variant = item.get("effect_params", [])
	var params: Array = raw_params if raw_params is Array else []
	var error := ""
	var detail := ""
	match item_id:
		10000, 10005, 10012, 10014:
			var percent := _effect_param(params, 0, 0)
			var healed := GameSession.heal_player_percent(percent)
			if healed <= 0:
				error = "生命值已满，未消耗道具"
			else:
				detail = "恢复 %d 点生命" % healed
		10001:
			var amount := _effect_param(params, 0, 1)
			error = GameSession.queue_next_battle_attack_bonus(amount)
			detail = "下一场战斗的我方英雄攻击 +%d" % amount
		10002, 10009:
			var percent := _effect_param(params, 0, 0)
			var duration := _effect_param(params, 1, 0)
			error = GameSession.queue_move_speed_buff(percent, duration)
			detail = "移动速度提高 %d%%，持续 %d 秒" % [
				percent,
				duration,
			]
		10003, 10010:
			var percent := _effect_param(params, 0, 0)
			error = _queue_quality_upgrade(percent)
			detail = "下一次搜索每格有 %d%% 概率提升品质" % percent
		10004, 10011:
			var percent := _effect_param(params, 0, 0)
			error = _queue_card_chance_boost(percent)
			detail = "下一次搜索的卡牌概率相对提高 %d%%" % percent
		10006:
			error = _queue_force_filled_slots()
			detail = "下一次搜索不会出现空格"
		10007:
			var amount := _effect_param(params, 0, 1)
			error = GameSession.queue_next_battle_energy_bonus(amount)
			detail = "下一场战斗从第二回合起每回合能量 +%d" % amount
		10008:
			error = GameSession.queue_instant_normal_kill()
			detail = "下一只遭遇的普通敌人将被直接击败"
		10013:
			error = _queue_guaranteed_card()
			detail = "下一次搜索至少出现一张卡牌"
		_:
			error = "该主动道具效果尚未实现"

	if not error.is_empty():
		return _use_result(false, error)
	_consume_inventory_item(item_id, 1)
	return _use_result(
		true,
		"已使用%s：%s" % [str(item.get("item_name", "主动道具")), detail]
	)


func transfer_inventory_to_container(
	inventory_index: int,
	container_instance_id: String
) -> String:
	if inventory_index < 0 or inventory_index >= inventory_slots.size():
		return "背包格不存在"

	var stack = inventory_slots[inventory_index]
	if stack == null:
		return "背包格为空"

	var state := get_container(container_instance_id)
	if state.is_empty():
		return "搜索容器不存在"

	var item_id := int(stack["item_id"])
	var count := int(stack["count"])
	if _container_available_space(state, item_id) < count:
		return "已搜索区域没有足够空间"

	_add_stack_to_revealed_slots(state, item_id, count)
	inventory_slots[inventory_index] = null
	_notify_inventory_changed()
	container_changed.emit(container_instance_id)
	return ""


func bind_active_item(slot_index: int, item_id: int) -> String:
	if slot_index < 0 or slot_index >= active_bindings.size():
		return "主动道具栏不存在"
	if not is_active_item(item_id):
		return "该物品不是主动道具"
	if get_inventory_item_count(item_id) <= 0:
		return "背包中没有该主动道具"

	if active_bindings[slot_index] == item_id:
		active_bindings[slot_index] = null
		active_bindings_changed.emit()
		return ""

	for index in active_bindings.size():
		if active_bindings[index] == item_id:
			active_bindings[index] = null
	active_bindings[slot_index] = item_id
	active_bindings_changed.emit()
	return ""


func clear_active_binding(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= active_bindings.size():
		return
	active_bindings[slot_index] = null
	active_bindings_changed.emit()


func get_inventory_item_count(item_id: int) -> int:
	ensure_initialized()
	var total := 0
	for stack in inventory_slots:
		if stack != null and int(stack["item_id"]) == item_id:
			total += int(stack["count"])
	return total


func is_active_item(item_id: int) -> bool:
	return bool(get_item(item_id).get("is_active", false))


func is_container_looted(container_instance_id: String) -> bool:
	var state := get_container(container_instance_id)
	if state.is_empty() or not bool(state.get("completed", false)):
		return false
	for stack in state["slots"]:
		if stack != null:
			return false
	return true


func get_inventory_weight() -> float:
	ensure_initialized()
	var total := 0.0
	for stack in inventory_slots:
		if stack != null:
			total += (
				get_item_weight(int(stack["item_id"]))
				* int(stack["count"])
			)
	return total


func get_inventory_used_slots() -> int:
	ensure_initialized()
	var used := 0
	for stack in inventory_slots:
		if stack != null:
			used += 1
	return used


func get_item_weight(item_id: int) -> float:
	return float(get_item(item_id).get("unit_weight", 0.0))


func get_stack_sell_value(stack: Variant) -> int:
	if stack == null:
		return 0
	var item := get_item(int(stack["item_id"]))
	return int(item.get("sell_price", 0)) * int(stack["count"])


func sell_inventory_stack(inventory_index: int, count := -1) -> int:
	if inventory_index < 0 or inventory_index >= inventory_slots.size():
		return 0
	var stack = inventory_slots[inventory_index]
	if stack == null:
		return 0
	var sell_count := int(stack["count"]) if count < 0 else mini(
		count,
		int(stack["count"])
	)
	if sell_count <= 0:
		return 0
	var earned := (
		int(get_item(int(stack["item_id"])).get("sell_price", 0))
		* sell_count
	)
	stack["count"] = int(stack["count"]) - sell_count
	if int(stack["count"]) <= 0:
		inventory_slots[inventory_index] = null
	player_coins += earned
	_notify_inventory_changed()
	return earned


func _build_unified_item_table() -> Dictionary:
	var unified := {}
	var normal_table := GameDataScript.load_items()
	for item_id in normal_table:
		var item: Dictionary = normal_table[item_id].duplicate(true)
		item["is_active"] = false
		unified[int(item_id)] = item

	var active_table := GameDataScript.load_active_items()
	for active_item_id in active_table:
		var source: Dictionary = active_table[active_item_id]
		var item := source.duplicate(true)
		item["item_id"] = int(active_item_id)
		item["item_name"] = source.get("active_item_name", "主动道具")
		item["max_stack"] = 1
		item["is_active"] = true
		unified[int(active_item_id)] = item
	return unified


func _generate_container_contents(slots: Array, group: Dictionary) -> void:
	var fill_chance := clampf(
		float(group.get("fill_chance", 0.0)),
		0.0,
		100.0
	)
	if pending_force_filled_slots:
		fill_chance = 100.0
	var group_id := int(group.get("loot_group_id", -1))
	var quality_upgrade := pending_quality_upgrade_percent
	var card_boost := pending_card_chance_boost_percent
	var guarantee_card := pending_guaranteed_card
	for slot_index in slots.size():
		if (
			fill_chance <= 0.0
			or (
				fill_chance < 100.0
				and _rng.randf_range(0.0, 100.0) >= fill_chance
			)
		):
			continue
		var quality := _roll_quality(group_id)
		if (
			quality < 4
			and quality_upgrade > 0
			and _rng.randf_range(0.0, 100.0) < quality_upgrade
		):
			quality += 1
		var entry := _create_drop_entry(quality, group, card_boost)
		if entry.is_empty():
			continue
		slots[slot_index] = entry

	if guarantee_card and not _slots_have_card(slots):
		_force_card_into_slots(slots, group_id, quality_upgrade)

	pending_quality_upgrade_percent = 0
	pending_card_chance_boost_percent = 0
	pending_guaranteed_card = false
	pending_force_filled_slots = false
	search_effects_changed.emit()


func _roll_quality(group_id: int) -> int:
	var group: Dictionary = loot_groups.get(group_id, {})
	var roll := _rng.randf_range(0.0, 100.0)
	var accumulated := 0.0
	var chance_fields := [
		"white_chance",
		"green_chance",
		"blue_chance",
		"purple_chance",
		"gold_chance",
	]
	for quality in chance_fields.size():
		accumulated += float(group.get(chance_fields[quality], 0.0))
		if roll < accumulated:
			return quality
	return 0


func _create_drop_entry(
	quality: int,
	group: Dictionary,
	card_boost_percent: int
) -> Dictionary:
	var weights := {
		"item": maxf(float(group.get("normal_item_chance", 60.0)), 0.0),
		"active": maxf(float(group.get("active_item_chance", 20.0)), 0.0),
		"card": maxf(float(group.get("card_chance", 20.0)), 0.0),
	}
	if card_boost_percent > 0:
		var added_card_chance := (
			float(weights["card"]) * card_boost_percent / 100.0
		)
		weights["card"] = float(weights["card"]) + added_card_chance
		weights["item"] = maxf(
			0.0,
			float(weights["item"]) - added_card_chance
		)

	var available_weights := {}
	if _has_weighted_item_candidate(quality, false):
		available_weights["item"] = weights["item"]
	if _has_weighted_item_candidate(quality, true):
		available_weights["active"] = weights["active"]
	if _has_weighted_card_candidate(quality):
		available_weights["card"] = weights["card"]
	var category := _roll_weighted_category(available_weights)
	match category:
		"item":
			var item := _pick_weighted_item(quality, false)
			if not item.is_empty():
				return {
					"content_type": "item",
					"item_id": int(item["item_id"]),
					"count": 1,
				}
		"active":
			var item := _pick_weighted_item(quality, true)
			if not item.is_empty():
				return {
					"content_type": "item",
					"item_id": int(item["item_id"]),
					"count": 1,
				}
		"card":
			var card := _pick_weighted_card(quality)
			if not card.is_empty():
				return {
					"content_type": "card",
					"card_id": int(card["card_id"]),
					"count": 1,
				}
	return {}


func _pick_weighted_item(quality: int, active_only: bool) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for item_value in items.values():
		var item: Dictionary = item_value
		if int(item.get("item_equality", -1)) != quality:
			continue
		if bool(item.get("is_active", false)) != active_only:
			continue
		var weight := float(item.get("drop_weight", 0.0))
		if weight <= 0.0:
			continue
		candidates.append(item)
		total_weight += weight

	if candidates.is_empty() or total_weight <= 0.0:
		return {}

	var roll := _rng.randf_range(0.0, total_weight)
	var accumulated := 0.0
	for item in candidates:
		accumulated += float(item.get("drop_weight", 0.0))
		if roll < accumulated:
			return item
	return candidates.back()


func _pick_weighted_card(quality: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for card_value in cards.values():
		var card: Dictionary = card_value
		if int(card.get("card_equality", -1)) != quality:
			continue
		var weight := float(card.get("card_drop_weight", 0.0))
		if weight <= 0.0:
			continue
		candidates.append(card)
		total_weight += weight
	if candidates.is_empty() or total_weight <= 0.0:
		return {}
	var roll := _rng.randf_range(0.0, total_weight)
	var accumulated := 0.0
	for card in candidates:
		accumulated += float(card.get("card_drop_weight", 0.0))
		if roll < accumulated:
			return card
	return candidates.back()


func _has_weighted_item_candidate(quality: int, active_only: bool) -> bool:
	for item_value in items.values():
		var item: Dictionary = item_value
		if (
			int(item.get("item_equality", -1)) == quality
			and bool(item.get("is_active", false)) == active_only
			and float(item.get("drop_weight", 0.0)) > 0.0
		):
			return true
	return false


func _has_weighted_card_candidate(quality: int) -> bool:
	for card_value in cards.values():
		var card: Dictionary = card_value
		if (
			int(card.get("card_equality", -1)) == quality
			and float(card.get("card_drop_weight", 0.0)) > 0.0
		):
			return true
	return false


func _roll_weighted_category(weights: Dictionary) -> String:
	var total := 0.0
	for value in weights.values():
		total += maxf(float(value), 0.0)
	if total <= 0.0:
		return ""
	var roll := _rng.randf_range(0.0, total)
	var accumulated := 0.0
	for category in ["item", "active", "card"]:
		if not weights.has(category):
			continue
		accumulated += maxf(float(weights[category]), 0.0)
		if roll < accumulated:
			return category
	return str(weights.keys().back())


func _slots_have_card(slots: Array) -> bool:
	for entry in slots:
		if (
			entry != null
			and str(entry.get("content_type", "item")) == "card"
		):
			return true
	return false


func _force_card_into_slots(
	slots: Array,
	group_id: int,
	quality_upgrade: int
) -> void:
	if slots.is_empty():
		return
	var quality := _roll_quality(group_id)
	if (
		quality < 4
		and quality_upgrade > 0
		and _rng.randf_range(0.0, 100.0) < quality_upgrade
	):
		quality += 1
	var card := _pick_weighted_card(quality)
	if card.is_empty():
		for fallback_quality in 5:
			card = _pick_weighted_card(fallback_quality)
			if not card.is_empty():
				break
	if card.is_empty():
		return
	var target_index := _rng.randi_range(0, slots.size() - 1)
	for index in slots.size():
		if slots[index] == null:
			target_index = index
			break
	slots[target_index] = {
		"content_type": "card",
		"card_id": int(card["card_id"]),
		"count": 1,
	}


func _inventory_available_space(item_id: int) -> int:
	var available := _available_space(
		inventory_slots,
		item_id,
		inventory_capacity
	)
	if not is_active_item(item_id):
		return available
	var max_carry := int(get_item(item_id).get("max_carry_count", 1))
	return mini(
		available,
		maxi(max_carry - get_inventory_item_count(item_id), 0)
	)


func _container_available_space(state: Dictionary, item_id: int) -> int:
	var slots: Array = state["slots"]
	var revealed: Array = state["revealed"]
	var max_stack := maxi(int(get_item(item_id).get("max_stack", 1)), 1)
	var available := 0
	for index in slots.size():
		if not bool(revealed[index]):
			continue
		var stack = slots[index]
		if stack == null:
			available += max_stack
		elif int(stack["item_id"]) == item_id:
			available += maxi(max_stack - int(stack["count"]), 0)
	return available


func _available_space(slots: Array, item_id: int, limit: int) -> int:
	var max_stack := maxi(int(get_item(item_id).get("max_stack", 1)), 1)
	var available := 0
	for index in mini(limit, slots.size()):
		var stack = slots[index]
		if stack == null:
			available += max_stack
		elif int(stack["item_id"]) == item_id:
			available += maxi(max_stack - int(stack["count"]), 0)
	return available


func _add_stack_to_revealed_slots(
	state: Dictionary,
	item_id: int,
	count: int
) -> int:
	var slots: Array = state["slots"]
	var revealed: Array = state["revealed"]
	var max_stack := maxi(int(get_item(item_id).get("max_stack", 1)), 1)
	var remaining := count
	for index in slots.size():
		if not bool(revealed[index]):
			continue
		var stack = slots[index]
		if stack == null or int(stack["item_id"]) != item_id:
			continue
		var add_count := mini(max_stack - int(stack["count"]), remaining)
		stack["count"] = int(stack["count"]) + add_count
		remaining -= add_count
		if remaining <= 0:
			return 0
	for index in slots.size():
		if not bool(revealed[index]) or slots[index] != null:
			continue
		var add_count := mini(max_stack, remaining)
		slots[index] = {"item_id": item_id, "count": add_count}
		remaining -= add_count
		if remaining <= 0:
			return 0
	return remaining


func _add_stack_to_slots(
	slots: Array,
	item_id: int,
	count: int,
	limit: int
) -> int:
	var remaining := count
	var max_stack := maxi(int(get_item(item_id).get("max_stack", 1)), 1)
	var bounded_limit := mini(limit, slots.size())

	for index in bounded_limit:
		var stack = slots[index]
		if stack == null or int(stack["item_id"]) != item_id:
			continue
		var add_count := mini(max_stack - int(stack["count"]), remaining)
		stack["count"] = int(stack["count"]) + add_count
		remaining -= add_count
		if remaining <= 0:
			return 0

	for index in bounded_limit:
		if slots[index] != null:
			continue
		var add_count := mini(max_stack, remaining)
		slots[index] = {"item_id": item_id, "count": add_count}
		remaining -= add_count
		if remaining <= 0:
			return 0
	return remaining


func _queue_quality_upgrade(percent: int) -> String:
	if percent <= pending_quality_upgrade_percent:
		return "已有相同或更强的下一次搜索品质效果"
	pending_quality_upgrade_percent = percent
	search_effects_changed.emit()
	return ""


func _queue_card_chance_boost(percent: int) -> String:
	if pending_guaranteed_card:
		return "下一次搜索已经保证出现卡牌"
	if percent <= pending_card_chance_boost_percent:
		return "已有相同或更强的下一次搜索卡牌效果"
	pending_card_chance_boost_percent = percent
	search_effects_changed.emit()
	return ""


func _queue_guaranteed_card() -> String:
	if pending_guaranteed_card:
		return "下一次搜索已经保证出现卡牌"
	pending_guaranteed_card = true
	pending_card_chance_boost_percent = 0
	search_effects_changed.emit()
	return ""


func _queue_force_filled_slots() -> String:
	if pending_force_filled_slots:
		return "下一次搜索已经不会出现空格"
	pending_force_filled_slots = true
	search_effects_changed.emit()
	return ""


func _consume_inventory_item(item_id: int, count: int) -> bool:
	var remaining := maxi(count, 0)
	for index in inventory_slots.size():
		var stack = inventory_slots[index]
		if stack == null or int(stack.get("item_id", -1)) != item_id:
			continue
		var removed := mini(int(stack.get("count", 0)), remaining)
		stack["count"] = int(stack.get("count", 0)) - removed
		remaining -= removed
		if int(stack["count"]) <= 0:
			inventory_slots[index] = null
		if remaining <= 0:
			_notify_inventory_changed()
			return true
	return false


func _effect_param(params: Array, index: int, fallback: int) -> int:
	return int(params[index]) if index < params.size() else fallback


func _use_result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}


func _notify_inventory_changed() -> void:
	var bindings_changed := false
	for index in active_bindings.size():
		var item_id = active_bindings[index]
		if item_id != null and get_inventory_item_count(int(item_id)) <= 0:
			active_bindings[index] = null
			bindings_changed = true
	inventory_changed.emit()
	if bindings_changed:
		active_bindings_changed.emit()
