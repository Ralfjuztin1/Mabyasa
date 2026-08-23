@tool
class_name ScatterEdgeEvenNode
extends ScatterPlacementSourceNode


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"path", "Path", ScatterValueTypeRegistry.PATH)]

@export_range(0.001, 1000000.0, 0.1) var spacing := 1.0
@export var offset := 0.0
@export var align_to_path := false


func get_type_id() -> StringName:
	return &"edge_even"


func get_caption() -> String:
	return "Along Edge Even"


func get_color() -> Color:
	return Color("4b9b72")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterCreationOps.append_path_even(
		buffer,
		inputs.path(),
		spacing,
		offset,
		align_to_path,
		context.maximum_instances,
	)
	return buffer
