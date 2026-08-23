@tool
class_name ScatterFinalOutputView
extends ScatterNodeView

var _count_label: Label


func minimum_width() -> float:
	return 200.0


func _build_ports() -> void:
	var connected := context.graph.incoming_connections(model.node_id, &"instances").size()
	for index in maxi(1, connected + 1):
		add_port_row(&"instances", &"", tr("Instances %d") % (index + 1))
	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.modulate = Color("d8b36f")
	add_child(_count_label)
	update_runtime_stats()


func _build_properties() -> void:
	pass


func update_runtime_stats() -> void:
	if _count_label == null or context == null:
		return
	var count := 0
	if is_instance_valid(context.target) and context.target.multimesh != null:
		count = context.target.multimesh.instance_count
	_count_label.text = tr("%d instances") % count
