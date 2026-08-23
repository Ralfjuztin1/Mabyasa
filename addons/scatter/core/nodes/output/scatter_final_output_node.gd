@tool
class_name ScatterFinalOutputNode
extends ScatterNode


func get_type_id() -> StringName:
	return &"final_output"


func get_caption() -> String:
	return "Final Output"


func get_category() -> StringName:
	return &"Output"


func get_color() -> Color:
	return Color("d9aa56")


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"instances", "Instances", ScatterValueTypeRegistry.INSTANCES, true)]


func get_output_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"result", "Result", ScatterValueTypeRegistry.INSTANCES, false, false, false)]


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var combined := ScatterInstances.new()
	for value in inputs.all(&"instances"):
		if not value is ScatterInstances:
			continue
		var before := combined.transforms.size()
		combined.append_instances(value as ScatterInstances, context.maximum_instances)
		if before + (value as ScatterInstances).transforms.size() > context.maximum_instances:
			context.add_warning(&"instance_limit", node_id, "Final Output truncated instances at the build limit.", {"limit": context.maximum_instances})
		if combined.transforms.size() >= context.maximum_instances:
			break
	combined.normalize()
	return combined


func can_disable() -> bool:
	return false


func is_deletable() -> bool:
	return false
