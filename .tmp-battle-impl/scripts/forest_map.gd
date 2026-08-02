@tool
extends Node2D

const MAP_SIZE := Vector2i(1536, 1024)
const HALF_SIZE := Vector2(768, 512)
const TILE_SIZE := 16

const GRASS_BACKGROUND := preload(
	"res://assets/art/scene/world/grass_background.png"
)
const DIRT_TILESET := preload(
	"res://assets/art/scene/world/dirt_tileset.png"
)
const TREE_TEXTURE := preload("res://assets/art/scene/world/tree.png")
const MAPLE_TEXTURE := preload("res://assets/art/scene/world/maple_tree.png")
const BUSH_TEXTURE := preload("res://assets/art/scene/world/bush.png")
const GRASS_TEXTURE := preload("res://assets/art/scene/world/grass.png")
const HOUSE_TEXTURE := preload("res://assets/art/scene/world/house.png")
const ROAD_DECOR_TEXTURE := preload("res://assets/art/scene/world/road.png")
const MEDIUM_SHADOW := preload(
	"res://assets/art/scene/shadows/medium_shadow.png"
)
const LARGE_SHADOW := preload(
	"res://assets/art/scene/shadows/large_shadow.png"
)

const TREE_POSITIONS := [
	Vector2(-704, -448), Vector2(-624, -464), Vector2(-544, -452),
	Vector2(-464, -466), Vector2(-384, -448), Vector2(-304, -466),
	Vector2(-224, -450), Vector2(-144, -466), Vector2(-64, -452),
	Vector2(16, -466), Vector2(96, -450), Vector2(336, -454),
	Vector2(416, -466), Vector2(496, -450), Vector2(576, -466),
	Vector2(656, -448), Vector2(720, -390), Vector2(704, -300),
	Vector2(720, -210), Vector2(704, -104), Vector2(720, 8),
	Vector2(704, 296), Vector2(720, 392), Vector2(656, 458),
	Vector2(576, 446), Vector2(496, 462), Vector2(416, 448),
	Vector2(336, 464), Vector2(256, 448), Vector2(176, 464),
	Vector2(96, 448), Vector2(16, 464), Vector2(-64, 448),
	Vector2(-144, 464), Vector2(-224, 448), Vector2(-304, 464),
	Vector2(-384, 448), Vector2(-464, 464), Vector2(-544, 448),
	Vector2(-624, 464), Vector2(-704, 448), Vector2(-720, 360),
	Vector2(-704, 272), Vector2(-720, 64), Vector2(-704, -32),
	Vector2(-720, -128), Vector2(-704, -224), Vector2(-720, -320),
	Vector2(-624, -330), Vector2(-560, -280), Vector2(-620, -220),
	Vector2(-548, -174), Vector2(-156, -330), Vector2(-96, -286),
	Vector2(-132, -220), Vector2(356, -354), Vector2(430, -320),
	Vector2(594, -340), Vector2(650, -270), Vector2(388, 300),
	Vector2(452, 350), Vector2(520, 390), Vector2(620, 350),
]

const BUSH_POSITIONS := [
	Vector2(-654, -250), Vector2(-586, -206), Vector2(-520, -338),
	Vector2(-188, -282), Vector2(-110, -250), Vector2(-640, 318),
	Vector2(-520, 380), Vector2(-360, 376), Vector2(-96, 356),
	Vector2(356, -282), Vector2(620, -214), Vector2(410, 252),
	Vector2(520, 300), Vector2(644, 270), Vector2(680, 92),
]

const GRASS_POSITIONS := [
	Vector2(-650, 18), Vector2(-590, 82), Vector2(-520, -72),
	Vector2(-470, 286), Vector2(-418, 332), Vector2(-338, 290),
	Vector2(-270, 30), Vector2(-220, 280), Vector2(-156, 52),
	Vector2(-84, -176), Vector2(-36, 320), Vector2(34, -292),
	Vector2(54, 260), Vector2(330, -180), Vector2(370, 52),
	Vector2(418, -114), Vector2(472, 268), Vector2(548, 48),
	Vector2(620, -70), Vector2(654, 190),
]

var _generated: Node2D
var _wave_lines: Array[Line2D] = []
var _wave_time := 0.0


func _ready() -> void:
	_build_map()
	set_process(true)


func _process(delta: float) -> void:
	_wave_time += delta
	for index in _wave_lines.size():
		var line := _wave_lines[index]
		line.position.x = sin(_wave_time * 1.4 + float(index)) * 5.0


func _build_map() -> void:
	var old_generated := get_node_or_null("Generated")
	if old_generated:
		old_generated.queue_free()

	_generated = Node2D.new()
	_generated.name = "Generated"
	_generated.y_sort_enabled = true
	add_child(_generated)

	_add_ground()
	_add_river()
	_add_roads()
	_add_bridge()
	_add_landmarks()
	_add_forest()
	_add_foliage()
	_add_road_details()
	_add_map_collisions()


