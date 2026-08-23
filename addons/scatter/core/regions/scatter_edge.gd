@tool
class_name ScatterEdge
extends RefCounted

var a := Vector3.ZERO
var b := Vector3.ZERO


func _init(p_a := Vector3.ZERO, p_b := Vector3.ZERO) -> void:
	a = p_a
	b = p_b
