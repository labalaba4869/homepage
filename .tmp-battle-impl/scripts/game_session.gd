extends Node

const RETREAT_COOLDOWN_MSEC := 2000

var current_enemy_id := -1
var world_return_position := Vector2.ZERO
var has_world_return_position := false
var return_to_spawn := false
var last_battle_result := ""
var defeated_enemy_ids := {}
var encounter_blocked_until_msec := 0


func begin_battle(enemy_id: int, player_position: Vector2) -> void:
	current_enemy_id = enemy_id
	world_return_position = player_position
	has_world_return_position = true
	return_to_spawn = false
	last_battle_result = ""


func finish_battle(result: String) -> void:
	last_battle_result = result
	match result:
		"victory":
			defeated_enemy_ids[current_enemy_id] = true
		"defeat":
			return_to_spawn = true
			has_world_return_position = false
		"retreat":
			encounter_blocked_until_msec = (
				Time.get_ticks_msec() + RETREAT_COOLDOWN_MSEC
			)


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
	has_world_return_position = false
	return result
