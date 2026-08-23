@tool
class_name ScatterGridNode
extends ScatterPlacementSourceNode

@export var spacing := Vector3(2, 2, 2)
@export var offset := Vector3.ZERO
@export_enum("Global:0", "Local:1", "Instance:2") var space: int = ScatterSpace.Type.LOCAL


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"shape", "Shape", ScatterValueTypeRegistry.SHAPE)]


func get_type_id() -> StringName:
	return &"create_grid"


func get_caption() -> String:
	return "Grid Placement"


func get_color() -> Color:
	return Color("4b9b72")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	var shape := inputs.shape()
	var grid_to_local := _grid_to_local(context, shape)
	if absf(grid_to_local.basis.determinant()) <= 0.000001:
		context.add_error(&"invalid_grid_space", node_id, "Grid Placement space transform must be invertible.")
		return buffer
	ScatterCreationOps.append_grid(buffer, shape, spacing, offset, grid_to_local, context.maximum_instances)
	return buffer


func _grid_to_local(context: ScatterEvaluationContext, shape: ScatterShapeValue) -> Transform3D:
	if space == ScatterSpace.Type.INSTANCE:
		return shape.get_local_transform() if shape != null else Transform3D.IDENTITY
	if space == ScatterSpace.Type.GLOBAL and context != null and is_instance_valid(context.target):
		var target_transform := context.target.global_transform if context.target.is_inside_tree() else context.target.transform
		return target_transform.affine_inverse()
	return Transform3D.IDENTITY
