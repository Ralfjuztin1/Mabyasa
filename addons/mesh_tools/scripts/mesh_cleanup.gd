## This function should be used with the await keyword if you are using the csg node right after,
## as it edits the resource, and process frame differences can cause dependancy issues in the downtime.
static func rebuild_csg_node(csg_node:CSGShape3D, force:bool=false) -> void:
	# Wait for the CSG to update and generate its baked mesh
	await csg_node.get_tree().process_frame

	# Get the baked mesh data - this includes all CSG operations from children.
	var meshes: Array = csg_node.get_meshes()

	if meshes.size() < 2:
		push_warning("CSG node has no baked mesh available")
		if not force:
			return

		push_warning("Attempting to find root CSG node (expensive operation)")
		var looking_for_parent: CSGShape3D = csg_node
		while true:
			if looking_for_parent.is_root_shape():
				meshes = looking_for_parent.get_meshes()
				csg_node = looking_for_parent
				break
			else:
				looking_for_parent = looking_for_parent.get_parent()

	var baked_mesh: ArrayMesh = meshes[1]
	if baked_mesh == null:
		push_warning("CSG node baked mesh is null")
		return

	# Replace the CSG node's contents. We keep the same node (still a CSG node)
	# but strip its CSG children and convert it into a CSGMesh3D-style holder
	# of the baked mesh. We do this by replacing it with a CSGMesh3D, since the
	# original could be any CSGShape3D subclass (CSGBox3D, CSGCombiner3D, etc.).
	var replacement: CSGMesh3D = CSGMesh3D.new()
	replacement.name = csg_node.name
	replacement.transform = csg_node.transform
	replacement.operation = csg_node.operation
	replacement.use_collision = csg_node.use_collision
	replacement.collision_layer = csg_node.collision_layer
	replacement.collision_mask = csg_node.collision_mask
	replacement.calculate_tangents = csg_node.calculate_tangents
	replacement.mesh = baked_mesh#final_mesh

	# Free all CSG children
	for child in csg_node.get_children():
		csg_node.remove_child(child)
		child.queue_free()

	# Swap the node in the tree
	var parent: Node3D = csg_node.get_parent()
	var index: int = csg_node.get_index()
	var owner_node := csg_node.owner
	parent.remove_child(csg_node)
	parent.add_child(replacement)
	parent.move_child(replacement, index)
	if owner_node:
		replacement.owner = owner_node
	csg_node.queue_free()

## This literally inverts the direction of the normal, without touching winding order or face orientation.
static func invert_normal_vectors(mesh: Mesh) -> Mesh:
	var new_mesh: ArrayMesh = ArrayMesh.new()

	for surface_idx in mesh.get_surface_count():
		var mdt: MeshDataTool = MeshDataTool.new()
		mdt.create_from_surface(mesh, surface_idx)

		for v in mdt.get_vertex_count():
			var normal: Vector3 = mdt.get_vertex_normal(v)
			mdt.set_vertex_normal(v, -normal)

		mdt.commit_to_surface(new_mesh)

	return new_mesh

## Flips the direction of the face by rebuilding the mesh.
static func flip_face_normals(mesh: Mesh) -> Mesh:
	var new_mesh := ArrayMesh.new()
	for surface_idx in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_idx)

		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in normals.size():
				normals[i] = -normals[i]
			arrays[Mesh.ARRAY_NORMAL] = normals

		if arrays[Mesh.ARRAY_INDEX] != null:
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				var tmp := indices[i + 1]
				indices[i + 1] = indices[i + 2]
				indices[i + 2] = tmp
			arrays[Mesh.ARRAY_INDEX] = indices

		new_mesh.add_surface_from_arrays(mesh.surface_get_primitive_type(surface_idx), arrays)

		var mat: Material = mesh.surface_get_material(surface_idx)
		if mat:
			new_mesh.surface_set_material(surface_idx, mat)

	return new_mesh


