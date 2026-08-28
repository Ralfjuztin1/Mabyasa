class_name MeshTools

## Islands has the methods:
## [br]separate_mesh_islands
## [br]    Takes a [param mesh], and returns an array of all the floating mesh islands separated out of it.
## [br]calculate_mesh_volume
## [br]    Returns the given [param mesh]'s volume, in the cubed unit of said mesh. (typically cubic meters) It is assumed the mesh is watertight.
const Islands = preload("res://addons/mesh_tools/scripts/island_separate.gd")

## CleanUp has the methods:
## [br]rebuild_csg_node
## [br]    Bakes any CSG node and all it's children into one new [CSGMesh3D].  The children are then removed after.
## [br]merge_by_distance
## [br]    Takes a [param mesh] and performs a merge by distance operation on it, useful after a CSG operation.
## [br]invert_normal_vectors
## [br]    This function takes a [param mesh] and inverts the normal.  It does not flip the face orientation, (which would affect backface culling) but just the "amplitude" of the normal.[br]Use this function if it looks like your model's lighting is flipped, as if it were illuminated from the interior.
## [br]flip_face_normals
## [br]    Takes a [param mesh] and flips the face orientation.  This is similar to Blender's flip normals operation, and it does affect backface culling.
const CleanUp = preload("res://addons/mesh_tools/scripts/mesh_cleanup.gd")

## BodyProblems has the methods:
## [br]create_rigid_body_from_mesh
## [br]    Creates a [RigidBody3D] from a given mesh, and defaults to reasonable physics parameters if none are given.
## [br]create_static_body_from_mesh
## [br]    Creates a [StaticBody3D] from a given mesh, and defaults to reasonable physics parameters if none are given.
## [br]create_csg_body_from_mesh
## [br]    Creates a [CSGMesh3D] from a given mesh, and does not use collision by default.
## [br]set_center_of_mass
## [br]    A function that is almost mandatory to run on [RigidBody3D]s generated from create_rigid_body_from_mesh
const BodyProblems = preload("res://addons/mesh_tools/scripts/body_problems.gd")

## MeshEffects has the methods:
## [br]randomize_mesh
## [br]    Takes a [param mesh] and randomizes the vertex positions.  The normals, or winding order, may need to be flipped using [method CleanUp.invert_normal_vectors] depending on the situation.[br]Parameters are included for [param distance], [param uniform],  [param along_normal], and the [param seed].
## [br]shade_smooth_by_angle
## [br]    Takes [param mesh] and [param float] and performs a shade auto-smooth operation, like Blender.
const MeshEffects = preload("res://addons/mesh_tools/scripts/mesh_effects.gd")

## MeshDestruction has the methods:
## [br]slice_mesh
## [br]    It takes a [param MeshInstance3D] with a [param PlaneMesh] that does the cutting, a recieving [param mesh], and an optional [param StandardMaterial3D].
## [br]check_penetration
## [br]    Using the [param MeshInstance3D] plane you intend to slice with, and a [param MeshInstance3D], run a check to see if the slicing plane fully bisects the target, or only partially does.[br]This is useful for weapons or effects that have a limited range or power to slice.  The slicer always cuts on an infinate plane, so this is just a sanity check if you want it.
const MeshDestruction = preload("res://addons/mesh_tools/scripts/mesh_destruction.gd")
