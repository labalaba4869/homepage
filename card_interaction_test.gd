extends Node

const INVENTORY_SCENE := preload(
	"res://scenes/ui/inventory/inventory_view.tscn"
)
const BATTLE_SCENE := preload("res://scenes/battle.tscn")

var _failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	await _test_inventory_cards()
	await _test_battle_cards()
	get_tree().quit(1 if _failed else 0)


func _test_inventory_cards() -> void:
	var inventory := INVENTORY_SCENE.instantiate()
	get_tree().root.add_child(inventory)
	await get_tree().process_frame
	await get_tree().process_frame
	inventory._show_tab(2)
	await get_tree().process_frame
	var deck_grid: GridContainer = inventory.get_node("%DeckGrid")
	_check(deck_grid.get_child_count() > 0, "Deck card grid is empty")
	if deck_grid.get_child_count() == 0:
		inventory.queue_free()
		await get_tree().process_frame
		return
	var card_cell := deck_grid.get_child(0) as CenterContainer
	var card := card_cell.get_child(0) as BattleCardView
	inventory._on_browse_card_hover(card, true)
	await get_tree().create_timer(0.14).timeout
	_check(card.scale.is_equal_approx(Vector2.ONE * 1.2), "Browse hover scale is not 1.2")
	_save_screenshot("D:/Homepage Dev/inventory_card_hover_preview.png")
	card.card_clicked.emit()
	await get_tree().process_frame
	var detail: CardDetailOverlay = inventory.get_node("%CardDetailOverlay")
	_check(detail.visible, "Inventory card detail did not open")
	detail.close()
	inventory.queue_free()
	await get_tree().process_frame


func _test_battle_cards() -> void:
	var battle = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var hand_container: HBoxContainer = battle.get_node("%HandContainer")
	var playable := _playable_hand_cards(battle, hand_container)
	_check(playable.size() >= 2, "Need two playable cards for interaction test")
	if playable.size() < 2:
		battle.queue_free()
		await get_tree().process_frame
		return

	var first: Dictionary = playable[0]
	var second: Dictionary = playable[1]
	battle._on_hand_card_pressed(first["instance_id"], first["view"])
	await get_tree().create_timer(0.14).timeout
	_check(bool(battle.get("_sticky_targeting")), "Card click did not enter targeting")
	_check(first["view"].scale.is_equal_approx(Vector2.ONE * 1.2), "Battle click scale is not 1.2")
	_save_screenshot("D:/Homepage Dev/battle_card_targeting_preview.png")

	battle._on_hand_card_pressed(second["instance_id"], second["view"])
	await get_tree().process_frame
	_check(
		int(battle.get("_dragging_instance_id")) == int(second["instance_id"]),
		"Clicking another card did not switch targeting"
	)

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	battle._input(right_click)
	await get_tree().create_timer(0.14).timeout
	_check(not bool(battle.get("_sticky_targeting")), "Right click did not cancel targeting")

	playable = _playable_hand_cards(battle, hand_container)
	var drag_card: Dictionary = playable[0]
	var drag_view: BattleCardView = drag_card["view"]
	var center := drag_view.get_global_rect().get_center()
	battle._on_hand_card_drag_started(
		center,
		drag_card["instance_id"],
		drag_view
	)
	_check(not bool(battle.get("_sticky_targeting")), "Direct drag became sticky targeting")
	battle._on_hand_card_drag_ended(center, drag_card["instance_id"])
	await get_tree().process_frame
	_check(int(battle.get("_dragging_instance_id")) < 0, "Invalid drag did not cancel")
	_check(battle.get_node_or_null("%CardDetailOverlay") == null, "Battle still contains card detail overlay")
	battle.queue_free()
	await get_tree().process_frame


func _playable_hand_cards(battle: Node, hand: HBoxContainer) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in hand.get_children():
		if cell.get_child_count() == 0:
			continue
		var card := cell.get_child(0) as BattleCardView
		var instance_id := int(card.runtime_state.get("instance_id", -1))
		if instance_id >= 0 and battle._can_start_card_interaction(instance_id):
			result.append({
				"instance_id": instance_id,
				"view": card,
			})
	return result


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _save_screenshot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
