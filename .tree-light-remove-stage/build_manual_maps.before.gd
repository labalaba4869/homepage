extends SceneTree

const CELL_SIZE := 32
const MAP_HALF_WIDTH := 48
const MAP_HALF_HEIGHT := 32

const TERRAIN_PATH := "res://assets/art/scene/tileset/meadow/meadow_terrain.tres"
const ENVIRONMENT_PATH := "res://assets/art/scene/tileset/meadow/meadow_environment.tres"
const DECORATION_PATH := "res://assets/art/scene/tileset/meadow/meadow_decorations.tres"
const BOUNDARY_PATH := "res://assets/art/scene/tileset/meadow/map_boundary.tres"
const MANUAL_LEVEL_SCRIPT := preload("res://scripts/manual_level.gd")

const SIDE_BITS := [
	[1, TileSet.CELL_NEIGHBOR_TOP_SIDE],
	[2, TileSet.CELL_NEIGHBOR_RIGHT_SIDE],
	[4, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE],
	[8, TileSet.CELL_NEIGHBOR_LEFT_SIDE],
]


func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--confirm-rebuild"):
		print(
			"Manual map rebuild skipped. Pass --confirm-rebuild only when "
			+ "you intentionally want to overwrite the template and meadow map."
		)
		quit()
		return
	call_deferred("_build")


func _build() -> void:
	_make_directories()
	_build_environment_scenes()
	_build_tilesets()
	_build_map_template()
	_build_meadow_map()
	print("Manual map resources created successfully.")
	quit()


func _make_directories() -> void:
	for path in [
		"res://assets/art/scene/tileset/meadow",
		"res://scenes/environment/meadow",
		"res://scenes/maps/templates",
		"res://scenes/maps/manual",
	]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_environment_scenes() -> void:
	_build_tree_scene(
		"res://scenes/environment/meadow/tree_green.tscn",
		"res://assets/art/scene/world/tree.png",
		Rect2(),
		Color.WHITE,
		Vector2(2.0, 2.0)
	)
	_build_tree_scene(
		"res://scenes/environment/meadow/tree_light.tscn",
		"res://assets/art/scene/world/tree.png",
		Rect2(),
		Color(1.08, 1.02, 0.86, 1.0),
		Vector2(2.15, 2.05)
	)
	_build_tree_scene(
		"res://scenes/environment/meadow/tree_maple.tscn",
		"res://assets/art/scene/world/maple_tree.png",
		Rect2(0, 0, 32, 48),
		Color.WHITE,
		Vector2(2.0, 2.0)
	)
	_build_bush_scene(
		"res://scenes/environment/meadow/bush_green.tscn",
		Color.WHITE,
		Vector2(2.0, 2.0)
	)
	_build_bush_scene(
		"res://scenes/environment/meadow/bush_light.tscn",
		Color(1.05, 1.05, 0.78, 1.0),
		Vector2(1.8, 1.8)
	)
	_build_house_scene()


func _build_tree_scene(
	path: String,
	texture_path: String,
	region: Rect2,
	modulate: Color,
	scale_value: Vector2
) -> void:
	var root := StaticBody2D.new()
	root.name = path.get_file().get_basename().to_pascal_case()

	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = load("res://assets/art/scene/shadows/medium_shadow.png")
	shadow.position = Vector2(0, -4)
	shadow.scale = Vector2(3.2, 1.8)
	shadow.modulate = Color(1, 1, 1, 0.58)
	shadow.z_index = -1
	_add_owned(root, shadow, root)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	var texture: Texture2D = load(texture_path)
	if region.size != Vector2.ZERO:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		sprite.texture = atlas
	else:
		sprite.texture = texture
	sprite.position = Vector2(0, -48)
	sprite.scale = scale_value
	sprite.modulate = modulate
	_add_owned(root, sprite, root)

	var collision := CollisionShape2D.new()
	collision.name = "TrunkCollision"
	collision.position = Vector2(0, -8)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 18)
	collision.shape = shape
	_add_owned(root, collision, root)
	_save_scene(root, path)


func _build_bush_scene(path: String, modulate: Color, scale_value: Vector2) -> void:
	var root := Node2D.new()
	root.name = path.get_file().get_basename().to_pascal_case()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/art/scene/world/bush.png")
	sprite.position = Vector2(0, -16)
	sprite.scale = scale_value
	sprite.modulate = modulate
	_add_owned(root, sprite, root)
	_save_scene(root, path)


