extends Node

const TEST_SLOT := 2
const TEST_SLOT_PATH := "user://saves/slot_3.json"
const PREFERENCES_PATH := "user://save_preferences.cfg"

var _failed := false
var _original_slot_text := ""
var _original_preferences_text := ""
var _had_original_slot := false
var _had_original_preferences := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_backup_files()
	SaveSystem.delete_slot(TEST_SLOT)
	var created := SaveSystem.create_new_slot(TEST_SLOT)
	_check(bool(created.get("ok", false)), "creates an empty save slot")
	_check(FileAccess.file_exists(TEST_SLOT_PATH), "writes the slot file")

	InventoryState.player_coins = 321
	GameSession.set_player_hp(maxi(1, GameSession.player_max_hp - 2))
	SaveSystem.save_now()
	InventoryState.player_coins = 0
	GameSession.restore_full_health()
	var loaded := SaveSystem.load_slot(TEST_SLOT)
	_check(bool(loaded.get("ok", false)), "loads the saved slot")
	_check(InventoryState.player_coins == 321, "restores coins")
	_check(GameSession.player_hp == maxi(1, GameSession.player_max_hp - 2), "restores player hp")
	var summary := SaveSystem.get_slot_summaries()[TEST_SLOT]
	_check(bool(summary.get("occupied", false)), "reports an occupied slot")
	_check(int(summary.get("coins", 0)) == 321, "reports saved slot metadata")

	_restore_files()
	print("SAVE_SYSTEM_TEST_PASS")
	get_tree().quit(1 if _failed else 0)


func _backup_files() -> void:
	_had_original_slot = FileAccess.file_exists(TEST_SLOT_PATH)
	if _had_original_slot:
		_original_slot_text = FileAccess.get_file_as_string(TEST_SLOT_PATH)
	_had_original_preferences = FileAccess.file_exists(PREFERENCES_PATH)
	if _had_original_preferences:
		_original_preferences_text = FileAccess.get_file_as_string(PREFERENCES_PATH)


func _restore_files() -> void:
	_restore_file(TEST_SLOT_PATH, _had_original_slot, _original_slot_text)
	_restore_file(PREFERENCES_PATH, _had_original_preferences, _original_preferences_text)


func _restore_file(path: String, existed: bool, contents: String) -> void:
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(contents)
		file.close()
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
