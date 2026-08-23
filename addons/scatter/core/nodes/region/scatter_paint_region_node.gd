@tool
class_name ScatterPaintRegionNode
extends ScatterRegionNode

@export var strokes: Array[ScatterPaintStroke] = []
@export_range(0.01, 1000.0, 0.05) var depth := 0.35
@export_range(-1000.0, 1000.0, 0.01) var surface_offset := 0.0


func get_type_id() -> StringName:
	return &"paint_region"


func get_caption() -> String:
	return "Paint Region"


func get_color() -> Color:
	return Color("5d83b3")


func evaluate_value(context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	if space == ScatterSpace.Type.LOCAL or context == null or not is_instance_valid(context.target):
		return ScatterPaintRegion.new(strokes, depth, surface_offset)
	var transform := ScatterSpace.authored_to_local(space, context.target.global_transform if context.target.is_inside_tree() else context.target.transform)
	var converted: Array[ScatterPaintStroke] = []
	var radius_scale := maxf(transform.basis.x.length(), maxf(transform.basis.y.length(), transform.basis.z.length()))
	for stroke in strokes:
		converted.append(ScatterPaintStroke.create(
			transform * stroke.position,
			(transform.basis * stroke.normal).normalized(),
			stroke.radius * radius_scale,
		))
	return ScatterPaintRegion.new(converted, depth * radius_scale, surface_offset * radius_scale)
