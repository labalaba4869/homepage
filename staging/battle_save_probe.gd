extends Node


func _ready() -> void:
	var packed_scene := load("res://Tscn/Scene/battle.tscn") as PackedScene
	if packed_scene == null:
		printerr("battle scene could not be loaded")
		get_tree().quit(1)
		return
	var error := ResourceSaver.save(packed_scene, "user://battle_save_probe.tscn")
	print("battle save probe result: ", error)
	get_tree().quit(0 if error == OK else 1)
