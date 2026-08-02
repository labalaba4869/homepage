extends SceneTree

func _init() -> void:
	print("Render preview script initialized")
	root.size = Vector2i(1280, 720)
	var scene: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(scene)
	_capture.call_deferred()


func _capture() -> void:
	for _frame in range(20):
		await process_frame
	var image := root.get_texture().get_image()
	var result := image.save_png(
		"D:/Homepage Dev/level-converter-work/world_preview.png"
	)
	print("Preview save result: ", result, " size=", image.get_size())
	quit()