## Returns a new ArrayMesh with vertices closer than [param distance] welded together.
## [br][param mesh] is left untouched. Materials from the original surfaces are preserved
## as best as possible by grouping output triangles by their dominant source
## surface.
static func merge_by_distance(mesh: Mesh, distance: float) -> ArrayMesh:
	if mesh == null:
		push_error("MeshMergeByDistance: mesh is null")
		return null
	if distance <= 0.0:
		# Nothing to merge — just return a duplicate as an ArrayMesh.
		return _mesh_to_array_mesh(mesh)

	# 1. Flatten every surface into one unified vertex/index buffer, while
	#    remembering which surface (and therefore which material) each
	#    original triangle came from.
	var flat: _FlatMesh = _flatten_mesh(mesh)
	if flat.vertices.is_empty() or flat.indices.is_empty():
		push_warning("MeshMergeByDistance: mesh has no geometry")
		return _mesh_to_array_mesh(mesh)

	# 2. Build the voxel grid and find the canonical (representative) vertex
	#    for every input vertex.
	var remap: PackedInt32Array = _build_vertex_remap(flat.vertices, distance)

	# 3. Build the merged vertex buffer and rewrite indices so triangles point
	#    at the merged vertex set. Degenerate triangles (two or more shared
	#    indices after merging) are dropped.
	var merged: _MergedBuffers = _build_merged_buffers(flat, remap)

	# 4. Group triangles by source surface so each material gets its own
	#    surface in the output. The vertex buffer itself is shared logic-wise:
	#    every surface re-indexes into the same merged vertex set, which means
	#    seams between materials remain physically welded.
	return _build_output_mesh(mesh, merged, flat.tri_surface)


# Internal container for the flattened mesh data.
class _FlatMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var has_normals: bool = false
	var has_uvs: bool = false
	var has_colors: bool = false
	# One entry per triangle (indices.size() / 3) telling us which source
	# surface (and therefore material) it came from.
	var tri_surface: PackedInt32Array = PackedInt32Array()
	# Flat triangle index buffer into the vertex arrays above.
	var indices: PackedInt32Array = PackedInt32Array()


static func _flatten_mesh(mesh: Mesh) -> _FlatMesh:
	var flat: _FlatMesh = _FlatMesh.new()
	var surface_count: int = mesh.get_surface_count()

	# First pass: detect which attributes are present in *any* surface so we
	# can keep the merged buffers consistent across surfaces.
	for s in surface_count:
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_NORMAL] != null:
			flat.has_normals = true
		if arrays[Mesh.ARRAY_TEX_UV] != null:
			flat.has_uvs = true
		if arrays[Mesh.ARRAY_COLOR] != null:
			flat.has_colors = true

	# Second pass: copy data, expanding indexed triangles into their actual
	# vertex references and offsetting indices into the unified buffer.
	for s in surface_count:
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts == null or verts.is_empty():
			continue

		var base_offset: int = flat.vertices.size()
		flat.vertices.append_array(verts)

		# Pad / fill optional channels so all surfaces stay aligned.
		_append_optional_v3(flat.normals, arrays[Mesh.ARRAY_NORMAL], verts.size(), flat.has_normals)
		_append_optional_v2(flat.uvs, arrays[Mesh.ARRAY_TEX_UV], verts.size(), flat.has_uvs)
		_append_optional_color(flat.colors, arrays[Mesh.ARRAY_COLOR], verts.size(), flat.has_colors)

		# Build a triangle list. If the surface is indexed, use that;
		# otherwise assume vertices form sequential triangles.
		var src_indices = arrays[Mesh.ARRAY_INDEX]
		if src_indices != null and not src_indices.is_empty():
			for i in src_indices:
				flat.indices.append(i + base_offset)
			var tri_count = src_indices.size() / 3
			for _t in tri_count:
				flat.tri_surface.append(s)
		else:
			var tri_count2 := verts.size() / 3
			for t in tri_count2:
				flat.indices.append(base_offset + t * 3)
				flat.indices.append(base_offset + t * 3 + 1)
				flat.indices.append(base_offset + t * 3 + 2)
				flat.tri_surface.append(s)

	return flat


