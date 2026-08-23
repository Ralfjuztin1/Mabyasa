@tool
class_name ScatterSphereNode
extends ScatterRegionNode

@export var center := Vector3.ZERO
@export_range(0.001, 1000000.0, 0.1) var radius := 5.0


func get_type_id() -> StringName:
	return &"shape_sphere"


func get_caption() -> String:
	return "Sphere Region"


func get_color() -> Color:
	return Color("5d83b3")


func get_output_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"region", "Regular Region", ScatterValueTypeRegistry.REGULAR_REGION)]


func evaluate_value(context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	return freeze_regular_region(context, ScatterSphereRegion.new(center, radius))
