extends Control

const WORLD_SCENE := "res://scenes/world.tscn"
const INVENTORY_VIEW_SCENE := preload(
	"res://scenes/ui/inventory/inventory_view.tscn"
)

@onready var status_label: Label = %StatusLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var inventory_label: Label = %InventoryLabel
@onready var cards_label: Label = %CardsLabel
@onready var coins_label: Label = %CoinsLabel
@onready var inventory_button: Button = %InventoryButton
@onready var depart_button: Button = %DepartButton

var _inventory_view: InventoryView


func _ready() -> void:
	InventoryState.ensure_initialized()
	GameSession.ensure_player_state()
	inventory_button.pressed.connect(_open_inventory)
	depart_button.pressed.connect(_depart)
	if not InventoryState.inventory_changed.is_connected(_refresh):
		InventoryState.inventory_changed.connect(_refresh)
	if not GameSession.player_health_changed.is_connected(_refresh_health):
		GameSession.player_health_changed.connect(_refresh_health)
	status_label.text = (
		"探索中生命归零，已安全返回基地。本次携带物暂不损失。"
		if GameSession.last_battle_result == "defeat"
		else "整备完成后可再次进入苔木荒野。"
	)
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	inventory_label.text = "背包  %d / %d 格    %.2f / %.2f kg" % [
		InventoryState.get_inventory_used_slots(),
		InventoryState.inventory_capacity,
		InventoryState.get_inventory_weight(),
		InventoryState.max_carry_weight,
	]
	cards_label.text = "获得卡牌  %d 张    当前卡组  %d 张" % [
		InventoryState.owned_cards.size(),
		InventoryState.deck_cards.size(),
	]
	coins_label.text = "持有金币  %d" % InventoryState.player_coins
	_refresh_health(GameSession.player_hp, GameSession.player_max_hp)


func _refresh_health(current_hp: int, max_hp: int) -> void:
	if not is_node_ready():
		return
	health_bar.max_value = maxi(max_hp, 1)
	health_bar.value = current_hp
	health_label.text = "%d / %d" % [current_hp, max_hp]


func _open_inventory() -> void:
	if is_instance_valid(_inventory_view):
		return
	_inventory_view = INVENTORY_VIEW_SCENE.instantiate() as InventoryView
	add_child(_inventory_view)
	_inventory_view.configure_embedded(false)
	_inventory_view.close_requested.connect(_close_inventory)


func _close_inventory() -> void:
	if is_instance_valid(_inventory_view):
		_inventory_view.queue_free()
	_inventory_view = null
	_refresh()


func _depart() -> void:
	InventoryState.reset_expedition()
	GameSession.start_new_expedition()
	get_tree().change_scene_to_file(WORLD_SCENE)