func _build_house_scene() -> void:
	var root := StaticBody2D.new()
	root.name = "MeadowHouse"
	root.set_meta("editor_description", "独立房屋场景。根节点位于门前地面，便于 Y 排序和地图吸附。")

	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = load("res://assets/art/scene/shadows/large_shadow.png")
	shadow.position = Vector2(0, -30)
	shadow.scale = Vector2(5.2, 2.8)
	shadow.modulate = Color(1, 1, 1, 0.62)
	shadow.z_index = -1
	_add_owned(root, shadow, root)

	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/art/scene/world/house.png")
	atlas.region = Rect2(0, 0, 80, 96)
	var sprite := Sprite2D.new()
	sprite.name = "HouseSprite"
	sprite.texture = atlas
	sprite.position = Vector2(0, -96)
	sprite.scale = Vector2(2, 2)
	_add_owned(root, sprite, root)

	var collision := CollisionShape2D.new()
	collision.name = "WallCollision"
	collision.position = Vector2(0, -22)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(132, 44)
	collision.shape = shape
	_add_owned(root, collision, root)

	var door := Marker2D.new()
	door.name = "DoorMarker"
	door.position = Vector2(0, 4)
	_add_owned(root, door, root)

	var interaction := Area2D.new()
	interaction.name = "DoorInteractionPlaceholder"
	interaction.collision_layer = 0
	interaction.collision_mask = 0
	interaction.monitoring = false
	interaction.set_meta("editor_description", "预留的房门交互节点，本阶段不切换室内场景。")
	_add_owned(root, interaction, root)
	var interaction_shape := CollisionShape2D.new()
	interaction_shape.name = "CollisionShape2D"
	interaction_shape.position = Vector2(0, 10)
	var door_shape := RectangleShape2D.new()
	door_shape.size = Vector2(34, 28)
	interaction_shape.shape = door_shape
	_add_owned(interaction, interaction_shape, root)
	_save_scene(root, "res://scenes/environment/meadow/meadow_house.tscn")


func _build_tilesets() -> void:
	_build_terrain_tileset()
	_build_environment_tileset()
	_build_decoration_tileset()
	_build_boundary_tileset()


func _build_terrain_tileset() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)

	for terrain_name in ["Road", "Water", "Cliff"]:
		tile_set.add_terrain_set()
		var terrain_set := tile_set.get_terrain_sets_count() - 1
		tile_set.set_terrain_set_mode(terrain_set, TileSet.TERRAIN_MODE_MATCH_SIDES)
		tile_set.add_terrain(terrain_set)
		tile_set.set_terrain_name(terrain_set, 0, terrain_name)

	var ground := _atlas_source("res://assets/art/scene/tileset/meadow/ground_variants.png")
	tile_set.add_source(ground, 0)
	for x in range(8):
		ground.create_tile(Vector2i(x, 0))
		ground.get_tile_data(Vector2i(x, 0), 0).probability = 1.0

	var road := _atlas_source("res://assets/art/scene/tileset/meadow/road_terrain.png")
	tile_set.add_source(road, 1)
	_configure_connected_tiles(road, 0, false, false)

	var water := _atlas_source("res://assets/art/scene/tileset/meadow/water_terrain_animated.png")
	tile_set.add_source(water, 2)
	for mask in range(16):
		var coords := Vector2i(mask * 4, 0)
		water.create_tile(coords)
		water.set_tile_animation_columns(coords, 4)
		water.set_tile_animation_frames_count(coords, 4)
		water.set_tile_animation_speed(coords, 2.4)
		var tile_data := water.get_tile_data(coords, 0)
		_set_terrain_bits(tile_data, 1, mask)
		_add_collision_rect(tile_data, Rect2(-16, -16, 32, 32))

	var cliff := _atlas_source("res://assets/art/scene/tileset/meadow/cliff_terrain.png")
	tile_set.add_source(cliff, 3)
	_configure_connected_tiles(cliff, 2, true, false)

	var bridge := _atlas_source("res://assets/art/scene/tileset/meadow/bridge_tiles.png")
	tile_set.add_source(bridge, 4)
	bridge.create_tile(Vector2i(0, 0))
	bridge.create_tile(Vector2i(1, 0))
	ResourceSaver.save(tile_set, TERRAIN_PATH)


