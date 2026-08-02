extends Node2D

const BATTLE_SCENE := preload("res://scenes/battle.tscn")
const SEARCH_VIEW_SCENE := preload(
	"res://scenes/ui/search/search_view.tscn"
)
const INVENTORY_VIEW_SCENE := preload(
	"res://scenes/ui/inventory/inventory_view.tscn"
)
const GameDataLoader = preload("res://scripts/game_data.gd")

@onready var player: CharacterBody2D = $Actors/Player
@onready var map_title: Label = (
	$CanvasLayer/HUDPanel/Margin/VBoxContainer/Title
)
@onready var map_location: Label = (
	$CanvasLayer/HUDPanel/Margin/VBoxContainer/Location
)
@onready var battle_hint: Label = (
	$CanvasLayer/HUDPanel/Margin/VBoxContainer/BattleHint
)
@onready var card_count: Label = (
	$CanvasLayer/HUDPanel/Margin/VBoxContainer/CardCount
)
@onready var active_quickbar: ActiveQuickbar = %ActiveQuickbar

var _active_ui: Node
var _transitioning_to_battle := false
var _enemies: Dictionary = {}


func _ready() -> void:
	InventoryState.ensure_initialized()
	_enemies = GameDataLoader.load_enemies()
	_configure_current_map()
	_restore_world_session()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if GameSession.is_enemy_defeated(
			enemy.enemy_id,
			str(enemy.map_object_id)
		):
			enemy.queue_free()
			continue
		var battle_callback := _enter_battle.bind(str(enemy.map_object_id))
		if not enemy.player_touched.is_connected(battle_callback):
			enemy.player_touched.connect(battle_callback)

	for chest in get_tree().get_nodes_in_group("chests"):
		if not chest.search_requested.is_connected(_open_search):
			chest.search_requested.connect(_open_search)
		chest.refresh_state()

	if not InventoryState.inventory_changed.is_connected(_refresh_hud):
		InventoryState.inventory_changed.connect(_refresh_hud)
	_refresh_hud()
	if battle_hint.text.is_empty():
		battle_hint.text = "沿道路探索，靠近宝箱按 E 搜索，按 B 打开背包。"


func _configure_current_map() -> void:
	var level := get_tree().get_first_node_in_group("level_root")
	if level == null:
		level = get_tree().get_first_node_in_group("generated_level")
	if level == null:
		return
	if level.has_method("get_map_rect"):
		player.configure_world_bounds(level.get_map_rect())
	if (
		not GameSession.has_world_return_position
		and level.has_method("get_spawn_position")
	):
		player.global_position = level.get_spawn_position()
	map_title.text = str(level.get("map_name"))
	map_location.text = "地图：%s" % str(level.get("map_id"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and _active_ui == null:
		_open_inventory()
		get_viewport().set_input_as_handled()


func _restore_world_session() -> void:
	var result := GameSession.last_battle_result
	if (
		GameSession.has_world_return_position
		and not GameSession.return_to_spawn
	):
		player.global_position = GameSession.world_return_position

	match result:
		"victory":
			battle_hint.text = "战斗胜利，遭遇目标已清除。"
		"defeat":
			battle_hint.text = "战斗失败，已返回起点并恢复状态。"
		"retreat":
			battle_hint.text = "已撤退，2 秒内不会再次触发战斗。"

	GameSession.consume_world_result()


func _enter_battle(enemy_id: int, enemy_instance_id := "") -> void:
	if _transitioning_to_battle or not GameSession.can_enter_battle():
		return
	var enemy_data: Dictionary = _enemies.get(enemy_id, {})
	if GameSession.try_instant_enemy_defeat(
		enemy_id,
		str(enemy_data.get("enemy_type", "normal")),
		enemy_instance_id
	):
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if str(enemy.map_object_id) == enemy_instance_id:
				enemy.queue_free()
				break
		var enemy_name := str(enemy_data.get("name", "普通敌人"))
		battle_hint.text = "%s 已被护身符击败，正常掉落结算已触发。" % enemy_name
		active_quickbar.show_status("护身符生效：击败%s" % enemy_name)
		_refresh_hud()
		return
	_transitioning_to_battle = true
	GameSession.begin_battle(
		enemy_id,
		player.global_position,
		enemy_instance_id
	)
	get_tree().change_scene_to_packed(BATTLE_SCENE)


func _open_search(
	container_instance_id: String,
	loot_group_id: int
) -> void:
	if _active_ui != null or _transitioning_to_battle:
		return

	var search_view := SEARCH_VIEW_SCENE.instantiate() as SearchView
	add_child(search_view)
	_active_ui = search_view
	player.set_input_locked(true)
	active_quickbar.set_interaction_enabled(false)
	search_view.close_requested.connect(_close_search)
	search_view.open_container(
		container_instance_id,
		loot_group_id
	)
	battle_hint.text = "正在搜索，敌人仍会移动并可能打断搜索。"


func _open_inventory() -> void:
	var inventory_view := INVENTORY_VIEW_SCENE.instantiate() as InventoryView
	$CanvasLayer.add_child(inventory_view)
	_active_ui = inventory_view
	player.set_input_locked(true)
	active_quickbar.set_interaction_enabled(false)
	inventory_view.configure_embedded(false)
	inventory_view.close_requested.connect(_close_inventory)
	battle_hint.text = "已打开背包。"


func _close_search(_container_instance_id: String) -> void:
	_close_active_ui()
	battle_hint.text = "已暂停搜索，再次按 E 可继续。"


func _close_inventory() -> void:
	_close_active_ui()
	battle_hint.text = "已关闭背包。"


func _close_active_ui() -> void:
	if is_instance_valid(_active_ui):
		_active_ui.queue_free()
	_active_ui = null
	player.set_input_locked(false)
	active_quickbar.set_interaction_enabled(true)
	for chest in get_tree().get_nodes_in_group("chests"):
		chest.refresh_state()
	_refresh_hud()


func _refresh_hud() -> void:
	card_count.text = "卡组 1    背包 %d/%d    负重 %.1f/%.1f kg" % [
		InventoryState.get_inventory_used_slots(),
		InventoryState.inventory_capacity,
		InventoryState.get_inventory_weight(),
		InventoryState.max_carry_weight,
	]
