@tool
extends Node3D

## Keep a temporary simple model visible until any sprite frames are added.
## Works in both the Godot editor and the running game.

@onready var _npc_sprite: AnimatedSprite3D = get_parent().get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D


func _ready() -> void:
	_update_placeholder()


func _process(_delta: float) -> void:
	_update_placeholder()


func _update_placeholder() -> void:
	if not is_instance_valid(_npc_sprite):
		return
	var sprite_frames: SpriteFrames = _npc_sprite.sprite_frames
	if sprite_frames == null:
		visible = true
		return
	for animation_name: StringName in sprite_frames.get_animation_names():
		if sprite_frames.get_frame_count(animation_name) > 0:
			visible = false
			return
	visible = true
