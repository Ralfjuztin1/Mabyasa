extends Node3D
var player = null
var parent_bubble: SpeechBubble3D

func _ready() -> void:
	parent_bubble = get_parent_node_3d()
	parent_bubble.close_bubble()


func set_radius(radius: float):
	$Area3D/CollisionShape3D.shape.radius = radius


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		player = body
		parent_bubble.say_text(parent_bubble.text)


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body == player:
		player = null
		parent_bubble.close_bubble()
