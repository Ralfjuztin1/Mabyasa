@tool
class_name ScatterEdgeRandomNode
extends ScatterPlacementSourceNode

@export_range(0, 1000000, 1) var instance_count := 10
@export var align_to_path := false


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"path", "Path", ScatterValueTypeRegistry.PATH)]


func get_type_id() -> StringName:
	return &"edge_random"


func get_caption() -> String:
	return "Along Edge Random"


func get_color() -> Color:
	return Color("4b9b72")


func supports_seed() -> bool:
	return true


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterCreationOps.append_path_random(
		buffer,
		inputs.path(),
		instance_count,
		align_to_path,
		context.random_for(self),
		context.maximum_instances,
	)
	return buffer
