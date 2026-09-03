extends Node

@export var collision_layer: int = 1

func _ready() -> void:
	# Automatically run when the node enters the scene tree
	_generate_house_collisions(self)

func _generate_house_collisions(parent_node: Node) -> void:
	for child in parent_node.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			# Safety check: Skip if mesh resource is missing
			if child.mesh == null:
				continue
				
			# Changed from ArrayMesh to generic Mesh so saved .res files pass safely
			if not child.mesh is Mesh:
				push_warning("⚠️ [HOUSE MANAGER] Invalid mesh resource on: " + child.name)
				continue
				
			# Avoid duplicate collisions if one already exists
			if child.has_node("StaticBody3D"):
				continue
				
			var static_body = StaticBody3D.new()
			var collision_shape = CollisionShape3D.new()
			
			var shape = child.mesh.create_trimesh_shape()
			if shape:
				collision_shape.shape = shape
				static_body.add_child(collision_shape)
				static_body.collision_layer = collision_layer
				static_body.collision_mask = 0
				child.add_child(static_body)
				print("🧱 [HOUSE MANAGER] Generated collision for mesh: ", child.name)
