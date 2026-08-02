extends Node

signal slots_changed
signal save_completed(slot_index: int)

const SLOT_COUNT := 3
const SAVE_DIRECTORY := "user://saves"
const SAVE_VERSION := 1
const BASE_SCENE := "res://scenes/base.tscn"
const WORLD_SCENE := "res://scenes/world.tscn"
const MENU_SCENE := "res://scenes/ui/menu/main_menu.tscn"
const DEFAULT_BASE_POSITION := Vector2(512, 522)

var active_slot_index := -1
var _last_used_slot_index := -1
var _play_time_seconds := 0.0
var _play_time_started_msec := 0
var _resume_scene_path := BASE_SCENE
var _resume_position := DEFAULT_BASE_POSITION
var _save_queued := false
var _exit_dialog: ConfirmationDialog
var _exit_after_save := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_save_directory()
	_load_preferences()
	InventoryState.inventory_changed.connect(request_auto_save)
	InventoryState.active_bindings_changed.connect(request_auto_save)
	InventoryState.search_effects_changed.connect(request_auto_save)
	GameSession.player_health_changed.connect(_on_player_health_changed)
	GameSession.world_effects_changed.connect(request_auto_save)
	GameSession.enemy_defeated.connect(_on_enemy_defeated)
	get_tree().scene_changed.connect(_on_scene_changed)
	get_window().close_requested.connect(_on_window_close_requested)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_escape_event(event) or _is_menu_scene() or active_slot_index < 0:
		return
	_request_return_to_menu(false)
	get_viewport().set_input_as_handled()


func has_any_save() -> bool:
	for slot_index in SLOT_COUNT:
		if FileAccess.file_exists(_slot_path(slot_index)):
			return true
	return false


func get_slot_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for slot_index in SLOT_COUNT:
		var data := _read_slot(slot_index)
		if data.is_empty():
			summaries.append({
				"slot_index": slot_index,
				"occupied": false,
			})
			continue
		var meta := _as_dictionary(data.get("meta", {}))
		summaries.append({
			"slot_index": slot_index,
			"occupied": true,
			"scene_path": str(meta.get("scene_path", BASE_SCENE)),
			"scene_name": _scene_display_name(str(meta.get("scene_path", BASE_SCENE))),
			"coins": int(meta.get("coins", 0)),
			"play_time_seconds": int(meta.get("play_time_seconds", 0)),
			"saved_at_unix": int(meta.get("saved_at_unix", 0)),
		})
	return summaries


