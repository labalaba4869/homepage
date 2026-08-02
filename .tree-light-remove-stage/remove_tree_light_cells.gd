extends SceneTree

const MAP_PATH := "D:/Homepage Dev/.tree-light-remove-stage/map_meadow_01.tscn"
const ENVIRONMENT_SOURCE_ID := 2
const TREE_LIGHT_TILE_ID := 1


func _initialize() -> void:
	call_deferred("_remove_cells")


func _remove_cells() -> void:
	var packed := load(MAP_PATH) as PackedScene
	if packed == null:
		push_error("Unable to load staged meadow map.")
		quit(1)
		return

	var level := packed.instantiate()
	var tree_layer := level.get_node("TileLayers/TreeLayer") as TileMapLayer
	var removed := 0
	for cell in tree_layer.get_used_cells():
		if (
			tree_layer.get_cell_source_id(cell) == ENVIRONMENT_SOURCE_ID
			and tree_layer.get_cell_alternative_tile(cell) == TREE_LIGHT_TILE_ID
		):
			tree_layer.erase_cell(cell)
			removed += 1

	var output := PackedScene.new()
	var pack_error := output.pack(level)
	if pack_error != OK:
		push_error("Unable to repack staged meadow map: %s" % error_string(pack_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(output, MAP_PATH)
	if save_error != OK:
		push_error("Unable to save staged meadow map: %s" % error_string(save_error))
		quit(1)
		return

	print("REMOVED_TREE_LIGHT_CELLS=", removed)
	level.free()
	quit()
