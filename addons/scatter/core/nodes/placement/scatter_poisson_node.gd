@tool
class_name ScatterPoissonNode
extends ScatterPlacementSourceNode

@export_range(0.001, 1000000.0, 0.05) var radius := 1.0
@export_range(1, 100, 1) var samples_before_rejection := 15
@export_range(1, 1000000, 1) var max_points := 10000


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"shape", "Shape", ScatterValueTypeRegistry.SHAPE)]


func get_type_id() -> StringName:
	return &"create_poisson"


func get_caption() -> String:
	return "Poisson Placement"


func get_color() -> Color:
	return Color("4b9b72")


func supports_seed() -> bool:
	return true


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterCreationOps.append_poisson(
		buffer,
		inputs.shape(),
		radius,
		samples_before_rejection,
		max_points,
		context.random_for(self),
		context.maximum_instances,
	)
	return buffer
