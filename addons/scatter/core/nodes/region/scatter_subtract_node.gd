@tool
class_name ScatterSubtractNode
extends ScatterRegionOperatorNode

@export_enum("From A:0", "From B:1", "Bounds Center:2") var pivot: int = ScatterRegionValue.BooleanPivot.FROM_A


func get_type_id() -> StringName:
	return &"region_subtract"


func get_caption() -> String:
	return "Subtract"


func get_color() -> Color:
	return Color("3fae9a")


func evaluate_value(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	return ScatterSubtractRegion.new(inputs.shape(&"a"), inputs.shape(&"b"), pivot)
