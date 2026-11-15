@tool
extends Node3D

## Existing fallback for NPCs with no sprite frames.
## Merchant-only repair: the saved town scene placed the merchant at the
## player's saved position, and its sprite is centered partly below terrain.

const BROKEN_MERCHANT_POSITION: Vector3 = Vector3(-41.739265, 0.15000927, 25.5)
const MERCHANT_STALL_POSITION: Vector3 = Vector3(-52.5, 0.65, 25.5)
const MERCHANT_SPRITE_HEIGHT: float = 0.28

@onready var _npc_sprite: AnimatedSprite3D = get_parent().get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D


func _ready() -> void:
	_repair_merchant()
	_update_placeholder()


func _process(_delta: float) -> void:
	_update_placeholder()


func _repair_merchant() -> void:
	var npc: Node3D = get_parent() as Node3D
	if not is_instance_valid(npc) or npc.name.to_lower() != "merchant":
		return
	if not is_instance_valid(_npc_sprite):
		return

	# Reposition only the known, broken location from the Nov 15 scene.
	# Preserve future manual merchant placements in the editor.
	if npc.position.distance_to(BROKEN_MERCHANT_POSITION) < 0.75:
		npc.position = MERCHANT_STALL_POSITION

	# BaseNPC's scene is scaled 3x, so its original sprite Y=0.013 was
	# nearly entirely below ground. Position it above the ground instead.
	_npc_sprite.position.y = MERCHANT_SPRITE_HEIGHT
	_npc_sprite.visible = true
	_npc_sprite.shaded = false
	_npc_sprite.pixel_size = 0.01
	_npc_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if _npc_sprite.sprite_frames != null:
		if _npc_sprite.sprite_frames.has_animation(&"idle_front"):
			if _npc_sprite.sprite_frames.get_frame_count(&"idle_front") > 0:
				_npc_sprite.animation = &"idle_front"
				_npc_sprite.play()


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
