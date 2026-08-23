@tool
class_name ScatterPathNode
extends ScatterNode

@export var points := PackedVector3Array([Vector3(-5, 0, 0), Vector3(5, 0, 0)])
@export var closed := false
@export_enum("Global:0", "Local:1") var space: int = ScatterSpace.Type.LOCAL


func get_type_id() -> StringName:
	return &"shape_path"


func get_caption() -> String:
	return "Path"


func get_category() -> StringName:
	return &"Shape"


func get_input_ports() -> Array[ScatterPort]:
	return []


func get_output_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"path", "Path", ScatterValueTypeRegistry.PATH)]


func get_color() -> Color:
	return Color("5d83b3")


func evaluate_value(context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	if space == ScatterSpace.Type.LOCAL or context == null or not is_instance_valid(context.target):
		return ScatterPathValue.new(points, closed)
	var transform := ScatterSpace.authored_to_local(space, context.target.global_transform if context.target.is_inside_tree() else context.target.transform)
	return ScatterPathValue.new(points, closed, transform)


func evaluate_disabled_value(_context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	return ScatterPathValue.new()
