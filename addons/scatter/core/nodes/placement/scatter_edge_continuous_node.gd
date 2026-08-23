@tool
class_name ScatterEdgeContinuousNode
extends ScatterPlacementSourceNode


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"path", "Path", ScatterValueTypeRegistry.PATH)]

@export_range(0.001, 1000000.0, 0.1) var item_length := 2.0
@export var ignore_slopes := false


func get_type_id() -> StringName:
	return &"edge_continuous"


func get_caption() -> String:
	return "Along Edge Continuous"


func get_color() -> Color:
	return Color("4b9b72")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterCreationOps.append_path_continuous(
		buffer,
		inputs.path(),
		item_length,
		context.maximum_instances,
	)
	return buffer