func _add_ground() -> void:
	var fallback := Polygon2D.new()
	fallback.name = "GroundColor"
	fallback.polygon = _rect_polygon(
		Rect2(-HALF_SIZE, Vector2(MAP_SIZE))
	)
	fallback.color = Color("3f7c46")
	fallback.z_index = -110
	_generated.add_child(fallback)

	var ground := Sprite2D.new()
	ground.name = "GrassGround"
	ground.texture = GRASS_BACKGROUND
	ground.region_enabled = true
	ground.region_rect = Rect2(Vector2.ZERO, Vector2(MAP_SIZE))
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.z_index = -100
	_generated.add_child(ground)


func _add_river() -> void:
	var bank := Polygon2D.new()
	bank.name = "RiverBank"
	bank.polygon = PackedVector2Array([
		Vector2(70, -512), Vector2(292, -512), Vector2(280, -414),
		Vector2(310, -326), Vector2(282, -222), Vector2(302, -118),
		Vector2(276, -20), Vector2(304, 92), Vector2(284, 198),
		Vector2(308, 304), Vector2(282, 410), Vector2(298, 512),
		Vector2(58, 512), Vector2(70, 410), Vector2(46, 310),
		Vector2(72, 202), Vector2(42, 100), Vector2(66, 0),
		Vector2(42, -104), Vector2(68, -224), Vector2(44, -332),
		Vector2(66, -420),
	])
	bank.color = Color("76543b")
	bank.z_index = -82
	_generated.add_child(bank)

	var water := Polygon2D.new()
	water.name = "RiverWater"
	water.polygon = PackedVector2Array([
		Vector2(92, -512), Vector2(270, -512), Vector2(258, -410),
		Vector2(286, -324), Vector2(258, -220), Vector2(280, -118),
		Vector2(254, -18), Vector2(282, 92), Vector2(260, 198),
		Vector2(286, 304), Vector2(260, 410), Vector2(276, 512),
		Vector2(80, 512), Vector2(92, 410), Vector2(68, 310),
		Vector2(94, 202), Vector2(64, 100), Vector2(88, 0),
		Vector2(64, -104), Vector2(90, -224), Vector2(66, -332),
		Vector2(88, -420),
	])
	water.color = Color("26758c")
	water.z_index = -80
	_generated.add_child(water)

	var wave_specs := [
		[Vector2(112, -370), Vector2(202, -370)],
		[Vector2(154, -270), Vector2(248, -270)],
		[Vector2(104, -154), Vector2(214, -154)],
		[Vector2(142, -42), Vector2(252, -42)],
		[Vector2(100, 270), Vector2(210, 270)],
		[Vector2(146, 386), Vector2(246, 386)],
	]
	for spec in wave_specs:
		var wave := Line2D.new()
		wave.points = PackedVector2Array([spec[0], spec[1]])
		wave.width = 3.0
		wave.default_color = Color(0.55, 0.9, 0.92, 0.55)
		wave.z_index = -79
		_generated.add_child(wave)
		_wave_lines.append(wave)


func _add_roads() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var source := TileSetAtlasSource.new()
	source.texture = DIRT_TILESET
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for atlas_y in 3:
		for atlas_x in 3:
			source.create_tile(Vector2i(atlas_x, atlas_y))
	tile_set.add_source(source, 0)

	var road := TileMapLayer.new()
	road.name = "Roads"
	road.tile_set = tile_set
	road.z_index = -40
	_generated.add_child(road)

	var cells := {}
	for cell_x in range(-47, 48):
		for cell_y in range(7, 13):
			cells[Vector2i(cell_x, cell_y)] = true
	for cell_x in range(-27, -21):
		for cell_y in range(-17, 8):
			cells[Vector2i(cell_x, cell_y)] = true
	for cell_x in range(29, 35):
		for cell_y in range(-15, 8):
			cells[Vector2i(cell_x, cell_y)] = true

	for cell in cells:
		var north := cells.has(cell + Vector2i.UP)
		var south := cells.has(cell + Vector2i.DOWN)
		var west := cells.has(cell + Vector2i.LEFT)
		var east := cells.has(cell + Vector2i.RIGHT)
		var atlas := Vector2i(1, 1)

		if not north:
			atlas.y = 0
		elif not south:
			atlas.y = 2
		if not west:
			atlas.x = 0
		elif not east:
			atlas.x = 2

		road.set_cell(cell, 0, atlas)


func _add_bridge() -> void:
	var bridge := Node2D.new()
	bridge.name = "Bridge"
	bridge.z_index = -24
	_generated.add_child(bridge)

	var deck := Polygon2D.new()
	deck.polygon = _rect_polygon(Rect2(56, 108, 256, 104))
	deck.color = Color("8f5f3b")
	bridge.add_child(deck)

	for plank_x in range(64, 305, 16):
		var plank_line := Line2D.new()
		plank_line.points = PackedVector2Array([
			Vector2(plank_x, 114), Vector2(plank_x, 206)
		])
		plank_line.width = 2.0
		plank_line.default_color = Color("503624")
		bridge.add_child(plank_line)

	for rail_y in [114.0, 206.0]:
		var rail := Line2D.new()
		rail.points = PackedVector2Array([
			Vector2(52, rail_y), Vector2(316, rail_y)
		])
		rail.width = 6.0
		rail.default_color = Color("4b3021")
		bridge.add_child(rail)


