extends SceneTree


func _initialize() -> void:
	call_deferred("_inspect")


func _inspect() -> void:
	var packed := load("res://scenes/maps/manual/map_meadow_01.tscn") as PackedScene
	var level := packed.instantiate()
	root.add_child(level)
	await process_frame
	var layer := level.get_node("TileLayers/TreeLayer") as TileMapLayer
	var counts := {}
	for cell in layer.get_used_cells():
		var key := "%d:%s:%d" % [
			layer.get_cell_source_id(cell),
			layer.get_cell_atlas_coords(cell),
			layer.get_cell_alternative_tile(cell),
		]
		counts[key] = int(counts.get(key, 0)) + 1
	print("TREE_TILE_COUNTS=", counts)
	level.queue_free()
	await process_frame
	quit()
