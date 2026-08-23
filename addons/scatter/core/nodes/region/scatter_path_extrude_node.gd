@tool
class_name ScatterPathExtrudeNode
extends ScatterRegionNode

@export var normal := Vector3.UP
@export_range(0.0, 1000000.0, 0.1) var forward := 1.0
@export_range(0.0, 1000000.0, 0.1) var backward := 0.0
@export_enum("Projected Centroid:0", "Projected Path Origin:1") var pivot: int = ScatterPathExtrudeRegion.Pivot.PROJECTED_CENTROID


func get_type_id() -> StringName:
	return &"path_extrude_region"


func get_caption() -> String:
	return "Path Extrude"


func get_color() -> Color:
	return Color("3fae9a")


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"path", "Path", ScatterValueTypeRegistry.PATH)]


func evaluate_value(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	return ScatterPathExtrudeRegion.new(inputs.path(), normal, forward, backward, pivot)


func validate(_context: ScatterEvaluationContext) -> PackedStringArray:
	var errors := PackedStringArray()
	if normal.is_zero_approx():
		errors.append("Path Extrude normal must be non-zero.")
	if forward < 0.0 or backward < 0.0:
		errors.append("Path Extrude forward and backward distances must be non-negative.")
	return errors
