@tool
class_name ScatterUnionNode
extends ScatterRegionOperatorNode

@export_enum("From A:0", "From B:1", "Bounds Center:2") var pivot: int = ScatterRegionValue.BooleanPivot.BOUNDS_CENTER


func get_type_id() -> StringName:
	return &"region_union"


func get_caption() -> String:
	return "Union"


func get_color() -> Color:
	return Color("3fae9a")


func evaluate_value(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	return ScatterUnionRegion.new(inputs.shape(&"a"), inputs.shape(&"b"), pivot)
