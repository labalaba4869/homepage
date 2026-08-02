@tool
extends EditorScript

const MAP_SIZE := Vector2i(32, 20)


func _run() -> void:
	var root := get_scene()
	if root == null or root.scene_file_path != "res://scenes/base.tscn":
		push_error("Open scenes/base.tscn before running this editor script.")
		return
	var ground := root.get_node("TileLayers/GroundLayer") as TileMapLayer
	var road := root.get_node("TileLayers/RoadLayer") as TileMapLayer
	var decorations := root.get_node(
		"TileLayers/DecorationLayer"
	) as TileMapLayer
	ground.clear()
	road.clear()
	decorations.clear()

	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var variant := posmod(x * 7 + y * 13, 8)
			ground.set_cell(Vector2i(x, y), 0, Vector2i(variant, 0), 0)

	var clearing_cells: Array[Vector2i] = []
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var dx := (x - 16) / 9.0
			var dy := (y - 10) / 5.0
			if dx * dx + dy * dy <= 1.0:
				clearing_cells.append(Vector2i(x, y))
	for y in range(10, MAP_SIZE.y):
		for x in range(15, 18):
			clearing_cells.append(Vector2i(x, y))
	for x in range(3, 17):
		for y in range(9, 12):
			clearing_cells.append(Vector2i(x, y))
	road.set_cells_terrain_connect(clearing_cells, 0, 0, true)

	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var edge := x < 3 or x >= MAP_SIZE.x - 3 or y < 3 or y >= MAP_SIZE.y - 3
			if edge and posmod(x * 11 + y * 17, 5) == 0:
				decorations.set_cell(
					Vector2i(x, y),
					0,
					Vector2i(posmod(x + y, 10), 0),
					0
				)

	get_editor_interface().mark_scene_as_unsaved()
	print("Rebuilt base camp tiles. Review the scene, then save it normally.")
