extends Control


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var image := get_viewport().get_texture().get_image()
	image.save_png(
		"D:/Homepage Dev/.tmp-battle-impl/battle-preview.png"
	)
	get_tree().quit()
