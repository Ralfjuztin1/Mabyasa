@tool
class_name ScatterGizmoSink
extends RefCounted

var gizmo: EditorNode3DGizmo
var host: EditorNode3DGizmoPlugin


func _init(p_gizmo: EditorNode3DGizmo = null, p_host: EditorNode3DGizmoPlugin = null) -> void:
	gizmo = p_gizmo
	host = p_host


func add_lines(lines: PackedVector3Array, material_name: StringName = &"region") -> void:
	if gizmo != null and host != null and not lines.is_empty():
		gizmo.add_lines(lines, host.get_material(material_name, gizmo), false)


func add_handles(points: PackedVector3Array, ids := PackedInt32Array(), material_name: StringName = &"handles") -> void:
	if gizmo != null and host != null and not points.is_empty():
		gizmo.add_handles(points, host.get_material(material_name, gizmo), ids)
