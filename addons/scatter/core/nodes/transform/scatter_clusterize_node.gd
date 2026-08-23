@tool
class_name ScatterClusterizeNode
extends ScatterPlacementNode

@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.tres", "*.res") var mask := ""
@export var mask_rotation := 0.0
@export var mask_offset := Vector2.ZERO
@export var mask_scale := Vector2.ONE
@export_range(0.001, 1000000.0, 1.0) var pixel_to_unit_ratio := 64.0
@export_range(0.0, 1.0, 0.01) var remove_below := 0.1
@export_range(0.0, 1.0, 0.01) var remove_above := 1.0
@export var scale_transforms := true


func get_type_id() -> StringName:
	return &"clusterize"


func get_caption() -> String:
	return "Clusterize by Mask"


func get_category() -> StringName:
	return &"Transform"


func get_color() -> Color:
	return Color("a376bc")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterTransformOps.apply_clusterize(
		buffer,
		mask,
		mask_rotation,
		mask_offset,
		mask_scale,
		pixel_to_unit_ratio,
		remove_below,
		remove_above,
		scale_transforms,
	)
	return buffer
