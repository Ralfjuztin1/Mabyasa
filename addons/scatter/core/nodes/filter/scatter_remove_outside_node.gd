@tool
class_name ScatterRemoveOutsideNode
extends ScatterPlacementNode


func get_type_id() -> StringName:
	return &"remove_outside"


func get_caption() -> String:
	return "Remove Outside"


func get_category() -> StringName:
	return &"Filter"


func get_color() -> Color:
	return Color("bd5b60")


func get_input_ports() -> Array[ScatterPort]:
	return [
		ScatterPort.new(&"instances", "Instances", ScatterValueTypeRegistry.INSTANCES),
		ScatterPort.new(&"shape", "Shape", ScatterValueTypeRegistry.SHAPE),
	]


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterFilterOps.remove_outside(buffer, inputs.shape())
	return buffer
