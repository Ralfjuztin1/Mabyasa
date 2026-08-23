@tool
@abstract
class_name ScatterRegionOperatorNode
extends ScatterNode


func get_category() -> StringName:
	return &"Shape"


func get_input_ports() -> Array[ScatterPort]:
	return [
		ScatterPort.new(&"a", "A", ScatterValueTypeRegistry.SHAPE),
		ScatterPort.new(&"b", "B", ScatterValueTypeRegistry.SHAPE),
	]


func get_output_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"shape", "Shape", ScatterValueTypeRegistry.SHAPE)]


func evaluate_disabled_value(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	return inputs.shape(&"a") if inputs.shape(&"a") != null else ScatterEmptyRegion.new()