func create_new_slot(slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return {"ok": false, "message": "存档栏位无效"}
	InventoryState.reset_for_new_game()
	GameSession.reset_for_new_game()
	active_slot_index = slot_index
	_last_used_slot_index = slot_index
	_play_time_seconds = 0.0
	_play_time_started_msec = Time.get_ticks_msec()
	_resume_scene_path = BASE_SCENE
	_resume_position = DEFAULT_BASE_POSITION
	_save_preferences()
	save_now()
	slots_changed.emit()
	return {"ok": true, "scene_path": BASE_SCENE}


func load_slot(slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return {"ok": false, "message": "存档栏位无效"}
	var data := _read_slot(slot_index)
	if data.is_empty():
		return {"ok": false, "message": "该栏位没有存档"}

	InventoryState.apply_save_data(_as_dictionary(data.get("inventory", {})))
	GameSession.apply_save_data(_as_dictionary(data.get("session", {})))
	var meta := _as_dictionary(data.get("meta", {}))
	active_slot_index = slot_index
	_last_used_slot_index = slot_index
	_play_time_seconds = maxf(float(meta.get("play_time_seconds", 0)), 0.0)
	_play_time_started_msec = Time.get_ticks_msec()
	_resume_scene_path = _validated_resume_scene(str(meta.get("scene_path", BASE_SCENE)))
	_resume_position = _array_to_vector2(meta.get("player_position", []), DEFAULT_BASE_POSITION)
	if _resume_scene_path == WORLD_SCENE:
		GameSession.world_return_position = _resume_position
		GameSession.has_world_return_position = true
	_save_preferences()
	slots_changed.emit()
	return {"ok": true, "scene_path": _resume_scene_path}


func continue_last_save() -> Dictionary:
	if _is_valid_slot(_last_used_slot_index) and FileAccess.file_exists(_slot_path(_last_used_slot_index)):
		return load_slot(_last_used_slot_index)
	for summary in get_slot_summaries():
		if bool(summary.get("occupied", false)):
			return load_slot(int(summary.get("slot_index", -1)))
	return {"ok": false, "message": "没有可继续的存档"}


func delete_slot(slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return {"ok": false, "message": "存档栏位无效"}
	var path := _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return {"ok": false, "message": "该栏位没有存档"}
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		return {"ok": false, "message": "删除存档失败"}
	if _last_used_slot_index == slot_index:
		_last_used_slot_index = -1
		_save_preferences()
	if active_slot_index == slot_index:
		active_slot_index = -1
	slots_changed.emit()
	return {"ok": true}


func save_now() -> bool:
	if active_slot_index < 0:
		return false
	_capture_runtime_context()
	var data := {
		"version": SAVE_VERSION,
		"meta": {
			"slot_index": active_slot_index,
			"saved_at_unix": int(Time.get_unix_time_from_system()),
			"play_time_seconds": int(get_play_time_seconds()),
			"scene_path": _resume_scene_path,
			"player_position": [_resume_position.x, _resume_position.y],
			"coins": InventoryState.player_coins,
		},
		"inventory": InventoryState.get_save_data(),
		"session": GameSession.get_save_data(),
	}
	var file := FileAccess.open(_slot_path(active_slot_index), FileAccess.WRITE)
	if file == null:
		push_error("Unable to write save slot %d" % active_slot_index)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_play_time_seconds = get_play_time_seconds()
	_play_time_started_msec = Time.get_ticks_msec()
	_last_used_slot_index = active_slot_index
	_save_preferences()
	save_completed.emit(active_slot_index)
	slots_changed.emit()
	return true


func request_auto_save() -> void:
	if active_slot_index < 0 or _save_queued:
		return
	_save_queued = true
	call_deferred("_flush_auto_save")


func get_play_time_seconds() -> float:
	if active_slot_index < 0 or _play_time_started_msec <= 0:
		return _play_time_seconds
	return _play_time_seconds + (Time.get_ticks_msec() - _play_time_started_msec) / 1000.0


func get_resume_scene_path() -> String:
	return _resume_scene_path


func get_resume_position() -> Vector2:
	return _resume_position


func is_resuming_scene(scene_path: String) -> bool:
	return active_slot_index >= 0 and _resume_scene_path == scene_path


func _flush_auto_save() -> void:
	_save_queued = false
	save_now()


func _on_player_health_changed(_current_hp: int, _max_hp: int) -> void:
	request_auto_save()


func _on_enemy_defeated(_enemy_id: int, _source: String) -> void:
	request_auto_save()


func _on_scene_changed(_scene_root: Node) -> void:
	if active_slot_index < 0:
		return
	call_deferred("request_auto_save")


func _on_window_close_requested() -> void:
	if _is_menu_scene() or active_slot_index < 0:
		get_tree().quit()
		return
	_request_return_to_menu(true)


func _request_return_to_menu(exit_after_save: bool) -> void:
	if _exit_dialog != null and is_instance_valid(_exit_dialog):
		return
	_exit_after_save = exit_after_save
	_exit_dialog = ConfirmationDialog.new()
	_exit_dialog.title = "退出游戏"
	_exit_dialog.dialog_text = "是否保存当前进度并退出到主界面？"
	_exit_dialog.ok_button_text = "保存并返回"
	_exit_dialog.cancel_button_text = "取消"
	_exit_dialog.confirmed.connect(_confirm_return_to_menu)
	_exit_dialog.canceled.connect(_dismiss_exit_dialog)
	get_tree().root.add_child(_exit_dialog)
	_exit_dialog.popup_centered(Vector2i(440, 180))


func _confirm_return_to_menu() -> void:
	save_now()
	var should_quit := _exit_after_save
	_dismiss_exit_dialog()
	if should_quit:
		get_tree().quit()
		return
	get_tree().change_scene_to_file(MENU_SCENE)


func _dismiss_exit_dialog() -> void:
	if _exit_dialog != null and is_instance_valid(_exit_dialog):
		_exit_dialog.queue_free()
	_exit_dialog = null
	_exit_after_save = false


func _capture_runtime_context() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var scene_path := str(current_scene.scene_file_path)
	if scene_path == "res://scenes/battle.tscn":
		_resume_scene_path = WORLD_SCENE
		if GameSession.has_world_return_position:
			_resume_position = GameSession.world_return_position
		return
	if scene_path != BASE_SCENE and scene_path != WORLD_SCENE:
		return
	_resume_scene_path = scene_path
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_resume_position = player.global_position


func _read_slot(slot_index: int) -> Dictionary:
	var path := _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return _as_dictionary(json.data)


func _ensure_save_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))


func _load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load("user://save_preferences.cfg") != OK:
		return
	_last_used_slot_index = int(config.get_value("save", "last_used_slot", -1))


func _save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("save", "last_used_slot", _last_used_slot_index)
	config.save("user://save_preferences.cfg")


func _slot_path(slot_index: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIRECTORY, slot_index + 1]


func _is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < SLOT_COUNT


func _is_menu_scene() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and str(current_scene.scene_file_path) == MENU_SCENE


func _is_escape_event(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_ESCAPE
	)


func _validated_resume_scene(scene_path: String) -> String:
	return scene_path if scene_path in [BASE_SCENE, WORLD_SCENE] else BASE_SCENE


func _scene_display_name(scene_path: String) -> String:
	if scene_path == WORLD_SCENE:
		return "野外探索"
	return "夜幕营地"


func _array_to_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func _as_dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
