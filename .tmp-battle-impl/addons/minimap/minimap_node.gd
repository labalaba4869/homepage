@tool
extends SubViewportContainer
class_name MiniMap

var sub_viewport: SubViewport
var border: Line2D
var placeholder: ColorRect
var camera_2d: Camera2D 
var marker: Sprite2D
@onready var sub_viewport_container: SubViewportContainer = $"."

@export var zoom: float = 0.5:
	set(value):
		zoom = value
		if camera_2d:
			camera_2d.zoom = Vector2(zoom, zoom)

@export var window_size: Vector2i = Vector2i(256,128):
	set(value):
		window_size = value
		if sub_viewport:
			sub_viewport.size = window_size
			update_border()
@export var hide_layer2:bool=false
			
@export var target:Node2D
@export var hide_marker:=false
@export var marker_image:Texture2D:
	set(value):
		marker_image=value
		if marker:
			marker.texture=marker_image
@export var marker_scale:Vector2=Vector2(1,1):
	set(value):
		marker_scale=value
		if marker:
			marker.scale=marker_scale
			
@export var border_line_color:Color=Color.BLACK:
	set(value):
		border_line_color = value
		if border:
			border.default_color = border_line_color

@export var frame_image:PackedScene:
	set(value):
		frame_image = value
		if frame_image:
			# Create an instance of the NinePatchRect scene
			var fameimage = frame_image.instantiate() 
			if fameimage is NinePatchRect and sub_viewport:
				add_child(fameimage)
				fameimage.custom_minimum_size=Vector2(sub_viewport.size.x,sub_viewport.size.y)
	
# Called when the node enters the scene tree for the first time.
func setup():
	if sub_viewport: return  # prevent duplicates

	sub_viewport = SubViewport.new()
	add_child(sub_viewport)

	camera_2d = Camera2D.new()
	sub_viewport.add_child(camera_2d)

	marker = Sprite2D.new()
	add_child(marker)

	border = Line2D.new()
	add_child(border)

	placeholder = ColorRect.new()
	add_child(placeholder)
	
func _enter_tree():
	if Engine.is_editor_hint():
		setup()
		
func _ready() -> void:
	## iniating everything:
	setup()
	

	sub_viewport.size=window_size
	marker.texture=marker_image
	if marker_scale and marker_scale != Vector2.ZERO:
		marker.scale=marker_scale
	placeholder.hide()
	camera_2d.zoom=(Vector2(zoom,zoom))

	border.default_color=border_line_color
	border.add_point(Vector2(2.5,2.5))
	border.add_point(Vector2(sub_viewport.size.x-2.5,2.5))
	border.add_point(Vector2(sub_viewport.size.x-2.5,sub_viewport.size.y-2.5))
	border.add_point(Vector2(2.5,sub_viewport.size.y-2.5))
	border.add_point(Vector2(2.5,0))

	marker.position=Vector2(sub_viewport.size.x/2,sub_viewport.size.y/2)
	
	if hide_layer2:
		sub_viewport.set_canvas_cull_mask_bit(1,false)
		
	if frame_image:
		# Create an instance of the NinePatchRect scene
		var fameimage = frame_image.instantiate() 
		if fameimage is NinePatchRect:
			add_child(fameimage)
			fameimage.custom_minimum_size=Vector2(sub_viewport.size.x,sub_viewport.size.y)
	sub_viewport.world_2d=get_tree().root.world_2d

# Called every frame. 'delta' is the elapsed time since the previous frame.
func update_border():
	if not border: return

	border.clear_points()
	border.default_color = border_line_color

	border.add_point(Vector2(2.5,2.5))
	border.add_point(Vector2(window_size.x-2.5,2.5))
	border.add_point(Vector2(window_size.x-2.5,window_size.y-2.5))
	border.add_point(Vector2(2.5,window_size.y-2.5))
	border.add_point(Vector2(2.5,2.5))

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
	if target:
		camera_2d.position=target.position