static func _append_optional_v3(dst: PackedVector3Array, src, count: int, channel_active: bool) -> void:
	if not channel_active:
		return
	if src != null and src.size() == count:
		dst.append_array(src)
	else:
		# Fill with zeros so per-vertex indexing stays valid.
		for _i in count:
			dst.append(Vector3.ZERO)


static func _append_optional_v2(dst: PackedVector2Array, src, count: int, channel_active: bool) -> void:
	if not channel_active:
		return
	if src != null and src.size() == count:
		dst.append_array(src)
	else:
		for _i in count:
			dst.append(Vector2.ZERO)


static func _append_optional_color(dst: PackedColorArray, src, count: int, channel_active: bool) -> void:
	if not channel_active:
		return
	if src != null and src.size() == count:
		dst.append_array(src)
	else:
		for _i in count:
			dst.append(Color.WHITE)


## Bucket every vertex into a voxel grid whose cell edge equals [param distance].
## Two points within [param distance] of each other can ONLY be in the same cell
## or one of the 26 neighboring cells, so we limit pair tests to that
## 27-cell neighborhood.
## [br]Use union-find (disjoint-set) to merge clusters. We ONLY union a pair
## after a real distance test passes — we never assume that "A near B and
## B near C" implies "A near C". That assumption was the source of the
## sloppy over-merging in the previous version.
## [br]To avoid testing every pair twice, when we examine vertex `i` we only
## look at vertices `j > i` in the 27-cell neighborhood.
static func _build_vertex_remap(vertices: PackedVector3Array, distance: float) -> PackedInt32Array:
	var vert_count: int = vertices.size()
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(vert_count)
	for i in vert_count:
		parent[i] = i # each vertex starts in its own set

	var cell_size: float = distance
	var dist_sq: float = distance * distance

	# Bucket vertices into voxel cells. Key is a 64-bit packed cell coord;
	# value is the list of vertex indices in that cell.
	var grid: Dictionary = {}
	var cell_coords: PackedInt64Array = PackedInt64Array()
	cell_coords.resize(vert_count)
	for i in vert_count:
		var ck: int = _cell_key64(vertices[i], cell_size)
		cell_coords[i] = ck
		if not grid.has(ck):
			grid[ck] = PackedInt32Array()
		grid[ck].append(i)

	# Pair-test every vertex against its 27-cell neighborhood, only unioning
	# pairs that genuinely pass the distance test.
	for i in vert_count:
		var cell: Vector3i = _cell_coord(vertices[i], cell_size)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					var nkey: int = _pack_cell(cell.x + dx, cell.y + dy, cell.z + dz)
					if not grid.has(nkey):
						continue
					var bucket: PackedInt32Array = grid[nkey]
					for j in bucket:
						# Only consider each unordered pair once.
						if j <= i:
							continue
						if vertices[i].distance_squared_to(vertices[j]) <= dist_sq:
							_uf_union(parent, i, j)

	# Path-compress: every entry now points directly at its set's root.
	# That root becomes the representative used downstream.
	for i in vert_count:
		parent[i] = _uf_find(parent, i)

	return parent


# Helper: union-find helpers
static func _uf_find(parent: PackedInt32Array, x: int) -> int:
	# Iterative find with path compression
	var root: int = x
	while parent[root] != root:
		root = parent[root]
	# Compress
	var cur: int = x
	while parent[cur] != root:
		var nxt := parent[cur]
		parent[cur] = root
		cur = nxt
	return root


static func _uf_union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra: int = _uf_find(parent, a)
	var rb: int = _uf_find(parent, b)
	if ra == rb:
		return
	# Always keep the lower index as the root for deterministic output.
	if ra < rb:
		parent[rb] = ra
	else:
		parent[ra] = rb


# Helper: cell-coordinate helpers
static func _cell_coord(v: Vector3, cell_size: float) -> Vector3i:
	return Vector3i(
		int(floorf(v.x / cell_size)),
		int(floorf(v.y / cell_size)),
		int(floorf(v.z / cell_size))
	)


