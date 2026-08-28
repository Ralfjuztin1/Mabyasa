class_name SpeechBubble3D extends Node3D

## Size in pixels for word wrapping.
@export var wrap_size : float = 300.0

## Time to fade in and out.
@export var fade_duration : float = 0.2

## speed that letters appear, 0.0 for all at once.
@export var text_speed : float = 0.02

## color of letters
@export var text_color : Color = Color(0.0, 0.0, 0.0):
	set(c):
		text_color = c
		if label_settings != null:
			label_settings.font_color = c

@export var text_font : Font = null:
	set(f):
		text_font = f;
		if label_settings != null:
			label_settings.font = f

@export var text_size : int = 16:
	set(s):
		text_size = s;
		if label_settings != null:
			label_settings.font_size = s

## text to display
@export var text : String = ""

## Add an area3d to detect a player and enable and disable on entering the area
@export var use_detector : bool = true
@export var detector_radius : float = 3.0

## Layer number of bubble.
## Larger layer displayed in front of lower.
@export var layer : int = 1:
	set(new_value):
		layer = new_value
		$CanvasLayer.layer = layer
#---------------------------------------------------------------------------------------------------

var fade_out_time : float = 0.0
var fade_in_time : float = 0.0
var letter_time : float = 0.0
var speech_text : String
var current_letter : int
var label_settings : LabelSettings
var text_extent : Vector2
var life_time : float = 0.0
var current_life : float = 0.0

var visiblity_node : CanvasLayer
var player_detector
var speech_label : Label
var bubble_pic_left : NinePatchRect
var bubble_pic_right : NinePatchRect
var speech_container : BoxContainer
var transparency_node : CanvasModulate
var margin_node : MarginContainer
#---------------------------------------------------------------------------------------------------

func _ready() -> void:
	var scene : PackedScene = preload("res://addons/speechbubble3d/canvas_layer.tscn")
	var detector: PackedScene = preload("res://addons/speechbubble3d/detector.tscn")
	visiblity_node = scene.instantiate()
	add_child(visiblity_node)
	if use_detector:
		player_detector = detector.instantiate()
		add_child(player_detector)
		player_detector.set_radius(detector_radius)
	
	speech_label = get_node("CanvasLayer/CanvasModulate/ResizeContainer/EncloseContainer/TextMargin/Text")
	bubble_pic_left = get_node("CanvasLayer/CanvasModulate/ResizeContainer/EncloseContainer/BubblePicLeft")
	bubble_pic_right = get_node("CanvasLayer/CanvasModulate/ResizeContainer/EncloseContainer/BubblePicRight")
	speech_container = get_node("CanvasLayer/CanvasModulate/ResizeContainer")
	transparency_node = get_node("CanvasLayer/CanvasModulate")
	margin_node = get_node("CanvasLayer/CanvasModulate/ResizeContainer/EncloseContainer/TextMargin")
	
	bubble_pic_left.texture = preload("res://addons/speechbubble3d/speech_bubble.png")
	bubble_pic_right.texture = preload("res://addons/speechbubble3d/speech_bubble_r.png")
	
	label_settings = LabelSettings.new()
	if text_font != null:
		label_settings.font = text_font
	else:
		label_settings.font = preload("res://addons/speechbubble3d/PatrickHand-Regular.ttf")
	label_settings.font_color = text_color
	label_settings.font_size = text_size
	speech_label.label_settings = label_settings

	if text != "" and not use_detector:
		say_text(text)
#---------------------------------------------------------------------------------------------------

## show text in bubble, if life > 0 will close life seconds after text finished
func say_text(text:String, life:float = 0.0) -> void:
	if text.length() < 1:
		close_bubble()
		return
		
	text_extent = label_settings.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_settings.font_size)
	#text_extent.x *= 1.2
	if text_extent.x > wrap_size:
		text_extent.x = wrap_size

	letter_time = text_speed
	current_letter = 0
	speech_text = text
	
	life_time = life
	if text_speed > 0.0:
		current_life = 0.0
	else:
		current_life = life
	
	fade_out_time = fade_duration
	fade_in_time = fade_duration
#---------------------------------------------------------------------------------------------------

## fade out bubble
func close_bubble() -> void:
	# hides speech bubble
	fade_out_time = fade_duration
	fade_in_time = 0.0
#---------------------------------------------------------------------------------------------------

func showing_text() -> bool:
	return visiblity_node.visible
#---------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if fade_out_time > 0.0:
		fade_out_time -= delta
		if fade_out_time > 0.0:
			transparency_node.color.a = fade_out_time / fade_duration
		else:
			if fade_in_time > 0.0:
				# going to fade in with new text
				if text_speed > 0.0:
					speech_label.text = ""
				else:
					speech_label.text = speech_text
				speech_label.custom_minimum_size = text_extent
				transparency_node.color.a = 0.0
				visiblity_node.show()
			else:
				# stop at clear
				visiblity_node.hide()
				speech_text = ""

	elif fade_in_time > 0.0:
		fade_in_time -= delta
		if fade_in_time > 0.0:
			transparency_node.color.a = (fade_duration - fade_in_time) / fade_duration
		else:
			transparency_node.color.a = 1.0

	elif text_speed > 0.0 and current_letter < speech_text.length():
		# spell out text
		letter_time -= delta
		if letter_time <= 0.0:
			letter_time = text_speed
			current_letter += 1
			
			if current_letter >= speech_text.length():
				current_life = life_time

			var left_text : String = speech_text.left(current_letter)
			var last_letter : String = left_text.right(1)
			
			speech_label.text = left_text
			
			# pause after punctuation
			if last_letter == " ":
				letter_time += 2.0 * text_speed
			elif last_letter == ",":
				letter_time += 10.0 * text_speed
			elif last_letter == "." or last_letter == "!" or last_letter == "?":
				letter_time += 30.0 * text_speed

	elif not visiblity_node.visible:
		return
	
	if current_life > 0.0:
		current_life -= delta
		if current_life <= 0.0:
			close_bubble()

	# position bubble on screen
	var bubble_size : Vector2 = margin_node.size
	var camera : Camera3D = get_viewport().get_camera_3d()
	var behind_camera : bool = camera.is_position_behind(global_transform.origin)

	#margin to keep bubble on screen
	var view_rect : Rect2 = get_viewport().get_visible_rect()
	view_rect.size -= bubble_size 

	# move bubble to edge if offscreen
	var view_pos : Vector2
	if behind_camera:
		view_pos.x = view_rect.size.x / 2.0
		view_pos.y = view_rect.size.y
	else:
		var offset : Vector2 = bubble_size
		offset.x = 0.0
		
		view_pos = camera.unproject_position(global_transform.origin) - offset
		
	# swap bubble arrow if at right edge of screen
	if view_pos.x > view_rect.size.x:
		view_pos.x -= bubble_size.x
		bubble_pic_left.hide()
		bubble_pic_right.show()
	else:
		bubble_pic_left.show()
		bubble_pic_right.hide()
		
	speech_container.position = view_pos.clamp(Vector2.ZERO, view_rect.size)

#---------------------------------------------------------------------------------------------------
