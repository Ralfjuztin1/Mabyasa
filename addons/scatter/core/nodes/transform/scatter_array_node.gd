@tool
class_name ScatterArrayNode
extends ScatterPlacementNode

@export_range(1, 10000, 1) var amount := 1
@export_range(-1, 10000, 1) var min_amount := -1
@export var local_offset := false
@export var offset := Vector3(2, 0, 0)
@export var local_rotation := false
@export var rotation := Vector3.ZERO
@export var individual_rotation_pivots := true
@export var rotation_pivot := Vector3.ZERO
@export var local_scale := true
@export var scale := Vector3.ONE
@export var randomize_indices := true


func get_type_id() -> StringName:
	return &"array"


func get_caption() -> String:
	return "Array"


func get_category() -> StringName:
	return &"Transform"


func get_color() -> Color:
	return Color("4b9b72")


func supports_seed() -> bool:
	return true


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterTransformOps.apply_array(
		buffer,
		amount,
		min_amount,
		local_offset,
		offset,
		local_rotation,
		rotation,
		individual_rotation_pivots,
		rotation_pivot,
		local_scale,
		scale,
		randomize_indices,
		context.random_for(self),
		context.maximum_instances,
	)
	return buffer