func _build_environment_tileset() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "Fence")

	var fence := _atlas_source("res://assets/art/scene/tileset/meadow/fence_terrain.png")
	tile_set.add_source(fence, 0)
	_configure_connected_tiles(fence, 0, false, true)

	var decoration := _atlas_source("res://assets/art/scene/tileset/meadow/decoration_variants.png")
	tile_set.add_source(decoration, 1)
	for x in range(10):
		decoration.create_tile(Vector2i(x, 0))
		decoration.get_tile_data(Vector2i(x, 0), 0).probability = 1.0

	var scenes := TileSetScenesCollectionSource.new()
	scenes.create_scene_tile(load("res://scenes/environment/meadow/tree_green.tscn"), 0)
	scenes.create_scene_tile(load("res://scenes/environment/meadow/tree_light.tscn"), 1)
	scenes.create_scene_tile(load("res://scenes/environment/meadow/tree_maple.tscn"), 2)
	scenes.create_scene_tile(load("res://scenes/environment/meadow/bush_green.tscn"), 3)
	scenes.create_scene_tile(load("res://scenes/environment/meadow/bush_light.tscn"), 4)
	tile_set.add_source(scenes, 2)
	ResourceSaver.save(tile_set, ENVIRONMENT_PATH)


func _build_boundary_tileset() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)
	var source := _atlas_source("res://assets/art/scene/tileset/meadow/boundary_debug.png")
	tile_set.add_source(source, 0)
	source.create_tile(Vector2i.ZERO)
	_add_collision_rect(source.get_tile_data(Vector2i.ZERO, 0), Rect2(-16, -16, 32, 32))
	ResourceSaver.save(tile_set, BOUNDARY_PATH)


func _build_decoration_tileset() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	var source := TileSetAtlasSource.new()
	source.texture = load(
		"res://assets/art/scene/tileset/meadow/decoration_variants.png"
	)
	# The art stays 32 px so tufts retain their visual size, while the
	# TileMap grid is 16 px for half-cell placement.
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	tile_set.add_source(source, 0)
	for x in range(10):
		source.create_tile(Vector2i(x, 0))
		source.get_tile_data(Vector2i(x, 0), 0).probability = 1.0
	ResourceSaver.save(tile_set, DECORATION_PATH)


func _atlas_source(texture_path: String) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path)
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	return source


func _configure_connected_tiles(
	source: TileSetAtlasSource,
	terrain_set: int,
	full_collision: bool,
	fence_collision: bool
) -> void:
	for mask in range(16):
		var coords := Vector2i(mask, 0)
		source.create_tile(coords)
		var tile_data := source.get_tile_data(coords, 0)
		_set_terrain_bits(tile_data, terrain_set, mask)
		if full_collision:
			_add_collision_rect(tile_data, Rect2(-16, -16, 32, 32))
		elif fence_collision:
			_add_collision_rect(tile_data, Rect2(-5, -7, 10, 14))
			if mask & 1:
				_add_collision_rect(tile_data, Rect2(-3, -16, 6, 12))
			if mask & 2:
				_add_collision_rect(tile_data, Rect2(4, -3, 12, 6))
			if mask & 4:
				_add_collision_rect(tile_data, Rect2(-3, 4, 6, 12))
			if mask & 8:
				_add_collision_rect(tile_data, Rect2(-16, -3, 12, 6))


func _set_terrain_bits(tile_data: TileData, terrain_set: int, mask: int) -> void:
	tile_data.terrain_set = terrain_set
	tile_data.terrain = 0
	for side in SIDE_BITS:
		tile_data.set_terrain_peering_bit(side[1], 0 if mask & side[0] else -1)


func _add_collision_rect(tile_data: TileData, rect: Rect2) -> void:
	var polygon_index := tile_data.get_collision_polygons_count(0)
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(
		0,
		polygon_index,
		PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
	)


func _build_map_template() -> void:
	var root := _create_map_root("MapTemplate", "template", "地图模板")
	_create_map_structure(root)
	_save_scene(root, "res://scenes/maps/templates/map_template.tscn")


func _build_meadow_map() -> void:
	var root := _create_map_root("MapMeadow01", "meadow_01", "新绿原野")
	var nodes := _create_map_structure(root)
	_populate_meadow(root, nodes)
	_save_scene(root, "res://scenes/maps/manual/map_meadow_01.tscn")


