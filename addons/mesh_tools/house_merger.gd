@tool
extends Node3D

@export var merge_house_now: bool = false:
	set(val):
		if val:
			_combine_meshes_with_materials()

func _combine_meshes_with_materials():
	# Dictionary to group surfaces by their material
	var material_surfaces = {} # Material -> Array of data
	
	_gather_surfaces(self, Transform3D.IDENTITY, material_surfaces)
	
	if material_surfaces.is_empty():
		print("No meshes found to merge!")
		merge_house_now = false
		return
		
	var final_mesh = ArrayMesh.new()
	var mat_index = 0
	
	# Build the new mesh surface by surface, keeping materials separated
	for mat in material_surfaces.keys():
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		for item in material_surfaces[mat]:
			st.append_from(item["mesh"], item["surf"], item["xform"])
			
		st.commit(final_mesh)
		final_mesh.surface_set_material(mat_index, mat)
		mat_index += 1
		
	# Remove old individual parts
	for child in get_children():
		if child != self:
			child.queue_free()
			
	# Create the single final MeshInstance3D
	var mi = MeshInstance3D.new()
	mi.mesh = final_mesh
	mi.name = "House_Textured_SingleMesh"
	add_child(mi)
	mi.owner = self
	
	print("Success! House merged into one object with textures preserved.")
	merge_house_now = false

func _gather_surfaces(node: Node, acc_xform: Transform3D, dict: Dictionary):
	var current_xform = acc_xform
	if node is Node3D:
		current_xform = acc_xform * node.transform
		
	if node is MeshInstance3D and node.mesh and node != self:
		var mesh = node.mesh
		for i in range(mesh.get_surface_count()):
			# Grab the material assigned to this specific surface
			var mat = node.get_surface_override_material(i)
			if not mat:
				mat = mesh.surface_get_material(i)
			if not mat:
				mat = StandardMaterial3D.new() # Fallback
				
			if not dict.has(mat):
				dict[mat] = []
				
			dict[mat].append({
				"mesh": mesh,
				"surf": i,
				"xform": current_xform
			})
			
	for child in node.get_children():
		if child != self:
			_gather_surfaces(child, current_xform, dict)
