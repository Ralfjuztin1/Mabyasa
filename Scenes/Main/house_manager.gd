extends Node

func _generate_house_collisions(parent_node: Node) -> void:
	for child in parent_node.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			# Safety check: Skip if mesh resource is missing
			if child.mesh == null:
				continue
				
			# FBX/ImporterMesh protection: Skip if it's not a ready-to-use runtime ArrayMesh
			if not child.mesh is ArrayMesh:
				push_warning("⚠️ [HOUSE MANAGER] Skipped FBX ImporterMesh (baking recommended): " + child.name)
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
				child.add_child(static_body)
				print("🧱 [HOUSE MANAGER] Generated collision for mesh: ", child.name)
