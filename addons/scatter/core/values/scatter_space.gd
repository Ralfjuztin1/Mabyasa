@tool
class_name ScatterSpace
extends RefCounted

enum Type {
	GLOBAL,
	LOCAL,
	INSTANCE,
}


static func authored_to_local(space: Type, target_global_transform: Transform3D) -> Transform3D:
	if space == Type.GLOBAL:
		return target_global_transform.affine_inverse()
	return Transform3D.IDENTITY