# Pack a (x,y,z) cell coordinate into a single 64-bit int for fast dictionary
# lookup. 21 bits per axis covers a ±1,000,000-cell range, which at typical
# merge distances is far larger than any realistic mesh extents.
static func _pack_cell(x: int, y: int, z: int) -> int:
	const MASK := 0x1FFFFF # 21 bits
	const BIAS := 0x100000 # shift signed -> unsigned 21-bit
	var ux := (x + BIAS) & MASK
	var uy := (y + BIAS) & MASK
	var uz := (z + BIAS) & MASK
	return (ux << 42) | (uy << 21) | uz


static func _cell_key64(v: Vector3, cell_size: float) -> int:
	var c: Vector3i = _cell_coord(v, cell_size)
	return _pack_cell(c.x, c.y, c.z)


class _MergedBuffers:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var has_normals: bool = false
	var has_uvs: bool = false
	var has_colors: bool = false
	# Triangles after merging, as flat index triples into `vertices`.
	var triangles: PackedInt32Array = PackedInt32Array()
	# Source surface for each surviving triangle (parallel to triangles/3).
	var tri_surface: PackedInt32Array = PackedInt32Array()


static func _build_merged_buffers(flat: _FlatMesh, remap: PackedInt32Array) -> _MergedBuffers:
	var out: _MergedBuffers = _MergedBuffers.new()
	out.has_normals = flat.has_normals
	out.has_uvs = flat.has_uvs
	out.has_colors = flat.has_colors

	# Map: original representative index -> new compact index.
	var rep_to_new: Dictionary = {}
	# Accumulators for averaging across each cluster.
	var pos_sums: Array[Vector3] = []
	var pos_counts: PackedInt32Array = PackedInt32Array()
	var normal_sums: Array[Vector3] = []
	var normal_counts: PackedInt32Array = PackedInt32Array()
	var uv_sums: Array[Vector2] = []
	var uv_counts: PackedInt32Array = PackedInt32Array()
	var color_sums: Array[Color] = []
	var color_counts: PackedInt32Array = PackedInt32Array()

	# Positions are averaged to the cluster centroid so the welded vertex
	# sits at the geometric center of the points it replaced (rather than
	# snapping to whichever original vertex happened to win union-find).
	# Normals/UVs/colors are averaged the same way so attributes blend
	# smoothly across what used to be a seam.
	for orig_i in flat.vertices.size():
		var rep: int = remap[orig_i]
		var new_i: int
		if rep_to_new.has(rep):
			new_i = rep_to_new[rep]
		else:
			new_i = out.vertices.size()
			rep_to_new[rep] = new_i
			out.vertices.append(Vector3.ZERO) # placeholder, filled in below
			pos_sums.append(Vector3.ZERO)
			pos_counts.append(0)
			if out.has_normals:
				normal_sums.append(Vector3.ZERO)
				normal_counts.append(0)
			if out.has_uvs:
				uv_sums.append(Vector2.ZERO)
				uv_counts.append(0)
			if out.has_colors:
				color_sums.append(Color(0, 0, 0, 0))
				color_counts.append(0)

		pos_sums[new_i] += flat.vertices[orig_i]
		pos_counts[new_i] += 1
		if out.has_normals:
			normal_sums[new_i] += flat.normals[orig_i]
			normal_counts[new_i] += 1
		if out.has_uvs:
			uv_sums[new_i] += flat.uvs[orig_i]
			uv_counts[new_i] += 1
		if out.has_colors:
			var c: Color = flat.colors[orig_i]
			color_sums[new_i] = Color(
				color_sums[new_i].r + c.r,
				color_sums[new_i].g + c.g,
				color_sums[new_i].b + c.b,
				color_sums[new_i].a + c.a
			)
			color_counts[new_i] += 1

	# Finalize positions to the centroid of each cluster.
	for i in out.vertices.size():
		var cnt_p := pos_counts[i]
		if cnt_p > 0:
			out.vertices[i] = pos_sums[i] / float(cnt_p)

	# Finalize averaged attributes.
	if out.has_normals:
		out.normals.resize(out.vertices.size())
		for i in out.vertices.size():
			var n: Vector3 = normal_sums[i]
			if normal_counts[i] > 0 and n.length_squared() > 0.0:
				out.normals[i] = n.normalized()
			else:
				out.normals[i] = Vector3.UP
	if out.has_uvs:
		out.uvs.resize(out.vertices.size())
		for i in out.vertices.size():
			if uv_counts[i] > 0:
				out.uvs[i] = uv_sums[i] / float(uv_counts[i])
			else:
				out.uvs[i] = Vector2.ZERO
	if out.has_colors:
		out.colors.resize(out.vertices.size())
		for i in out.vertices.size():
			var cnt := color_counts[i]
			if cnt > 0:
				var s: Color = color_sums[i]
				out.colors[i] = Color(s.r / cnt, s.g / cnt, s.b / cnt, s.a / cnt)
			else:
				out.colors[i] = Color.WHITE

	# Rewrite triangles. Drop any that became degenerate after merging
	# (two or three indices collapsed to the same vertex).
	var tri_count: int = flat.indices.size() / 3
	for t in tri_count:
		var a: int = rep_to_new[remap[flat.indices[t * 3 + 0]]]
		var b: int = rep_to_new[remap[flat.indices[t * 3 + 1]]]
		var c2: int = rep_to_new[remap[flat.indices[t * 3 + 2]]]
		if a == b or b == c2 or a == c2:
			continue
		out.triangles.append(a)
		out.triangles.append(b)
		out.triangles.append(c2)
		out.tri_surface.append(flat.tri_surface[t])

	return out


