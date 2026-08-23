@tool
@abstract
class_name ScatterPlacementSourceNode
extends ScatterPlacementNode


func get_input_ports() -> Array[ScatterPort]:
	return []


func source_only() -> bool:
	return true


func input_instances(_context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterInstances:
	return ScatterInstances.new()
