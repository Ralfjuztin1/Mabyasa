@tool
class_name ScatterSetColorNode
extends ScatterPlacementNode

@export var color := Color.WHITE


func get_type_id() -> StringName:
	return &"set_color"


func get_caption() -> String:
	return "Set Color"


func get_category() -> StringName:
	return &"Data"


func get_color() -> Color:
	return Color("8b929e")


func supports_seed() -> bool:
	return false


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	buffer.normalize()
	ScatterDataOps.set_colors(
		buffer.colors,
		buffer.transforms.size(),
		color,
	)
	return buffer
