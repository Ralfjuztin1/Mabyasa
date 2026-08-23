@tool
class_name ScatterTransformOps
extends RefCounted

static func apply_array(
		buffer: ScatterInstances,
		amount: int,
		min_amount: int,
		local_offset: bool,
		offset: Vector3,
		local_rotation: bool,
		rotation_degrees: Vector3,
		individual_rotation_pivots: bool,
		rotation_pivot: Vector3,
		local_scale: bool,
		scale: Vector3,
		randomize_indices: bool,
		rng: RandomNumberGenerator,
		maximum: int,
) -> void:
	buffer.normalize()
	var originals := buffer.transforms.duplicate()
	var original_colors := buffer.colors.duplicate()
	var original_custom := buffer.custom_data.duplicate()
	amount = maxi(1, amount)
	for original_index in originals.size():
		var original: Transform3D = originals[original_index]
		var copy_count := rng.randi_range(maxi(0, min_amount), amount) if min_amount >= 0 else amount
		for copy_index in range(1, copy_count + 1):
			if buffer.transforms.size() >= maximum:
				return
			var copy := original
			var delta_basis := Basis.from_euler(rotation_degrees * PI / 180.0 * copy_index)
			copy.basis = copy.basis * delta_basis if local_rotation else delta_basis * copy.basis
			var scaled := ScatterMath.pow_vec3(scale, copy_index)
			copy.basis = (
				copy.basis.scaled(scaled)
				if local_scale
				else copy.basis.orthonormalized().scaled(copy.basis.get_scale() * scaled)
			)
			var move := offset * copy_index
			if local_offset:
				move = original.basis.orthonormalized() * move
			copy.origin += move
			var pivot := original.origin if individual_rotation_pivots else rotation_pivot
			copy.origin = pivot + delta_basis * (copy.origin - pivot)
			buffer.add_instance(copy, original_colors[original_index], original_custom[original_index])
	if randomize_indices:
		for index in range(buffer.transforms.size() - 1, 0, -1):
			var swap_index := rng.randi_range(0, index)
			_swap_items(buffer.transforms, index, swap_index)
			_swap_items(buffer.colors, index, swap_index)
			_swap_items(buffer.custom_data, index, swap_index)


static func apply_transform(
		buffer: ScatterInstances,
		position: Vector3,
		rotation_degrees: Vector3,
		scale: Vector3,
		space: int,
		target: Node3D,
) -> void:
	var target_transform := _target_global_transform(target)
	var target_basis := _target_rotation_basis(target)
	var rotation_delta := Basis.from_euler(rotation_degrees * PI / 180.0)
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		# Edit Transform follows the same contract as its three dedicated nodes:
		# position is an offset, rotation changes orientation, and scale changes
		# geometry. It must not orbit or resize instance positions around an origin.
		transform.origin += _resolve_offset(transform, position, space, target_transform)
		transform.basis = _apply_rotation_delta(transform, rotation_delta, space, target_basis)
		transform.basis = _apply_scale_factor(transform, scale, space, target_basis)
		buffer.transforms[index] = transform


static func apply_position(
		buffer: ScatterInstances,
		value: Vector3,
		operation: int,
		space: int,
		target: Node3D,
) -> void:
	var target_transform := _target_global_transform(target)
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		if operation == 0:
			transform.origin += _resolve_offset(transform, value, space, target_transform)
		elif operation == 1:
			if space == ScatterSpace.Type.GLOBAL:
				var global_origin := target_transform * transform.origin
				global_origin *= value
				transform.origin = target_transform.affine_inverse() * global_origin
			elif space == ScatterSpace.Type.LOCAL:
				transform.origin *= value
			# An instance origin is (0, 0, 0) in its own reference frame,
			# so multiplying its position in Instance space is intentionally a no-op.
		else:
			if space == ScatterSpace.Type.GLOBAL:
				transform.origin = target_transform.affine_inverse() * value
			elif space == ScatterSpace.Type.LOCAL:
				transform.origin = value
			else:
				# Instance coordinates use each transform's axes, while retaining the
				# MultiMesh node as their common origin.
				transform.origin = transform.basis * value
		buffer.transforms[index] = transform


