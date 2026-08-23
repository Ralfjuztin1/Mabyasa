@tool
extends MultiMeshInstance3D

@export var scatter_radius : float = 100.0
@export var terrain_y : float = 0.0

@export var scatter_now : bool = false:
	set(value):
		if value:
			_do_scatter()

func _ready():
	if not Engine.is_editor_hint():
		_do_scatter()

func _do_scatter():
	var mm = multimesh
	if not mm:
		return
		
	var count = mm.instance_count
	for i in range(count):
		var random_x = randf_range(-scatter_radius, scatter_radius)
		var random_z = randf_range(-scatter_radius, scatter_radius)
		
		# Create a fresh transform with a clean, un-squashed basis
		var t = Transform3D()
		t.origin = Vector3(random_x, terrain_y, random_z)
		
		# Safely scale the basis uniformly so it never stretches
		var random_scale = randf_range(0.7, 1.3)
		t.basis = t.basis.scaled(Vector3(random_scale, random_scale, random_scale))
		
		mm.set_instance_transform(i, t)
	print("🌲 Trees scattered cleanly!")
