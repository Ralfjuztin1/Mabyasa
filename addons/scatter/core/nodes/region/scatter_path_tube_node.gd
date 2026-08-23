@tool
class_name ScatterPathTubeNode
extends ScatterRegionNode

@export_range(0.001, 1000000.0, 0.1) var radius := 1.0


func get_type_id() -> StringName:
	return &"path_tube_region"


func get_caption() -> String:
	return "Path Tube Region"


func get_color() -> Color:
	return Color("3fae9a")


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"path", "Path", ScatterValueTypeRegistry.PATH)]


func evaluate_value(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	return ScatterPathTubeRegion.new(inputs.path(), radius)
