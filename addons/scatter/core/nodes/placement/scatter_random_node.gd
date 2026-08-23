@tool
class_name ScatterRandomNode
extends ScatterPlacementSourceNode

@export_range(0, 1000000, 1) var amount := 100


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"shape", "Shape", ScatterValueTypeRegistry.SHAPE)]


func get_type_id() -> StringName:
	return &"create_random"


func get_caption() -> String:
	return "Random Placement"


func get_color() -> Color:
	return Color("4b9b72")


func supports_seed() -> bool:
	return true


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	var sampling := ScatterCreationOps.append_random(
		buffer,
		inputs.shape(),
		amount,
		context.random_for(self),
		context.maximum_instances,
	)
	if sampling.generated < sampling.requested:
		context.add_warning(&"rejection_budget_exhausted", node_id, "Random sampling exhausted its deterministic rejection budget.", sampling)
	return buffer
