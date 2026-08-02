class_name MainMenu
extends Control

const BASE_SCENE := "res://scenes/base.tscn"

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var load_button: Button = %LoadButton
@onready var quit_button: Button = %QuitButton
@onready var slot_picker: SaveSlotPicker = %SaveSlotPicker
@onready var overwrite_dialog: ConfirmationDialog = %OverwriteDialog
@onready var delete_dialog: ConfirmationDialog = %DeleteDialog

var _pending_slot_index := -1


func _ready() -> void:
	continue_button.pressed.connect(_continue_game)
	new_game_button.pressed.connect(_open_new_game_picker)
	load_button.pressed.connect(_open_load_picker)
	quit_button.pressed.connect(_quit_game)
	slot_picker.slot_selected.connect(_on_slot_selected)
	slot_picker.delete_requested.connect(_request_delete_slot)
	overwrite_dialog.confirmed.connect(_create_pending_slot)
	delete_dialog.confirmed.connect(_delete_pending_slot)
	SaveSystem.slots_changed.connect(_refresh_buttons)
	_refresh_buttons()


func _refresh_buttons() -> void:
	var has_saves := SaveSystem.has_any_save()
	continue_button.visible = has_saves
	load_button.disabled = not has_saves


func _continue_game() -> void:
	var result := SaveSystem.continue_last_save()
	if bool(result.get("ok", false)):
		_change_to_saved_scene(str(result.get("scene_path", BASE_SCENE)))


func _open_new_game_picker() -> void:
	slot_picker.open_picker(false)


func _open_load_picker() -> void:
	if SaveSystem.has_any_save():
		slot_picker.open_picker(true)


func _on_slot_selected(slot_index: int, occupied: bool, load_mode: bool) -> void:
	_pending_slot_index = slot_index
	if load_mode:
		var load_result := SaveSystem.load_slot(slot_index)
		if bool(load_result.get("ok", false)):
			slot_picker.hide()
			_change_to_saved_scene(str(load_result.get("scene_path", BASE_SCENE)))
		return
	if occupied:
		overwrite_dialog.popup_centered(Vector2i(430, 180))
		return
	_create_pending_slot()


func _create_pending_slot() -> void:
	var result := SaveSystem.create_new_slot(_pending_slot_index)
	if not bool(result.get("ok", false)):
		return
	slot_picker.hide()
	_change_to_saved_scene(str(result.get("scene_path", BASE_SCENE)))


func _request_delete_slot(slot_index: int) -> void:
	_pending_slot_index = slot_index
	delete_dialog.popup_centered(Vector2i(430, 180))


func _delete_pending_slot() -> void:
	SaveSystem.delete_slot(_pending_slot_index)
	slot_picker.refresh_picker()


func _change_to_saved_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func _quit_game() -> void:
	get_tree().quit()
