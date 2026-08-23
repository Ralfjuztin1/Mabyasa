@tool
class_name ScatterMultiMeshWriter
extends RefCounted


static func apply(target: MultiMeshInstance3D, result: ScatterBuildResult) -> void:
	if not is_instance_valid(target) or result == null or not result.ok:
		return
	var multimesh := target.multimesh
	if _needs_replacement(multimesh):
		multimesh = _create_compatible_multimesh(multimesh)
		target.multimesh = multimesh
	else:
		# A compatible local resource only needs its allocation reset. Do not
		# redundantly assign format flags while it still owns instances.
		multimesh.instance_count = 0
	result.instances.normalize()
	multimesh.instance_count = result.instances.transforms.size()
	multimesh.buffer = _pack_buffer(result.instances)
	multimesh.visible_instance_count = -1
	target.notify_property_list_changed()


static func _needs_replacement(multimesh: MultiMesh) -> bool:
	return (
		multimesh == null
		or not multimesh.resource_local_to_scene
		or multimesh.transform_format != MultiMesh.TRANSFORM_3D
		or not multimesh.use_colors
		or not multimesh.use_custom_data
	)


static func _create_compatible_multimesh(source: MultiMesh) -> MultiMesh:
	var result := MultiMesh.new()
	result.resource_local_to_scene = true
	# These allocation-format properties must be configured before instance_count.
	result.transform_format = MultiMesh.TRANSFORM_3D
	result.use_colors = true
	result.use_custom_data = true
	if source != null:
		result.mesh = source.mesh
		result.custom_aabb = source.custom_aabb
		result.physics_interpolation_quality = source.physics_interpolation_quality
	return result


static func _pack_buffer(instances: ScatterInstances) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(instances.transforms.size() * 20)
	var cursor := 0
	for index in instances.transforms.size():
		var transform := instances.transforms[index]
		var color := instances.colors[index]
		var custom := instances.custom_data[index]
		for value in [
			transform.basis.x.x, transform.basis.y.x, transform.basis.z.x, transform.origin.x,
			transform.basis.x.y, transform.basis.y.y, transform.basis.z.y, transform.origin.y,
			transform.basis.x.z, transform.basis.y.z, transform.basis.z.z, transform.origin.z,
			color.r, color.g, color.b, color.a,
			custom.r, custom.g, custom.b, custom.a,
		]:
			buffer[cursor] = value
			cursor += 1
	return buffer
