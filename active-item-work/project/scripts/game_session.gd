extends Node

signal player_health_changed(current_hp: int, max_hp: int)
signal world_effects_changed
signal enemy_defeated(enemy_id: int, source: String)

const GameDataScript = preload("res://scripts/game_data.gd")
const RETREAT_COOLDOWN_MSEC := 2000
const MIN_WINDOW_SIZE := Vector2i(960, 540)
const DEFAULT_WINDOW_SIZE := Vector2i(1280, 720)

var current_enemy_id := -1
var world_return_position := Vector2.ZERO
var has_world_return_position := false
var return_to_spawn := false
var return_to_base := false
var last_battle_result := ""
var defeated_enemy_ids := {}
var encounter_blocked_until_msec := 0

var player_max_hp := 1
var player_hp := 1
var pending_battle_attack_bonus := 0
var pending_battle_energy_bonus := 0
var pending_instant_normal_kill := false
var active_battle_attack_bonus := 0
var active_battle_energy_bonus := 0

var _move_speed_bonus_percent := 0
var _move_speed_buff_ends_msec := 0
var _windowed_size := DEFAULT_WINDOW_SIZE
var _windowed_position := Vector2i.ZERO
var _player_state_initialized := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().min_size = MIN_WINDOW_SIZE
	_windowed_size = DisplayServer.window_get_size()
	_windowed_position = DisplayServer.window_get_position()
	ensure_player_state()


func _process(_delta: float) -> void:
	_expire_move_speed_buff()


func _input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_F11
	):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()


func ensure_player_state() -> void:
	if _player_state_initialized:
		return
	var actors := GameDataScript.load_actors()
	var player_data: Dictionary = actors.get(0, {})
	player_max_hp = maxi(int(player_data.get("max_hp", 1)), 1)
	player_hp = player_max_hp
	_player_state_initialized = true


func set_player_hp(value: int) -> void:
	ensure_player_state()
	var next_hp := clampi(value, 0, player_max_hp)
	if next_hp == player_hp:
		return
	player_hp = next_hp
	player_health_changed.emit(player_hp, player_max_hp)


func heal_player_percent(percent: int) -> int:
	ensure_player_state()
	if player_hp >= player_max_hp or percent <= 0:
		return 0
	var amount := maxi(1, ceili(player_max_hp * percent / 100.0))
	var previous_hp := player_hp
	set_player_hp(player_hp + amount)
	return player_hp - previous_hp


func restore_full_health() -> void:
	ensure_player_state()
	set_player_hp(player_max_hp)


func queue_next_battle_attack_bonus(amount: int) -> String:
	if amount <= pending_battle_attack_bonus:
		return "已有相同或更强的下场战斗攻击增益"
	pending_battle_attack_bonus = amount
	world_effects_changed.emit()
	return ""


func queue_next_battle_energy_bonus(amount: int) -> String:
	if amount <= pending_battle_energy_bonus:
		return "已有相同或更强的下场战斗能量增益"
	pending_battle_energy_bonus = amount
	world_effects_changed.emit()
	return ""


func queue_move_speed_buff(percent: int, duration_seconds: int) -> String:
	_expire_move_speed_buff()
	if percent <= 0 or duration_seconds <= 0:
		return "移动速度效果配置无效"
	if (
		_move_speed_buff_ends_msec > Time.get_ticks_msec()
		and percent <= _move_speed_bonus_percent
	):
		return "已有相同或更强的移动速度效果"
	_move_speed_bonus_percent = percent
	_move_speed_buff_ends_msec = (
		Time.get_ticks_msec() + duration_seconds * 1000
	)
	world_effects_changed.emit()
	return ""


func get_move_speed_multiplier() -> float:
	_expire_move_speed_buff()
	return 1.0 + _move_speed_bonus_percent / 100.0


func get_move_speed_seconds_left() -> int:
	_expire_move_speed_buff()
	return maxi(
		0,
		ceili(
			(_move_speed_buff_ends_msec - Time.get_ticks_msec()) / 1000.0
		)
	)


func queue_instant_normal_kill() -> String:
	if pending_instant_normal_kill:
		return "护身符效果已经在等待下一只普通敌人"
	pending_instant_normal_kill = true
	world_effects_changed.emit()
	return ""


func try_instant_enemy_defeat(enemy_id: int, enemy_type: String) -> bool:
	if not pending_instant_normal_kill or enemy_type != "normal":
		return false
	pending_instant_normal_kill = false
	defeated_enemy_ids[enemy_id] = true
	enemy_defeated.emit(enemy_id, "active_item")
	world_effects_changed.emit()
	return true


func begin_battle(enemy_id: int, player_position: Vector2) -> void:
	current_enemy_id = enemy_id
	world_return_position = player_position
	has_world_return_position = true
	return_to_spawn = false
	return_to_base = false
	last_battle_result = ""
	active_battle_attack_bonus = pending_battle_attack_bonus
	active_battle_energy_bonus = pending_battle_energy_bonus
	pending_battle_attack_bonus = 0
	pending_battle_energy_bonus = 0
	world_effects_changed.emit()


func finish_battle(result: String) -> void:
	last_battle_result = result
	active_battle_attack_bonus = 0
	active_battle_energy_bonus = 0
	match result:
		"victory":
			defeated_enemy_ids[current_enemy_id] = true
			enemy_defeated.emit(current_enemy_id, "battle")
		"defeat":
			return_to_base = true
			return_to_spawn = false
			has_world_return_position = false
			restore_full_health()
		"retreat":
			encounter_blocked_until_msec = (
				Time.get_ticks_msec() + RETREAT_COOLDOWN_MSEC
			)
	world_effects_changed.emit()


func start_new_expedition() -> void:
	current_enemy_id = -1
	world_return_position = Vector2.ZERO
	has_world_return_position = false
	return_to_spawn = false
	return_to_base = false
	last_battle_result = ""
	defeated_enemy_ids.clear()
	encounter_blocked_until_msec = 0
	pending_battle_attack_bonus = 0
	pending_battle_energy_bonus = 0
	pending_instant_normal_kill = false
	active_battle_attack_bonus = 0
	active_battle_energy_bonus = 0
	_move_speed_bonus_percent = 0
	_move_speed_buff_ends_msec = 0
	restore_full_health()
	world_effects_changed.emit()


func can_enter_battle() -> bool:
	return (
		current_enemy_id < 0
		and Time.get_ticks_msec() >= encounter_blocked_until_msec
	)


func is_enemy_defeated(enemy_id: int) -> bool:
	return defeated_enemy_ids.has(enemy_id)


func consume_world_result() -> String:
	var result := last_battle_result
	last_battle_result = ""
	current_enemy_id = -1
	return_to_spawn = false
	return_to_base = false
	has_world_return_position = false
	return result


func _expire_move_speed_buff() -> void:
	if (
		_move_speed_buff_ends_msec <= 0
		or Time.get_ticks_msec() < _move_speed_buff_ends_msec
	):
		return
	_move_speed_bonus_percent = 0
	_move_speed_buff_ends_msec = 0
	world_effects_changed.emit()


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		call_deferred("_restore_windowed_bounds")
		return

	_windowed_size = DisplayServer.window_get_size()
	_windowed_position = DisplayServer.window_get_position()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _restore_windowed_bounds() -> void:
	DisplayServer.window_set_size(_windowed_size)
	DisplayServer.window_set_position(_windowed_position)
