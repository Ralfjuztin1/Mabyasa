@tool
@abstract
class_name ScatterRegionNode
extends ScatterNode

@export_enum("Global:0", "Local:1") var space: int = ScatterSpace.Type.LOCAL


func get_category() -> StringName:
	return &"Shape"


func get_input_ports() -> Array[ScatterPort]:
	return []


func get_output_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"region", "Region", ScatterValueTypeRegistry.REGION)]


func freeze_regular_region(context: ScatterEvaluationContext, region: ScatterRegularRegionValue) -> ScatterRegularRegionValue:
	if space == ScatterSpace.Type.LOCAL or context == null or not is_instance_valid(context.target):
		return region
	return ScatterTransformedRegularRegion.new(region, ScatterSpace.authored_to_local(space, context.target.global_transform if context.target.is_inside_tree() else context.target.transform))


func evaluate_disabled_value(_context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	return ScatterEmptyRegion.new()
