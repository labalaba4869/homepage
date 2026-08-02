extends TileMapLayer

@export_node_path("TileMapLayer") var water_layer_path := NodePath("../WaterLayer")
@export_node_path("TileMapLayer") var boundary_layer_path := NodePath("../BoundaryLayer")


func _ready() -> void:
	# Keep the editable map intact; remove only runtime water cells covered by bridge tiles.
	call_deferred("refresh_bridge_passage")


func refresh_bridge_passage() -> void:
	_clear_blocking_cells(water_layer_path)
	_clear_blocking_cells(boundary_layer_path)


func _clear_blocking_cells(layer_path: NodePath) -> void:
	var blocking_layer := get_node_or_null(layer_path) as TileMapLayer
	if blocking_layer == null:
		push_warning("BridgeLayer cannot find a blocking layer at %s." % layer_path)
		return

	for bridge_cell in get_used_cells():
		var bridge_world_position := to_global(map_to_local(bridge_cell))
		var blocking_cell := blocking_layer.local_to_map(
			blocking_layer.to_local(bridge_world_position)
		)
		blocking_layer.erase_cell(blocking_cell)

	blocking_layer.update_internals()