## Materials are applied by splitting the merged triangle list back out by
## source surface. Crucially, every output surface re-indexes into the SAME
## merged vertex set, so triangles that share a welded vertex still share it
## physically — there are no per-material vertex copies that would create
## tears at material boundaries.
static func _build_output_mesh(source_mesh: Mesh, merged: _MergedBuffers, _ignored: PackedInt32Array) -> ArrayMesh:
	var out_mesh: ArrayMesh = ArrayMesh.new()
	var surface_count: int = source_mesh.get_surface_count()

	# Bucket merged triangles by their source surface index.
	var per_surface_tris: Array[PackedInt32Array] = []
	per_surface_tris.resize(surface_count)
	for s in surface_count:
		per_surface_tris[s] = PackedInt32Array()

	var tri_count: int = merged.triangles.size() / 3
	for t in tri_count:
		var s: int = merged.tri_surface[t]
		# Guard against malformed data.
		if s < 0 or s >= surface_count:
			s = 0
		per_surface_tris[s].append(merged.triangles[t * 3 + 0])
		per_surface_tris[s].append(merged.triangles[t * 3 + 1])
		per_surface_tris[s].append(merged.triangles[t * 3 + 2])

	# Emit one ArrayMesh surface per non-empty source surface.
	for s in surface_count:
		var tris: PackedInt32Array = per_surface_tris[s]
		if tris.is_empty():
			continue

		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = merged.vertices
		if merged.has_normals:
			arrays[Mesh.ARRAY_NORMAL] = merged.normals
		if merged.has_uvs:
			arrays[Mesh.ARRAY_TEX_UV] = merged.uvs
		if merged.has_colors:
			arrays[Mesh.ARRAY_COLOR] = merged.colors
		arrays[Mesh.ARRAY_INDEX] = tris

		out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat: Material = source_mesh.surface_get_material(s)
		if mat != null:
			out_mesh.surface_set_material(out_mesh.get_surface_count() - 1, mat)

	return out_mesh


# Helper: turns a mesh into an ArrayMesh (utility nonsense that might be unnecessary FIXME)
static func _mesh_to_array_mesh(mesh: Mesh) -> ArrayMesh:
	if mesh is ArrayMesh:
		return mesh
	var out: ArrayMesh = ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat: Material = mesh.surface_get_material(s)
		if mat != null:
			out.surface_set_material(out.get_surface_count() - 1, mat)
	return out