func _create_map_root(node_name: String, id: String, display_name: String) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.script = MANUAL_LEVEL_SCRIPT
	root.set("map_id", id)
	root.set("map_name", display_name)
	root.add_to_group("level_root", true)
	root.set_meta("editor_description", "手工 TileMapLayer 地图。此场景不会被表格或脚本自动重建。")
	return root


func _create_map_structure(root: Node2D) -> Dictionary:
	var result := {}
	var tile_layers := Node2D.new()
	tile_layers.name = "TileLayers"
	_add_owned(root, tile_layers, root)

	var terrain: TileSet = load(TERRAIN_PATH)
	var environment: TileSet = load(ENVIRONMENT_PATH)
	var decorations: TileSet = load(DECORATION_PATH)
	var boundary: TileSet = load(BOUNDARY_PATH)
	for layer_data in [
		["GroundLayer", terrain, -100, false],
		["RoadLayer", terrain, -90, false],
		["WaterLayer", terrain, -80, false],
		["BridgeLayer", terrain, -70, false],
		["CliffLayer", terrain, -20, true],
		["DecorationLayer", decorations, -10, true],
		["TreeLayer", environment, 0, true],
		["BushLayer", environment, -5, true],
		["FenceLayer", environment, 2, true],
		["BoundaryLayer", boundary, 100, false],
	]:
		var layer := TileMapLayer.new()
		layer.name = layer_data[0]
		layer.tile_set = layer_data[1]
		layer.z_index = layer_data[2]
		layer.y_sort_enabled = layer_data[3]
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.navigation_enabled = false
		if layer.name == "BoundaryLayer":
			layer.visible = false
			layer.modulate = Color(1, 1, 1, 0.45)
		_add_owned(tile_layers, layer, root)
		result[layer.name] = layer

	var environment_root := Node2D.new()
	environment_root.name = "Environment"
	environment_root.y_sort_enabled = true
	_add_owned(root, environment_root, root)
	var houses := Node2D.new()
	houses.name = "Houses"
	houses.y_sort_enabled = true
	_add_owned(environment_root, houses, root)
	result["Houses"] = houses

	var gameplay := Node2D.new()
	gameplay.name = "Gameplay"
	gameplay.y_sort_enabled = true
	_add_owned(root, gameplay, root)
	for child_name in ["PlayerSpawns", "Chests", "Enemies", "Interactables", "Exits"]:
		var child := Node2D.new()
		child.name = child_name
		child.y_sort_enabled = true
		_add_owned(gameplay, child, root)
		result[child_name] = child

	for category in ["Normal", "Elite", "Boss"]:
		var category_node := Node2D.new()
		category_node.name = category
		category_node.y_sort_enabled = true
		_add_owned(result["Enemies"], category_node, root)
		result["Enemies" + category] = category_node

	var camera_bounds := Area2D.new()
	camera_bounds.name = "CameraBounds"
	camera_bounds.collision_layer = 0
	camera_bounds.collision_mask = 0
	camera_bounds.monitoring = false
	camera_bounds.monitorable = false
	camera_bounds.set_meta("editor_description", "选择矩形形状并拖动控制柄调整摄像机范围。")
	_add_owned(root, camera_bounds, root)
	var camera_shape_node := CollisionShape2D.new()
	camera_shape_node.name = "CollisionShape2D"
	var camera_shape := RectangleShape2D.new()
	camera_shape.size = Vector2(MAP_HALF_WIDTH * 2 * CELL_SIZE, MAP_HALF_HEIGHT * 2 * CELL_SIZE)
	camera_shape_node.shape = camera_shape
	_add_owned(camera_bounds, camera_shape_node, root)
	result["CameraBounds"] = camera_bounds
	return result


