@tool
class_name ScatterRandomColorNode
extends ScatterPlacementNode

@export var from_color := Color.WHITE
@export var to_color := Color.WHITE


func get_type_id() -> StringName:
	return &"random_color"


func get_caption() -> String:
	return "Random Color"


func get_category() -> StringName:
	return &"Data"


func get_color() -> Color:
	return Color("8b929e")


func supports_seed() -> bool:
	return true


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	buffer.normalize()
	ScatterDataOps.randomize_colors(
		buffer.colors,
		buffer.transforms.size(),
		from_color,
		to_color,
		context.random_for(self),
	)
	return buffer
