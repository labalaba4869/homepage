@tool
class_name GeneratedLevel
extends Node2D

const GRASS_TEXTURE := preload(
	"res://assets/art/scene/world/grass_background.png"
)
const DIRT_TEXTURE := preload("res://assets/art/scene/world/dirt_tileset.png")
const TREE_TEXTURE := preload("res://assets/art/scene/world/tree.png")
const BUSH_TEXTURE := preload("res://assets/art/scene/world/bush.png")
const GRASS_DECOR_TEXTURE := preload("res://assets/art/scene/world/grass.png")
const HOUSE_TEXTURE := preload("res://assets/art/scene/world/house.png")
const FENCE_TEXTURE := preload("res://assets/art/scene/world/fences.png")
const MEDIUM_SHADOW := preload(
	"res://assets/art/scene/shadows/medium_shadow.png"
)
const LARGE_SHADOW := preload(
	"res://assets/art/scene/shadows/large_shadow.png"
)

@export var map_id := ""
@export var map_name := ""
@export var map_width := 1
@export var map_height := 1
@export var cell_size := 32
@export_file("*.json") var data_path := ""

var _data: Dictionary = {}
var _build_queued := false


func _ready() -> void:
	_queue_rebuild()


func get_map_rect() -> Rect2:
	var size := Vector2(map_width * cell_size, map_height * cell_size)
	return Rect2(-size * 0.5, size)


func get_spawn_position() -> Vector2:
	var spawn := get_node_or_null("Gameplay/PlayerSpawn") as Marker2D
	return spawn.global_position if spawn else Vector2.ZERO


func get_spawn_facing() -> String:
	var spawn := get_node_or_null("Gameplay/PlayerSpawn") as Marker2D
	return str(spawn.get_meta("facing", "D")) if spawn else "D"


func _queue_rebuild() -> void:
	if _build_queued:
		return
	_build_queued = true
	call_deferred("_rebuild")


func _rebuild() -> void:
	_build_queued = false
	if data_path.is_empty() or not FileAccess.file_exists(data_path):
		push_warning("Generated level data is missing: %s" % data_path)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("Generated level data is invalid JSON: %s" % data_path)
		return
	_data = parsed
	_clear_generated_children()
	_build_terrain()
	_build_environment()
	_build_terrain_collisions()


func _clear_generated_children() -> void:
	for path in [
		"Terrain/GroundLayer",
		"Terrain/RoadLayer",
		"Terrain/WaterLayer",
		"Terrain/BridgeLayer",
		"Environment/Trees",
		"Environment/Bushes",
		"Environment/GrassDecorations",
		"Environment/Houses",
		"Environment/RegionBoundaries",
		"Collisions/MapBoundary",
		"Collisions/WaterCollision",
		"Collisions/PropCollision",
		"Collisions/RegionBoundaryCollision",
	]:
		var container := get_node_or_null(path)
		if container:
			for child in container.get_children():
				child.free()


func _build_terrain() -> void:
	var positions := {
		"G": [],
		"W": [],
	}
	var grid: Array = _data.get("grid", [])
	for y in range(grid.size()):
		var row: Array = grid[y]
		for x in range(row.size()):
			var terrain := str(row[x]).split(";", false, 1)[0]
			var position := _cell_center(x, y)
			match terrain:
				"G":
					positions["G"].append(position)
				"W":
					positions["W"].append(position)
				"R":
					_add_road_cell(position)
				"BR":
					_add_bridge_cell(position)

	_add_cell_multimesh(
		$Terrain/GroundLayer,
		"GrassCells",
		positions["G"],
		GRASS_TEXTURE,
		Color.WHITE,
		-100
	)
	_add_cell_multimesh(
		$Terrain/WaterLayer,
		"WaterCells",
		positions["W"],
		null,
		Color("26758c"),
		-80
	)