static func apply_rotation(
		buffer: ScatterInstances,
		value: Vector3,
		operation: int,
		space: int,
		target: Node3D,
) -> void:
	var delta := Basis.from_euler(value * PI / 180.0)
	var target_basis := _target_rotation_basis(target)
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		if operation == 2:
			transform.basis = _set_rotation(transform, delta, space, target_basis)
		elif operation == 1:
			var current := _rotation_in_space(transform, space, target_basis)
			transform.basis = _set_rotation(
				transform,
				Basis.from_euler(current.get_euler() * value),
				space,
				target_basis,
			)
		else:
			transform.basis = _apply_rotation_delta(transform, delta, space, target_basis)
		buffer.transforms[index] = transform


static func apply_scale(
		buffer: ScatterInstances,
		value: Vector3,
		operation: int,
		space: int,
		target: Node3D,
) -> void:
	var target_basis := _target_rotation_basis(target)
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		var current := _scale_in_space(transform, space, target_basis)
		var factor := (
			_safe_scale_ratio(current + value, current)
			if operation == 0
			else value if operation == 1
			else _safe_scale_ratio(value, current)
		)
		transform.basis = _apply_scale_factor(transform, factor, space, target_basis)
		buffer.transforms[index] = transform


static func apply_random_transform(
		buffer: ScatterInstances,
		position: Vector3,
		rotation_degrees: Vector3,
		scale: Vector3,
		space: int,
		rng: RandomNumberGenerator,
		target: Node3D,
) -> void:
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		var offset := Vector3(
			rng.randf_range(-position.x, position.x),
			rng.randf_range(-position.y, position.y),
			rng.randf_range(-position.z, position.z),
		)
		transform.origin += _resolve_offset(transform, offset, space, _target_global_transform(target))
		var angles := Vector3(
			rng.randf_range(-rotation_degrees.x, rotation_degrees.x),
			rng.randf_range(-rotation_degrees.y, rotation_degrees.y),
			rng.randf_range(-rotation_degrees.z, rotation_degrees.z),
		) * PI / 180.0
		var delta := Basis.from_euler(angles)
		transform.basis = _apply_rotation_delta(transform, delta, space, _target_rotation_basis(target))
		var scale_delta := Vector3(
			1.0 + rng.randf_range(-scale.x, scale.x),
			1.0 + rng.randf_range(-scale.y, scale.y),
			1.0 + rng.randf_range(-scale.z, scale.z),
		)
		transform.basis = _apply_scale_factor(transform, scale_delta, space, _target_rotation_basis(target))
		buffer.transforms[index] = transform


static func apply_random_rotation(
		buffer: ScatterInstances,
		rotation_degrees: Vector3,
		snap_angle: Vector3,
		space: int,
		rng: RandomNumberGenerator,
		target: Node3D,
) -> void:
	var target_basis := _target_rotation_basis(target)
	for index in buffer.transforms.size():
		var angles := Vector3(
			ScatterMath.random_snapped(rng, rotation_degrees.x, snap_angle.x),
			ScatterMath.random_snapped(rng, rotation_degrees.y, snap_angle.y),
			ScatterMath.random_snapped(rng, rotation_degrees.z, snap_angle.z),
		) * PI / 180.0
		var transform := buffer.transforms[index]
		var delta := Basis.from_euler(angles)
		transform.basis = _apply_rotation_delta(transform, delta, space, target_basis)
		buffer.transforms[index] = transform


static func _target_global_transform(target: Node3D) -> Transform3D:
	if not is_instance_valid(target):
		return Transform3D.IDENTITY
	# Core tests and recipe evaluation can operate on a target before it enters
	# a scene tree. In that case its local transform is the only valid frame.
	return target.global_transform if target.is_inside_tree() else target.transform


