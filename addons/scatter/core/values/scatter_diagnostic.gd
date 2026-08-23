@tool
class_name ScatterDiagnostic
extends RefCounted

enum Severity {
	WARNING,
	ERROR,
}

var severity := Severity.ERROR
var code: StringName
var node_id := -1
var message := ""
var details: Dictionary = {}


func _init(
		p_severity := Severity.ERROR,
		p_code: StringName = &"unknown",
		p_node_id := -1,
		p_message := "",
		p_details: Dictionary = {},
) -> void:
	severity = p_severity
	code = p_code
	node_id = p_node_id
	message = p_message
	details = p_details.duplicate(true)