func _add_cell_multimesh(
	parent: Node2D,
	node_name: String,
	positions: Array,
	texture: Texture2D,
	color: Color,
	z: int
) -> void:
	if positions.is_empty():
		return
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * cell_size
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()
	for index in range(positions.size()):
		multimesh.set_instance_transform_2d(
			index,
			Transform2D(0.0, positions[index])
		)
		multimesh.set_instance_color(index, color)
	var instance := MultiMeshInstance2D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.texture = texture
	instance.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	instance.z_index = z
	parent.add_child(instance)


func _add_road_cell(position: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "RoadCell"
	sprite.position = position
	sprite.texture = _atlas_texture(DIRT_TEXTURE, Rect2(16, 16, 16, 16))
	sprite.scale = Vector2(2, 2)
	sprite.z_index = -60
	$Terrain/RoadLayer.add_child(sprite)


func _add_bridge_cell(position: Vector2) -> void:
	var deck := Polygon2D.new()
	deck.name = "BridgeCell"
	deck.position = position
	deck.polygon = _rect_polygon(
		Rect2(Vector2.ONE * -cell_size * 0.5, Vector2.ONE * cell_size)
	)
	deck.color = Color("9a6841")
	deck.z_index = -40
	$Terrain/BridgeLayer.add_child(deck)
	for offset in [-10.0, 0.0, 10.0]:
		var plank := Line2D.new()
		plank.points = PackedVector2Array([
			Vector2(-cell_size * 0.5, offset),
			Vector2(cell_size * 0.5, offset),
		])
		plank.width = 2.0
		plank.default_color = Color("533722")
		deck.add_child(plank)


func _build_environment() -> void:
	var placements: Array = _data.get("placements", [])
	for placement_value in placements:
		if not placement_value is Dictionary:
			continue
		var placement: Dictionary = placement_value
		var code := str(placement.get("code", ""))
		match code:
			"T":
				_add_tree(placement)
			"BU":
				_add_foliage(placement, BUSH_TEXTURE, $Environment/Bushes, "Bush")
			"GT":
				_add_foliage(
					placement,
					GRASS_DECOR_TEXTURE,
					$Environment/GrassDecorations,
					"GrassTuft"
				)
			"H1", "H2":
				_add_house(placement, code)
			"RB":
				_add_region_boundary(placement)


func _add_tree(placement: Dictionary) -> void:
	var body := StaticBody2D.new()
	body.name = "Tree_%d_%d" % [placement["x"], placement["y"]]
	body.position = _placement_bottom_center(placement)
	$Environment/Trees.add_child(body)

	var shadow := Sprite2D.new()
	shadow.texture = MEDIUM_SHADOW
	shadow.scale = Vector2(2.8, 1.6)
	shadow.modulate = Color(1, 1, 1, 0.58)
	shadow.z_index = -1
	body.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.texture = TREE_TEXTURE
	sprite.scale = Vector2(2, 2)
	sprite.position = Vector2(0, -48)
	body.add_child(sprite)
	_add_shape(body, Vector2(24, 18), Vector2(0, -4))


func _add_foliage(
	placement: Dictionary,
	texture: Texture2D,
	parent: Node2D,
	node_name: String
) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "%s_%d_%d" % [node_name, placement["x"], placement["y"]]
	sprite.position = _placement_center(placement)
	sprite.texture = texture
	sprite.scale = Vector2(2, 2)
	sprite.z_index = -2
	parent.add_child(sprite)


func _add_house(placement: Dictionary, code: String) -> void:
	var body := StaticBody2D.new()
	body.name = "%s_%d_%d" % [code, placement["x"], placement["y"]]
	body.position = _placement_bottom_center(placement)
	$Environment/Houses.add_child(body)
	var region := Rect2(0, 0, 80, 96) if code == "H1" else Rect2(144, 0, 80, 112)

	var shadow := Sprite2D.new()
	shadow.texture = LARGE_SHADOW
	shadow.scale = Vector2(5.0, 2.4)
	shadow.position = Vector2(0, -16)
	shadow.modulate = Color(1, 1, 1, 0.65)
	shadow.z_index = -1
	body.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.texture = _atlas_texture(HOUSE_TEXTURE, region)
	sprite.scale = Vector2(2, 2)
	sprite.position = Vector2(0, -region.size.y)
	body.add_child(sprite)
	_add_shape(body, Vector2(132, 44), Vector2(0, -22))


func _add_region_boundary(placement: Dictionary) -> void:
	var body := StaticBody2D.new()
	body.name = "Fence_%d_%d" % [placement["x"], placement["y"]]
	body.position = _placement_center(placement)
	$Environment/RegionBoundaries.add_child(body)
	var sprite := Sprite2D.new()
	sprite.texture = _atlas_texture(FENCE_TEXTURE, Rect2(16, 0, 16, 16))
	sprite.scale = Vector2(2, 2)
	body.add_child(sprite)
	_add_shape(body, Vector2(cell_size, 12), Vector2.ZERO)


func _build_terrain_collisions() -> void:
	var grid: Array = _data.get("grid", [])
	var boundary_cells := {}
	var water_cells := {}
	for y in range(grid.size()):
		var row: Array = grid[y]
		for x in range(row.size()):
			var terrain := str(row[x]).split(";", false, 1)[0]
			if terrain == "X":
				boundary_cells[Vector2i(x, y)] = true
			elif terrain == "W":
				water_cells[Vector2i(x, y)] = true
	_add_merged_collisions($Collisions/MapBoundary, boundary_cells, "Boundary")
	_add_merged_collisions($Collisions/WaterCollision, water_cells, "Water")


func _add_merged_collisions(
	parent: Node2D,
	cells: Dictionary,
	prefix: String
) -> void:
	var remaining := cells.duplicate()
	var index := 0
	while not remaining.is_empty():
		var start: Vector2i = remaining.keys()[0]
		var width := 1
		while remaining.has(start + Vector2i(width, 0)):
			width += 1
		var height := 1
		while true:
			var next_row_valid := true
			for offset_x in range(width):
				if not remaining.has(start + Vector2i(offset_x, height)):
					next_row_valid = false
					break
			if not next_row_valid:
				break
			height += 1
		for offset_y in range(height):
			for offset_x in range(width):
				remaining.erase(start + Vector2i(offset_x, offset_y))
		index += 1
		var body := StaticBody2D.new()
		body.name = "%s_%d" % [prefix, index]
		body.position = Vector2(
			(start.x + width * 0.5) * cell_size - map_width * cell_size * 0.5,
			(start.y + height * 0.5) * cell_size - map_height * cell_size * 0.5
		)
		parent.add_child(body)
		_add_shape(
			body,
			Vector2(width * cell_size, height * cell_size),
			Vector2.ZERO
		)


func _add_shape(parent: StaticBody2D, size: Vector2, offset: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = offset
	parent.add_child(collision)


func _cell_center(x: int, y: int) -> Vector2:
	return Vector2(
		(x + 0.5) * cell_size - map_width * cell_size * 0.5,
		(y + 0.5) * cell_size - map_height * cell_size * 0.5
	)


func _placement_center(placement: Dictionary) -> Vector2:
	return Vector2(
		(float(placement["x"]) + float(placement.get("width", 1)) * 0.5)
			* cell_size - map_width * cell_size * 0.5,
		(float(placement["y"]) + float(placement.get("height", 1)) * 0.5)
			* cell_size - map_height * cell_size * 0.5
	)


func _placement_bottom_center(placement: Dictionary) -> Vector2:
	return Vector2(
		(float(placement["x"]) + float(placement.get("width", 1)) * 0.5)
			* cell_size - map_width * cell_size * 0.5,
		(float(placement["y"]) + float(placement.get("height", 1)))
			* cell_size - map_height * cell_size * 0.5
	)


func _atlas_texture(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	])