static func _target_rotation_basis(target: Node3D) -> Basis:
	var basis := _target_global_transform(target).basis
	return basis.orthonormalized() if basis.determinant() != 0.0 else Basis()


static func _resolve_offset(
		transform: Transform3D,
		value: Vector3,
		space: int,
		target_transform: Transform3D,
) -> Vector3:
	if space == ScatterSpace.Type.GLOBAL:
		return target_transform.basis.inverse() * value
	if space == ScatterSpace.Type.INSTANCE:
		return transform.basis * value
	return value


static func _apply_rotation_delta(
		transform: Transform3D,
		delta: Basis,
		space: int,
		target_basis: Basis,
) -> Basis:
	if space == ScatterSpace.Type.INSTANCE:
		return transform.basis * delta
	elif space == ScatterSpace.Type.GLOBAL:
		return target_basis.inverse() * delta * target_basis * transform.basis
	return delta * transform.basis


static func _rotation_in_space(transform: Transform3D, space: int, target_basis: Basis) -> Basis:
	var orientation := transform.basis.orthonormalized()
	return target_basis * orientation if space == ScatterSpace.Type.GLOBAL else orientation


static func _set_rotation(
		transform: Transform3D,
		desired: Basis,
		space: int,
		target_basis: Basis,
) -> Basis:
	var local_rotation := target_basis.inverse() * desired if space == ScatterSpace.Type.GLOBAL else desired
	return local_rotation.orthonormalized().scaled(transform.basis.get_scale())


static func _scale_in_space(transform: Transform3D, space: int, target_basis: Basis) -> Vector3:
	var basis := target_basis * transform.basis if space == ScatterSpace.Type.GLOBAL else transform.basis
	return basis.get_scale()


static func _safe_scale_ratio(target_scale: Vector3, current_scale: Vector3) -> Vector3:
	return Vector3(
		target_scale.x / current_scale.x if absf(current_scale.x) > 0.000001 else 1.0,
		target_scale.y / current_scale.y if absf(current_scale.y) > 0.000001 else 1.0,
		target_scale.z / current_scale.z if absf(current_scale.z) > 0.000001 else 1.0,
	)


static func _apply_scale_factor(
		transform: Transform3D,
		factor: Vector3,
		space: int,
		target_basis: Basis,
) -> Basis:
	var delta := Basis.from_scale(factor)
	if space == ScatterSpace.Type.INSTANCE:
		return transform.basis * delta
	elif space == ScatterSpace.Type.GLOBAL:
		return target_basis.inverse() * delta * target_basis * transform.basis
	return delta * transform.basis


static func apply_look_at(buffer: ScatterInstances, target_position: Vector3, up: Vector3) -> void:
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		var direction := target_position - transform.origin
		if direction.length_squared() > 0.000001:
			transform.basis = ScatterMath.basis_from_forward(direction.normalized(), up).scaled(transform.basis.get_scale())
		buffer.transforms[index] = transform


static func apply_snap(
		buffer: ScatterInstances,
		position_step: Vector3,
		rotation_step_degrees: Vector3,
		scale_step: Vector3,
) -> void:
	var rotation_step := rotation_step_degrees * PI / 180.0
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		transform.origin = ScatterMath.snapped_vec3(transform.origin, position_step)
		var euler := ScatterMath.snapped_vec3(transform.basis.get_euler(), rotation_step)
		var scale := ScatterMath.snapped_vec3(transform.basis.get_scale(), scale_step)
		transform.basis = Basis.from_euler(euler).scaled(scale)
		buffer.transforms[index] = transform


