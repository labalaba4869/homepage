extends SceneTree


func _initialize() -> void:
	call_deferred("_inspect")


func _inspect() -> void:
	var packed := load("res://scenes/maps/manual/map_meadow_01.tscn") as PackedScene
	var level := packed.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame

	var bridge := level.get_node("TileLayers/BridgeLayer") as TileMapLayer
	for cell in bridge.get_used_cells():
		var world_position := bridge.to_global(bridge.map_to_local(cell))
		var query := PhysicsPointQueryParameters2D.new()
		query.position = world_position
		query.collision_mask = 1
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hits: Array[Dictionary] = level.get_world_2d().direct_space_state.intersect_point(query, 32)
		if not hits.is_empty():
			var names: Array[String] = []
			for hit in hits:
				var collider := hit.get("collider") as Node
				names.append(str(collider.get_path()) if collider != null else "<unknown>")
			print("blocked cell=", cell, " at=", world_position, " by=", names)

	level.queue_free()
	await process_frame
	quit()
