extends Node2D

@onready var player: CharacterBody2D = $Actors/Player
@onready var battle_hint: Label = (
	$CanvasLayer/HUDPanel/Margin/VBoxContainer/BattleHint
)
@onready var card_count: Label = (
	$CanvasLayer/HUDPanel/Margin/VBoxContainer/CardCount
)

var _battle_scene := preload("res://scenes/battle.tscn")
var _opened_chests := 0
var _transitioning_to_battle := false


func _ready() -> void:
	_restore_world_session()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if GameSession.is_enemy_defeated(enemy.enemy_id):
			enemy.queue_free()
			continue
		if not enemy.player_touched.is_connected(_enter_battle):
			enemy.player_touched.connect(_enter_battle)

	for chest in get_tree().get_nodes_in_group("chests"):
		if not chest.opened.is_connected(_on_chest_opened):
			chest.opened.connect(_on_chest_opened)

	card_count.text = "牌库：11    手牌上限：10    物资：%d" % _opened_chests
	if battle_hint.text.is_empty():
		battle_hint.text = "沿道路探索，靠近宝箱按 E。"


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


func _enter_battle(enemy_id: int) -> void:
	if _transitioning_to_battle or not GameSession.can_enter_battle():
		return
	_transitioning_to_battle = true
	GameSession.begin_battle(enemy_id, player.global_position)
	get_tree().change_scene_to_packed(_battle_scene)


func _on_chest_opened(reward_text: String) -> void:
	_opened_chests += 1
	card_count.text = "牌库：11    手牌上限：10    物资：%d" % _opened_chests
	battle_hint.text = "发现：%s" % reward_text
