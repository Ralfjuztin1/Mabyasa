@tool
@abstract
class_name ScatterPlacementNode
extends ScatterNode


func get_category() -> StringName:
	return &"Placement"


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"instances", "Instances", ScatterValueTypeRegistry.INSTANCES)]


func get_output_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"instances", "Instances", ScatterValueTypeRegistry.INSTANCES)]


func source_only() -> bool:
	return false


func input_instances(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterInstances:
	var value := inputs.instances()
	return value.duplicate_instances() if value != null else ScatterInstances.new()


func evaluate_disabled_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	return input_instances(context, inputs)
