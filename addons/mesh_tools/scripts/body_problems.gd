enum CollisionType {
	SPHERE,   # Bounding sphere (encloses the mesh AABB)
	CUBE,     # Axis-aligned bounding box
	CONVEX,   # Convex hull generated from the mesh (recommended for most situations)
	MESH      # Original mesh as a concave trimesh (most accurate but expensive)
}

## Creates and returns a new RigidBody3D with the given mesh and physics properties.
## The visual MeshInstance3D and appropriate CollisionShape3D are added as children.
static func create_rigid_body_from_mesh(
	mesh: Mesh,
	friction: float = 1.0,
	bounciness: float = 0.1,
	collision_type: CollisionType = CollisionType.CONVEX,
) -> RigidBody3D:
	if mesh == null:
		push_error("create_rigid_body_from_mesh: mesh is null")
		return null

	var rigid_body: RigidBody3D = RigidBody3D.new()

	# Visual representation
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	rigid_body.add_child(mesh_instance)

	# Create the collision
	rigid_body.add_child(_create_collision(mesh, collision_type))

	# Physics material (friction + bounciness)
	var phys_mat: PhysicsMaterial = PhysicsMaterial.new()
	phys_mat.friction = friction
	phys_mat.bounce = bounciness
	rigid_body.physics_material_override = phys_mat

	return rigid_body


static func create_static_body_from_mesh(
	mesh: Mesh,
	friction: float = 1.0,
	bounciness: float = 0.1,
	collision_type : CollisionType = CollisionType.CONVEX
) -> StaticBody3D:
	if mesh == null:
		push_error("create_static_body_from_mesh: mesh is null")
		return null

	var static_body: StaticBody3D = StaticBody3D.new()

	# Visual representation
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	static_body.add_child(mesh_instance)

	# Create the collision
	static_body.add_child(_create_collision(mesh, collision_type))

	# Physics material (friction + bounciness)
	var phys_mat: PhysicsMaterial = PhysicsMaterial.new()
	phys_mat.friction = friction
	phys_mat.bounce = bounciness
	static_body.physics_material_override = phys_mat

	return static_body


static func create_csg_body_from_mesh(
	mesh: Mesh,
	use_collision: bool = false,
	operation:CSGShape3D.Operation = CSGShape3D.Operation.OPERATION_UNION
) -> CSGMesh3D:
	if mesh == null:
		push_warning("create_csg_mesh: Received null mesh")
		return null

	var csg: CSGMesh3D = CSGMesh3D.new()
	csg.mesh = mesh
	csg.operation = operation
	csg.use_collision = use_collision

	# Optional: sensible defaults when collision is enabled
	if use_collision:
		csg.collision_layer = 0x3
		csg.collision_mask = 1
		csg.collision_priority = 1.0

	return csg


## This sets the center of mass of the [RigidBody3D], by using the AABB bounding box, or calculating it by volume.
static func set_center_of_mass(rigid_body: RigidBody3D, fancy: bool):
	# Get the body's mesh (sloppy but good enough)
	var mesh: Mesh
	for child in rigid_body.get_children():
		if child is MeshInstance3D:
			mesh = child.mesh
			break
	# Set center point for physics
	rigid_body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	var mesh_local_center: Vector3
	var com_offset: Vector3
	if not fancy:
		mesh_local_center = mesh.get_aabb().get_center()
		com_offset = mesh_local_center
	else:
		com_offset = _get_mesh_centroid(mesh, true)
	rigid_body.center_of_mass = com_offset


## Helper: Gets the center of a given mesh, either by average (fast), or by the physical volume (very accurate)
static func _get_mesh_centroid(mesh: Mesh, volumetric: bool = false):
	if not mesh:
		return Vector3.ZERO

	if not volumetric:
		var sum: Vector3 = Vector3.ZERO
		var count: int = 0

		var faces: PackedVector3Array = mesh.get_faces()
		if faces.is_empty():
			return Vector3.ZERO

		for v in faces:
			sum += v

		print("This works")
		return sum / faces.size()
	else:
		return _get_mesh_volumetric_center(mesh)


## Helper: Returns the volumetric center (center of mass) of a [Mesh] in its local space.
## [br]Assumes the mesh is closed, triangulated, and consistently oriented.
## [br]Returns [Vector3].ZERO on invalid/empty mesh.
static func _get_mesh_volumetric_center(mesh: Mesh) -> Vector3:
	if mesh == null:
		push_warning("get_mesh_volumetric_center: mesh is null")
		return Vector3.ZERO

	var faces: PackedVector3Array = mesh.get_faces()
	if faces.size() == 0 or faces.size() % 3 != 0:
		push_warning("get_mesh_volumetric_center: invalid face data (not triangulated or empty)")
		return Vector3.ZERO

	var total_volume: float = 0.0
	var weighted_sum: Vector3 = Vector3.ZERO

	for i in range(0, faces.size(), 3):
		var v1: Vector3 = faces[i]
		var v2: Vector3 = faces[i + 1]
		var v3: Vector3 = faces[i + 2]

		# Signed volume of tetrahedron formed by origin + triangle
		# (positive if winding is consistent with outward normals)
		var vol: float = v1.dot(v2.cross(v3)) / 6.0
		total_volume += vol

		# Centroid of this tetrahedron = average of its 4 vertices (origin + v1,v2,v3)
		var tet_centroid: Vector3 = (v1 + v2 + v3) / 4.0
		weighted_sum += tet_centroid * vol

	if absf(total_volume) < 1e-8:
		push_warning("get_mesh_volumetric_center: mesh has zero or near-zero volume")
		return Vector3.ZERO

	return weighted_sum / total_volume


## Helper: Create a [CollisionShape3D] based on the mesh and collision_type given, and return that node.
##[br]Allowed collision types are:
##[br]    SPHERE
##[br]    CUBE
##[br]    CONVEX
##[br]    MESH
##[br][br]
##WARNING: Using MESH as a collision option only works with [StaticBody3D], Godot does not support collison trimesh with [RigidBody3D].
static func _create_collision(mesh: Mesh, collision_type) -> CollisionShape3D:
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var aabb: AABB = mesh.get_aabb()
	var center: Vector3 = aabb.get_center()
	var shape: Shape3D

	match collision_type:
		CollisionType.SPHERE:
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = aabb.size.length() / 2.0   # enclosing sphere
			shape = sphere
			collision_shape.position = center
		CollisionType.CUBE:
			var box: BoxShape3D = BoxShape3D.new()
			box.size = aabb.size
			shape = box
			collision_shape.position = center
		CollisionType.CONVEX:
			shape = mesh.create_convex_shape()
		CollisionType.MESH: # WARNING: Only supported by StaticBody3D
			push_warning("Using a trimesh for collision is only supported by StaticBody3D")
			shape = mesh.create_trimesh_shape()
	collision_shape.shape = shape
	return collision_shape
