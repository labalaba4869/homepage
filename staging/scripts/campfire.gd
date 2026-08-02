extends Node2D

@onready var fire_light: PointLight2D = %FireLight

var _elapsed := 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	var pulse := sin(_elapsed * 7.0) * 0.11 + sin(_elapsed * 13.0) * 0.05
	fire_light.energy = 1.32 + pulse
	fire_light.scale = Vector2.ONE * (1.0 + pulse * 0.08)
