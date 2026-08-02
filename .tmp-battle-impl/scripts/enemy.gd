extends Area2D

signal player_touched(enemy_id: int)

const ANIMAL_CONFIGS := {
	"bat": {
		"texture": preload("res://assets/art/character/animals/bat.png"),
		"frame_size": Vector2i(16, 24),
		"frame_count": 5,
		"row": 0,
		"fps": 10.0,
		"faces_right": true,
	},
	"male_cow_brown": {
		"texture": preload("res://assets/art/character/animals/male_cow_brown.png"),
		"frame_size": Vector2i(32, 32),
		"frame_count": 4,
		"row": 0,
		"fps": 7.0,
		"faces_right": false,
	},
	"female_cow_brown": {
		"texture": preload("res://assets/art/character/animals/female_cow_brown.png"),
		"frame_size": Vector2i(32, 32),
		"frame_count": 4,
		"row": 0,
		"fps": 7.0,
		"faces_right": false,
	},
	"chicken_red": {
		"texture": preload("res://assets/art/character/animals/chicken_red.png"),
		"frame_size": Vector2i(16, 16),
		"frame_count": 4,
		"row": 0,
		"fps": 8.0,
		"faces_right": false,
	},
	"chicken_blonde_green": {
		"texture": preload("res://assets/art/character/animals/chicken_blonde_green.png"),
		"frame_size": Vector2i(16, 16),
		"frame_count": 4,
		"row": 0,
		"fps": 8.0,
		"faces_right": false,
	},
	"baby_chicken_yellow": {
		"texture": preload("res://assets/art/character/animals/baby_chicken_yellow.png"),
		"frame_size": Vector2i(16, 16),
		"frame_count": 4,
		"row": 0,
		"fps": 8.0,
		"faces_right": false,
	},
}

@export_enum(
	"bat",
	"male_cow_brown",
	"female_cow_brown",
	"chicken_red",
	"chicken_blonde_green",
	"baby_chicken_yellow"
) var animal_type: String = "bat"
@export var enemy_id: int = 1
@export var patrol_distance: float = 80.0
@export var patrol_speed: float = 70.0
@export var visual_scale: float = 2.0
@export var animation_speed_scale: float = 1.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _origin_x: float
var _direction := 1.0
var _source_frames_face_right := true


func _ready() -> void:
	_origin_x = global_position.x
	_setup_animal_animation()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position.x += _direction * patrol_speed * delta
	if abs(position.x - _origin_x) >= patrol_distance:
		_direction *= -1.0
		_update_sprite_facing()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_touched.emit(enemy_id)


func _setup_animal_animation() -> void:
	var selected_type := animal_type
	if not ANIMAL_CONFIGS.has(selected_type):
		push_warning("Unknown enemy animal type '%s'; using bat." % selected_type)
		selected_type = "bat"

	var config: Dictionary = ANIMAL_CONFIGS[selected_type]
	var texture: Texture2D = config["texture"]
	var frame_size: Vector2i = config["frame_size"]
	var frame_count: int = config["frame_count"]
	var row: int = config["row"]
	_source_frames_face_right = bool(config["faces_right"])

	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	sprite_frames.add_animation(&"move")
	sprite_frames.set_animation_loop(&"move", true)
	sprite_frames.set_animation_speed(
		&"move",
		float(config["fps"]) * animation_speed_scale
	)

	for frame_index in frame_count:
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = texture
		frame_texture.region = Rect2(
			frame_index * frame_size.x,
			row * frame_size.y,
			frame_size.x,
			frame_size.y
		)
		sprite_frames.add_frame(&"move", frame_texture)

	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.scale = Vector2.ONE * visual_scale
	_update_sprite_facing()
	animated_sprite.play(&"move")


func _update_sprite_facing() -> void:
	var moving_right := _direction > 0.0
	animated_sprite.flip_h = moving_right != _source_frames_face_right
