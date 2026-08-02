extends Node2D

const WORLD_SCENE := "res://scenes/world.tscn"
const INVENTORY_VIEW_SCENE := preload(
	"res://scenes/ui/inventory/inventory_view.tscn"
)
const MERCHANT_SHOP_SCENE := preload(
	"res://scenes/ui/base/merchant_shop.tscn"
)
const DECK_OVERVIEW_SCENE := preload(
	"res://scenes/ui/base/deck_overview.tscn"
)
const BASE_MAP_RECT := Rect2(0, 0, 1024, 640)
const BASE_SCENE := "res://scenes/base.tscn"

@onready var player: CharacterBody2D = %Player
@onready var merchant: MerchantNpc = %Merchant
@onready var canvas_layer: CanvasLayer = %CanvasLayer
@onready var coins_label: Label = %CoinsLabel
@onready var backpack_button: Button = %BackpackButton
@onready var deck_button: Button = %DeckButton
@onready var depart_button: Button = %DepartButton
@onready var depart_dialog: ConfirmationDialog = %DepartDialog

var _active_ui: Control


func _ready() -> void:
	InventoryState.ensure_initialized()
	player.configure_world_bounds(BASE_MAP_RECT)
	if SaveSystem.is_resuming_scene(BASE_SCENE):
		player.global_position = SaveSystem.get_resume_position()
	merchant.trade_requested.connect(_open_shop)
	backpack_button.pressed.connect(_open_inventory)
	deck_button.pressed.connect(_open_deck_overview)
	depart_button.pressed.connect(_request_depart)
	depart_dialog.confirmed.connect(_depart)
	depart_dialog.canceled.connect(_cancel_depart)
	InventoryState.inventory_changed.connect(_refresh_hud)
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("inventory")
		and _active_ui == null
		and not depart_dialog.visible
	):
		_open_inventory()
		get_viewport().set_input_as_handled()


func _open_shop() -> void:
	if _active_ui != null or depart_dialog.visible:
		return
	var shop := MERCHANT_SHOP_SCENE.instantiate() as MerchantShop
	canvas_layer.add_child(shop)
	_open_overlay(shop)
	shop.close_requested.connect(_close_active_ui)


func _open_inventory() -> void:
	if _active_ui != null or depart_dialog.visible:
		return
	var inventory := INVENTORY_VIEW_SCENE.instantiate() as InventoryView
	canvas_layer.add_child(inventory)
	inventory.configure_embedded(false)
	_open_overlay(inventory)
	inventory.close_requested.connect(_close_active_ui)


func _open_deck_overview() -> void:
	if _active_ui != null or depart_dialog.visible:
		return
	var deck_overview := DECK_OVERVIEW_SCENE.instantiate() as DeckOverview
	canvas_layer.add_child(deck_overview)
	_open_overlay(deck_overview)
	deck_overview.close_requested.connect(_close_active_ui)


func _open_overlay(overlay: Control) -> void:
	_active_ui = overlay
	_set_hud_visible(false)
	player.set_input_locked(true)
	merchant.set_interaction_enabled(false)
	backpack_button.disabled = true
	deck_button.disabled = true
	depart_button.disabled = true


func _close_active_ui() -> void:
	if is_instance_valid(_active_ui):
		_active_ui.queue_free()
	_active_ui = null
	_set_hud_visible(true)
	player.set_input_locked(false)
	merchant.set_interaction_enabled(true)
	backpack_button.disabled = false
	deck_button.disabled = false
	depart_button.disabled = false
	_refresh_hud()


func _set_hud_visible(value: bool) -> void:
	for node in get_tree().get_nodes_in_group("base_hud"):
		if node is CanvasItem:
			node.visible = value


func _request_depart() -> void:
	if _active_ui != null:
		return
	player.set_input_locked(true)
	merchant.set_interaction_enabled(false)
	depart_dialog.popup_centered(Vector2i(420, 180))


func _cancel_depart() -> void:
	player.set_input_locked(false)
	merchant.set_interaction_enabled(true)


func _depart() -> void:
	InventoryState.reset_expedition()
	GameSession.start_new_expedition()
	get_tree().change_scene_to_file(WORLD_SCENE)


func _refresh_hud() -> void:
	coins_label.text = "%d" % InventoryState.player_coins
