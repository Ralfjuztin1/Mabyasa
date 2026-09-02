extends Node3D

@export_group("Collision Settings")
@export var trunk_radius: float = 0.5   # Thickness of the trunk collision
@export var trunk_height: float = 4.0   # Height of the trunk collision
@export var collision_layer: int = 1    # The physics layer your player collides with

func _ready() -> void:
	# Use deferred call so transforms are fully calculated before building physics
	_generate_all_collisions.call_deferred()

func _generate_all_collisions() -> void:
	# Shared shape resource to minimize memory allocations
	var shared_cylinder = CylinderShape3D.new()
	shared_cylinder.radius = trunk_radius
	shared_cylinder.height = trunk_height

	for child in get_children():
		if child is MultiMeshInstance3D:
			_build_colliders_for_multimesh(child, shared_cylinder)

func _build_colliders_for_multimesh(mm_instance: MultiMeshInstance3D, shape: CylinderShape3D) -> void:
	var multimesh = mm_instance.multimesh
	if not multimesh:
		return

	# Single container node for colliders to keep the scene tree clean
	var static_body = StaticBody3D.new()
	static_body.name = mm_instance.name + "_Colliders"
	static_body.collision_layer = collision_layer
	static_body.collision_mask = 0 # Static environment doesn't need to detect other objects
	mm_instance.add_child(static_body)

	var instance_count = multimesh.instance_count
	
	for i in range(instance_count):
		var xform = multimesh.get_instance_transform(i)
		
		# Create individual collision shape instance
		var col_shape = CollisionShape3D.new()
		col_shape.shape = shape
		
		# Offset the shape so the cylinder sits flat on the base of the trunk
		var local_offset = Vector3(0, trunk_height / 2.0, 0)
		col_shape.transform = Transform3D(xform.basis, xform.origin + (xform.basis * local_offset))
		
		static_body.add_child(col_shape)