func _populate_meadow(root: Node2D, nodes: Dictionary) -> void:
	var ground := nodes["GroundLayer"] as TileMapLayer
	var road := nodes["RoadLayer"] as TileMapLayer
	var water := nodes["WaterLayer"] as TileMapLayer
	var bridge := nodes["BridgeLayer"] as TileMapLayer
	var cliff := nodes["CliffLayer"] as TileMapLayer
	var decoration := nodes["DecorationLayer"] as TileMapLayer
	var trees := nodes["TreeLayer"] as TileMapLayer
	var bushes := nodes["BushLayer"] as TileMapLayer
	var fences := nodes["FenceLayer"] as TileMapLayer
	var boundary := nodes["BoundaryLayer"] as TileMapLayer

	for y in range(-MAP_HALF_HEIGHT, MAP_HALF_HEIGHT):
		for x in range(-MAP_HALF_WIDTH, MAP_HALF_WIDTH):
			var variant := absi(x * 13 + y * 7 + x * y) % 8
			ground.set_cell(Vector2i(x, y), 0, Vector2i(variant, 0))

	for x in range(-MAP_HALF_WIDTH, MAP_HALF_WIDTH):
		boundary.set_cell(Vector2i(x, -MAP_HALF_HEIGHT), 0, Vector2i.ZERO)
		boundary.set_cell(Vector2i(x, MAP_HALF_HEIGHT - 1), 0, Vector2i.ZERO)
	for y in range(-MAP_HALF_HEIGHT + 1, MAP_HALF_HEIGHT - 1):
		boundary.set_cell(Vector2i(-MAP_HALF_WIDTH, y), 0, Vector2i.ZERO)
		boundary.set_cell(Vector2i(MAP_HALF_WIDTH - 1, y), 0, Vector2i.ZERO)

	var water_lookup := {}
	for y in range(-MAP_HALF_HEIGHT + 1, MAP_HALF_HEIGHT - 1):
		var progress := float(y + MAP_HALF_HEIGHT) / float(MAP_HALF_HEIGHT * 2)
		var center_x := roundi(lerpf(-13.0, 11.0, progress) + sin(y * 0.28) * 1.8)
		for offset in range(-2, 3):
			water_lookup[Vector2i(center_x + offset, y)] = true

	var bridge_y := 0
	var bridge_center_x := roundi(lerpf(-13.0, 11.0, 0.5))
	for x in range(bridge_center_x - 3, bridge_center_x + 4):
		water_lookup.erase(Vector2i(x, bridge_y))
		bridge.set_cell(Vector2i(x, bridge_y), 4, Vector2i(0, 0))

	var ford_y := 21
	var ford_progress := float(ford_y + MAP_HALF_HEIGHT) / float(MAP_HALF_HEIGHT * 2)
	var ford_x := roundi(lerpf(-13.0, 11.0, ford_progress) + sin(ford_y * 0.28) * 1.8)
	for x in range(ford_x - 2, ford_x + 3):
		water_lookup.erase(Vector2i(x, ford_y))

	var water_cells: Array[Vector2i] = []
	for cell in water_lookup:
		water_cells.append(cell)
	water.set_cells_terrain_connect(water_cells, 1, 0)

	var road_lookup := {}
	for segment in [
		[Vector2i(-40, 23), Vector2i(-23, 4)],
		[Vector2i(-23, 4), Vector2i(bridge_center_x, bridge_y)],
		[Vector2i(bridge_center_x, bridge_y), Vector2i(22, -5)],
		[Vector2i(22, -5), Vector2i(35, -20)],
		[Vector2i(22, -5), Vector2i(30, 18)],
		[Vector2i(30, 18), Vector2i(ford_x, ford_y)],
		[Vector2i(ford_x, ford_y), Vector2i(-30, 17)],
		[Vector2i(-30, 17), Vector2i(-40, 23)],
		[Vector2i(-23, 4), Vector2i(-34, -13)],
		[Vector2i(22, -5), Vector2i(7, -18)],
	]:
		for cell in _line_cells(segment[0], segment[1]):
			road_lookup[cell] = true
	var road_cells: Array[Vector2i] = []
	for cell in road_lookup:
		if not water_lookup.has(cell):
			road_cells.append(cell)
	road.set_cells_terrain_connect(road_cells, 0, 0)

	var cliff_lookup := {}
	for segment in [
		[Vector2i(19, -27), Vector2i(43, -27)],
		[Vector2i(43, -27), Vector2i(43, -12)],
		[Vector2i(27, -12), Vector2i(43, -12)],
	]:
		for cell in _line_cells(segment[0], segment[1]):
			cliff_lookup[cell] = true
	var cliff_cells: Array[Vector2i] = []
	for cell in cliff_lookup:
		cliff_cells.append(cell)
	cliff.set_cells_terrain_connect(cliff_cells, 2, 0)

	var fence_lookup := {}
	for x in range(-28, -16):
		fence_lookup[Vector2i(x, -4)] = true
		if x not in [-23, -22]:
			fence_lookup[Vector2i(x, 5)] = true
	for y in range(-3, 5):
		fence_lookup[Vector2i(-28, y)] = true
		fence_lookup[Vector2i(-17, y)] = true
	var fence_cells: Array[Vector2i] = []
	for cell in fence_lookup:
		fence_cells.append(cell)
	fences.set_cells_terrain_connect(fence_cells, 0, 0)

	var reserved := {}
	for cell in water_lookup:
		reserved[cell] = true
	for cell in road_lookup:
		reserved[cell] = true
	for cell in cliff_lookup:
		reserved[cell] = true
	for cell in fence_lookup:
		reserved[cell] = true
	for cell in [
		Vector2i(-40, 23), Vector2i(-22, 1), Vector2i(-32, 12),
		Vector2i(-12, -15), Vector2i(27, 13), Vector2i(36, -18),
		Vector2i(-27, 9), Vector2i(12, 8), Vector2i(26, -7),
		Vector2i(23, 10), Vector2i(33, -20), Vector2i(-35, -12),
	]:
		_reserved_area(reserved, cell, 3)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260801
	_scatter_scene_tiles(trees, 150, [0, 1, 2], reserved, rng, 1)
	_scatter_scene_tiles(bushes, 75, [3, 4], reserved, rng, 0)
	_scatter_decorations(decoration, 220, reserved, rng)

	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = _cell_position(Vector2i(-40, 23))
	spawn.set_meta("facing", "R")
	spawn.add_to_group("player_spawn", true)
	_add_owned(nodes["PlayerSpawns"], spawn, root)

	var house_scene: PackedScene = load("res://scenes/environment/meadow/meadow_house.tscn")
	var house := house_scene.instantiate()
	house.name = "MeadowHouse01"
	house.position = _cell_position(Vector2i(-22, 1))
	_add_scene_instance(nodes["Houses"], house, root)

	_add_chest(nodes["Chests"], root, "ChestRoadside", Vector2i(-32, 12), 1, "meadow_01_chest_01")
	_add_chest(nodes["Chests"], root, "ChestForest", Vector2i(-12, -15), 2, "meadow_01_chest_02")
	_add_chest(nodes["Chests"], root, "ChestElite", Vector2i(27, 13), 2, "meadow_01_chest_03")
	_add_chest(nodes["Chests"], root, "ChestBoss", Vector2i(36, -18), 2, "meadow_01_chest_04")

	_add_enemy(nodes["EnemiesNormal"], root, "BatWest", Vector2i(-27, 9), 1, "bat", "LR", 96.0, 70.0, "meadow_01_enemy_01")
	_add_enemy(nodes["EnemiesNormal"], root, "ChickenCrossing", Vector2i(12, 8), 2, "chicken_red", "UD", 96.0, 64.0, "meadow_01_enemy_02")
	_add_enemy(nodes["EnemiesNormal"], root, "BatEast", Vector2i(26, -7), 1, "bat", "RL", 128.0, 72.0, "meadow_01_enemy_03")
	_add_enemy(nodes["EnemiesNormal"], root, "ChickenNorth", Vector2i(-35, -12), 2, "chicken_red", "DU", 80.0, 60.0, "meadow_01_enemy_04")
	_add_enemy(nodes["EnemiesElite"], root, "EliteGuardian", Vector2i(23, 10), 2, "chicken_blonde_green", "LR", 96.0, 58.0, "meadow_01_elite_01", 2.6)
	_add_enemy(nodes["EnemiesBoss"], root, "MeadowBull", Vector2i(33, -20), 1000, "male_cow_brown", "NONE", 0.0, 0.0, "meadow_01_boss_01", 2.4)

	var exit := Marker2D.new()
	exit.name = "NorthwestExit"
	exit.position = _cell_position(Vector2i(-44, -26))
	exit.set_meta("target_map_id", "")
	_add_owned(nodes["Exits"], exit, root)
	var exit_sprite := Sprite2D.new()
	exit_sprite.name = "EditorIcon"
	exit_sprite.texture = load("res://assets/art/scene/tileset/meadow/exit_marker.png")
	exit_sprite.modulate = Color(1, 1, 1, 0.8)
	_add_owned(exit, exit_sprite, root)


