extends Node3D

@export_group("Collision Settings")
@export var collision_layer: int = 1  # The physics layer your player collides with
@export var use_exact_trimesh: bool = false # Set true ONLY if houses have hollow interiors/doors you walk inside

func _ready() -> void:
	# Use deferred call so transforms and mesh instances are fully loaded first
	_generate_house_collisions.call_deferred()

func _generate_house_collisions() -> void:
	for child in get_children():
		if child is MeshInstance3D and child.mesh:
			# Skip if this house already has a static body attached
			if child.has_node("StaticBody3D") or _has_static_body_child(child):
				continue
				
			if use_exact_trimesh:
				# Creates exact concave collisions (best for houses with open doors/walkable interiors)
				child.create_trimesh_collision()
			else:
				# Creates a simplified convex hull (blazing fast, ideal for solid exterior houses)
				child.create_convex_collision(true, true)
				
			# Retrieve the newly created StaticBody3D to optimize physics layers
			var static_body = _find_static_body_child(child)
			if static_body:
				static_body.collision_layer = collision_layer
				static_body.collision_mask = 0 # Static buildings don't need to listen for other objects

func _has_static_body_child(node: Node) -> bool:
	return _find_static_body_child(node) != null

func _find_static_body_child(node: Node) -> StaticBody3D:
	for sub_child in node.get_children():
		if sub_child is StaticBody3D:
			return sub_child
	return null
