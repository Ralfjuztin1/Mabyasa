@tool
class_name ScatterBoxNode
extends ScatterRegionNode

@export var center := Vector3.ZERO
@export var size := Vector3(10, 1, 10)
@export var rotation := Vector3.ZERO


func get_type_id() -> StringName:
	return &"shape_box"


func get_caption() -> String:
	return "Box Region"


func get_color() -> Color:
	return Color("5d83b3")


func get_output_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"region", "Regular Region", ScatterValueTypeRegistry.REGULAR_REGION)]


func evaluate_value(context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	return freeze_regular_region(context, ScatterBoxRegion.new(center, size, rotation))