func _scatter_scene_tiles(
	layer: TileMapLayer,
	count: int,
	alternatives: Array,
	reserved: Dictionary,
	rng: RandomNumberGenerator,
	clearance: int
) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 40:
		attempts += 1
		var cell := Vector2i(
			rng.randi_range(-MAP_HALF_WIDTH + 3, MAP_HALF_WIDTH - 4),
			rng.randi_range(-MAP_HALF_HEIGHT + 3, MAP_HALF_HEIGHT - 4)
		)
		if reserved.has(cell):
			continue
		var alternative: int = alternatives[rng.randi_range(0, alternatives.size() - 1)]
		layer.set_cell(cell, 2, Vector2i.ZERO, alternative)
		_reserved_area(reserved, cell, clearance)
		placed += 1


func _scatter_decorations(
	layer: TileMapLayer,
	count: int,
	reserved: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 20:
		attempts += 1
		var cell := Vector2i(
			rng.randi_range(-MAP_HALF_WIDTH + 2, MAP_HALF_WIDTH - 3),
			rng.randi_range(-MAP_HALF_HEIGHT + 2, MAP_HALF_HEIGHT - 3)
		)
		if reserved.has(cell):
			continue
		var fine_cell := cell * 2 + Vector2i(
			rng.randi_range(0, 1),
			rng.randi_range(0, 1)
		)
		if layer.get_cell_source_id(fine_cell) >= 0:
			continue
		layer.set_cell(fine_cell, 0, Vector2i(rng.randi_range(0, 9), 0))
		placed += 1


func _add_chest(
	parent: Node,
	root: Node,
	name_value: String,
	cell: Vector2i,
	loot_group_id: int,
	instance_id: String
) -> void:
	var scene: PackedScene = load("res://scenes/chest.tscn")
	var chest := scene.instantiate()
	chest.name = name_value
	chest.position = _cell_position(cell)
	chest.set("loot_group_id", loot_group_id)
	chest.set("container_instance_id", instance_id)
	_add_scene_instance(parent, chest, root)


func _add_enemy(
	parent: Node,
	root: Node,
	name_value: String,
	cell: Vector2i,
	enemy_id: int,
	animal_type: String,
	patrol_direction: String,
	patrol_distance: float,
	patrol_speed: float,
	instance_id: String,
	visual_scale: float = 2.0
) -> void:
	var scene: PackedScene = load("res://scenes/enemy.tscn")
	var enemy := scene.instantiate()
	enemy.name = name_value
	enemy.position = _cell_position(cell)
	enemy.set("enemy_id", enemy_id)
	enemy.set("animal_type", animal_type)
	enemy.set("patrol_direction", patrol_direction)
	enemy.set("patrol_distance", patrol_distance)
	enemy.set("patrol_speed", patrol_speed)
	enemy.set("map_object_id", instance_id)
	enemy.set("visual_scale", visual_scale)
	_add_scene_instance(parent, enemy, root)


func _line_cells(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var x0 := start.x
	var y0 := start.y
	var x1 := finish.x
	var y1 := finish.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var error := dx + dy
	while true:
		result.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var twice_error := 2 * error
		var next_x := x0
		var next_y := y0
		if twice_error >= dy:
			error += dy
			next_x += sx
		if twice_error <= dx:
			error += dx
			next_y += sy
		if next_x != x0 and next_y != y0:
			result.append(Vector2i(next_x, y0))
		x0 = next_x
		y0 = next_y
	return result


func _reserved_area(reserved: Dictionary, center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			reserved[Vector2i(x, y)] = true


func _cell_position(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE + Vector2.ONE * CELL_SIZE * 0.5


func _add_owned(parent: Node, child: Node, owner: Node) -> void:
	parent.add_child(child)
	child.owner = owner


func _add_scene_instance(parent: Node, child: Node, owner: Node) -> void:
	parent.add_child(child)
	child.owner = owner


func _save_scene(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		push_error("Unable to pack %s: %s" % [path, error_string(pack_error)])
		return
	var save_error := ResourceSaver.save(packed, path)
	if save_error != OK:
		push_error("Unable to save %s: %s" % [path, error_string(save_error)])
	root.free()
