@tool
class_name ScatterMergeNode
extends ScatterPlacementNode


func get_type_id() -> StringName:
	return &"placement_merge"


func get_caption() -> String:
	return "Merge Placement"


func get_color() -> Color:
	return Color("9b70c9")


func get_input_ports() -> Array[ScatterPort]:
	return [
		ScatterPort.new(&"a", "A", ScatterValueTypeRegistry.INSTANCES),
		ScatterPort.new(&"b", "B", ScatterValueTypeRegistry.INSTANCES),
	]


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var a := inputs.instances(&"a")
	var b := inputs.instances(&"b")
	var result := a.duplicate_instances() if a != null else ScatterInstances.new()
	if b != null:
		result.append_instances(b, context.maximum_instances)
	result.limit(context.maximum_instances)
	return result