func _add_landmarks() -> void:
	_add_house(Vector2(-392, -242), Rect2(0, 0, 80, 96), "WestHouse")
	_add_house(Vector2(504, -210), Rect2(144, 0, 80, 112), "EastHouse")


func _add_house(
	map_position: Vector2,
	atlas_region: Rect2,
	house_name: String
) -> void:
	var body := StaticBody2D.new()
	body.name = house_name
	body.position = map_position
	_generated.add_child(body)

	var shadow := Sprite2D.new()
	shadow.texture = LARGE_SHADOW
	shadow.scale = Vector2(5.0, 2.4)
	shadow.position = Vector2(0, -2)
	shadow.modulate = Color(1, 1, 1, 0.65)
	shadow.z_index = -1
	body.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.texture = _atlas_texture(HOUSE_TEXTURE, atlas_region)
	sprite.scale = Vector2(2, 2)
	sprite.position = Vector2(0, -atlas_region.size.y + 8)
	body.add_child(sprite)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(132, 44)
	collision.shape = shape
	collision.position = Vector2(0, -16)
	body.add_child(collision)


func _add_forest() -> void:
	for index in TREE_POSITIONS.size():
		_add_tree(TREE_POSITIONS[index], index % 5 == 2)


func _add_tree(map_position: Vector2, use_maple: bool) -> void:
	var body := StaticBody2D.new()
	body.name = "MapleTree" if use_maple else "PineTree"
	body.position = map_position
	_generated.add_child(body)

	var shadow := Sprite2D.new()
	shadow.texture = MEDIUM_SHADOW
	shadow.scale = Vector2(2.8, 1.6)
	shadow.position = Vector2(0, 2)
	shadow.modulate = Color(1, 1, 1, 0.58)
	shadow.z_index = -1
	body.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.texture = (
		_atlas_texture(MAPLE_TEXTURE, Rect2(96, 0, 32, 48))
		if use_maple
		else TREE_TEXTURE
	)
	sprite.scale = Vector2(2, 2)
	sprite.position = Vector2(0, -40)
	body.add_child(sprite)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 18)
	collision.shape = shape
	collision.position = Vector2(0, -3)
	body.add_child(collision)


func _add_foliage() -> void:
	for bush_position in BUSH_POSITIONS:
		var bush := Sprite2D.new()
		bush.name = "Bush"
		bush.texture = BUSH_TEXTURE
		bush.scale = Vector2(2, 2)
		bush.position = bush_position
		_generated.add_child(bush)

	for grass_position in GRASS_POSITIONS:
		var grass := Sprite2D.new()
		grass.name = "GrassTuft"
		grass.texture = GRASS_TEXTURE
		grass.scale = Vector2(2, 2)
		grass.position = grass_position
		grass.z_index = -2
		_generated.add_child(grass)


func _add_road_details() -> void:
	var detail_specs := [
		[Vector2(-650, 96), Rect2(0, 0, 16, 16)],
		[Vector2(-520, 226), Rect2(16, 0, 16, 16)],
		[Vector2(-180, 92), Rect2(32, 0, 16, 16)],
		[Vector2(360, 226), Rect2(0, 16, 16, 16)],
		[Vector2(600, 96), Rect2(16, 16, 16, 16)],
		[Vector2(-448, -88), Rect2(0, 32, 16, 16)],
		[Vector2(552, -62), Rect2(16, 32, 16, 16)],
	]
	for spec in detail_specs:
		var detail := Sprite2D.new()
		detail.name = "RoadStones"
		detail.texture = _atlas_texture(ROAD_DECOR_TEXTURE, spec[1])
		detail.scale = Vector2(2, 2)
		detail.position = spec[0]
		detail.z_index = -20
		_generated.add_child(detail)


func _add_map_collisions() -> void:
	var collisions := Node2D.new()
	collisions.name = "MapCollisions"
	_generated.add_child(collisions)

	_add_rect_collision(
		collisions, "NorthBoundary", Vector2(0, -512), Vector2(1536, 32)
	)
	_add_rect_collision(
		collisions, "SouthBoundary", Vector2(0, 512), Vector2(1536, 32)
	)
	_add_rect_collision(
		collisions, "WestBoundary", Vector2(-768, 0), Vector2(32, 1024)
	)
	_add_rect_collision(
		collisions, "EastBoundary", Vector2(768, 0), Vector2(32, 1024)
	)
	_add_rect_collision(
		collisions, "UpperRiver", Vector2(180, -200), Vector2(226, 624)
	)
	_add_rect_collision(
		collisions, "LowerRiver", Vector2(180, 360), Vector2(226, 304)
	)


func _add_rect_collision(
	parent: Node,
	body_name: String,
	body_position: Vector2,
	body_size: Vector2
) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.position = body_position
	parent.add_child(body)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = body_size
	collision.shape = shape
	body.add_child(collision)


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
