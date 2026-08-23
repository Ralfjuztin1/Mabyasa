@tool
class_name ScatterProjectNode
extends ScatterPlacementNode

@export var ray_direction := Vector3.DOWN
@export_range(0.0, 1000000.0, 0.1) var ray_length := 10.0
@export var ray_offset := 1.0
@export var remove_points_on_miss := true
@export var align_with_collision_normal := false
@export_range(0.0, 90.0, 1.0) var max_slope := 90.0
@export_flags_3d_physics var collision_mask := 1
@export_flags_3d_physics var exclude_mask := 0


func get_type_id() -> StringName:
	return &"project"


func get_caption() -> String:
	return "Project On Colliders"


func get_category() -> StringName:
	return &"Transform"


func get_color() -> Color:
	return Color("a376bc")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterTransformOps.apply_projection(
		buffer,
		context.target,
		ray_direction,
		ray_length,
		ray_offset,
		remove_points_on_miss,
		align_with_collision_normal,
		max_slope,
		collision_mask,
		exclude_mask,
	)
	return buffer