static func apply_relax(
		buffer: ScatterInstances,
		iterations: int,
		offset_step: float,
		consecutive_step_multiplier: float,
) -> void:
	if buffer.transforms.size() < 2:
		return
	var offset := offset_step
	for _iteration in maxi(iterations, 0):
		var directions: Array[Vector3] = []
		for index in buffer.transforms.size():
			var closest := Vector3.ZERO
			var best := INF
			for other_index in buffer.transforms.size():
				if index == other_index:
					continue
				var difference := buffer.transforms[index].origin - buffer.transforms[other_index].origin
				if difference.length_squared() < best:
					best = difference.length_squared()
					closest = difference
			directions.append(closest.normalized() * offset)
		for index in buffer.transforms.size():
			buffer.transforms[index].origin += directions[index]
		offset *= consecutive_step_multiplier


static func apply_clusterize(
		buffer: ScatterInstances,
		mask_path: String,
		mask_rotation_degrees: float,
		mask_offset: Vector2,
		mask_scale: Vector2,
		pixel_to_unit_ratio: float,
		remove_below: float,
		remove_above: float,
		scale_transforms: bool,
) -> void:
	if mask_path.is_empty() or not ResourceLoader.exists(mask_path):
		return
	var texture = ResourceLoader.load(mask_path)
	if not texture is Texture2D:
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return
	buffer.normalize()
	var angle := deg_to_rad(mask_rotation_degrees)
	var ratio := maxf(pixel_to_unit_ratio, 0.001)
	var safe_scale := Vector2(maxf(absf(mask_scale.x), 0.001), maxf(absf(mask_scale.y), 0.001))
	for index in range(buffer.transforms.size() - 1, -1, -1):
		var origin := buffer.transforms[index].origin
		var uv := Vector2(origin.x, origin.z) / ratio + Vector2(0.5, 0.5)
		uv = ((uv - Vector2(0.5, 0.5)).rotated(angle) / safe_scale) + Vector2(0.5, 0.5) + mask_offset
		var x := clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1)
		var y := clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1)
		var value := image.get_pixel(x, y).get_luminance()
		if value < remove_below or value > remove_above:
			buffer.remove_at(index)
		elif scale_transforms:
			buffer.transforms[index].basis = buffer.transforms[index].basis.scaled(Vector3.ONE * value)


static func apply_projection(
		buffer: ScatterInstances,
		target: MultiMeshInstance3D,
		ray_direction: Vector3,
		ray_length: float,
		ray_offset: float,
		remove_points_on_miss: bool,
		align_with_collision_normal: bool,
		max_slope: float,
		collision_mask: int,
		exclude_mask: int,
) -> void:
	if not target.is_inside_tree() or target.get_world_3d() == null or ray_direction.length_squared() < 0.000001:
		return
	buffer.normalize()
	var state := target.get_world_3d().direct_space_state
	var direction := ray_direction.normalized()
	for index in range(buffer.transforms.size() - 1, -1, -1):
		var local_transform := buffer.transforms[index]
		var global_origin := target.to_global(local_transform.origin)
		var global_direction := (target.global_transform.basis * direction).normalized()
		var query := PhysicsRayQueryParameters3D.create(
			global_origin - global_direction * ray_offset,
			global_origin + global_direction * ray_length,
			collision_mask,
		)
		if exclude_mask != 0:
			var exclusion_query := PhysicsRayQueryParameters3D.create(query.from, query.to, exclude_mask)
			if not state.intersect_ray(exclusion_query).is_empty():
				buffer.remove_at(index)
				continue
		var hit := state.intersect_ray(query)
		if hit.is_empty():
			if remove_points_on_miss:
				buffer.remove_at(index)
			continue
		var normal: Vector3 = hit.normal
		if rad_to_deg(normal.angle_to(Vector3.UP)) > max_slope:
			buffer.remove_at(index)
			continue
		local_transform.origin = target.to_local(hit.position)
		if align_with_collision_normal:
			var local_normal := (target.global_transform.basis.inverse() * normal).normalized()
			local_transform.basis = ScatterMath.basis_from_up(local_normal, -local_transform.basis.z).scaled(local_transform.basis.get_scale())
		buffer.transforms[index] = local_transform


static func _swap_items(values: Array, a: int, b: int) -> void:
	var temporary = values[a]
	values[a] = values[b]
	values[b] = temporary
