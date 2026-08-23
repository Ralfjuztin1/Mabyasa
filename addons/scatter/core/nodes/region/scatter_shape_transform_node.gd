@tool
class_name ScatterShapeTransformNode
extends ScatterNode

@export var position := Vector3.ZERO
@export var rotation := Vector3.ZERO
@export var scale := Vector3.ONE
@export_storage var geometry_type: StringName = ScatterValueTypeRegistry.DYNAMIC_GEOMETRY

const PORT_ID := &"geometry"


func get_type_id() -> StringName:
	return &"shape_transform"


func get_caption() -> String:
	return "Shape Transform"


func get_category() -> StringName:
	return &"Shape"


func get_color() -> Color:
	return Color("5d83b3")


func get_input_ports() -> Array[ScatterPort]:
	return [_geometry_port()]


func get_output_ports() -> Array[ScatterPort]:
	return [_geometry_port()]


func evaluate_value(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var value := inputs.first(PORT_ID)
	if value is ScatterPathValue:
		return _transform_path(value as ScatterPathValue, _transform())
	if value is ScatterShapeValue:
		return _transform_shape(value as ScatterShapeValue, _transform())
	return _empty_value()


func evaluate_disabled_value(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var value := inputs.first(PORT_ID)
	return value if value != null else _empty_value()


func validate(_context: ScatterEvaluationContext) -> PackedStringArray:
	var errors := PackedStringArray()
	if absf(scale.x) <= 0.000001 or absf(scale.y) <= 0.000001 or absf(scale.z) <= 0.000001:
		errors.append("Shape Transform scale components must be non-zero.")
	if geometry_type != ScatterValueTypeRegistry.DYNAMIC_GEOMETRY and not ScatterValueTypeRegistry.is_geometry_value_type(geometry_type):
		errors.append("Shape Transform has an invalid geometry port type.")
	return errors


func is_dynamic_port_type(port_id: StringName, _is_output: bool) -> bool:
	return port_id == PORT_ID


func get_dynamic_port_type(port_id: StringName, _is_output: bool) -> StringName:
	return geometry_type if port_id == PORT_ID else &""


func propose_dynamic_port_type(
		port_id: StringName,
		is_output: bool,
		peer_type: StringName,
) -> StringName:
	if port_id != PORT_ID or not ScatterValueTypeRegistry.is_geometry_value_type(peer_type):
		return &""
	# An input reveals the actual produced type and is therefore always exact.
	# An output keeps a more precise inferred input type when the consumer can
	# accept it; otherwise the new output constraint wins.
	if (
		is_output
		and geometry_type != ScatterValueTypeRegistry.DYNAMIC_GEOMETRY
		and ScatterValueTypeRegistry.is_assignable(geometry_type, peer_type)
	):
		return geometry_type
	return peer_type


func set_dynamic_port_type(type_id: StringName) -> void:
	if type_id == ScatterValueTypeRegistry.DYNAMIC_GEOMETRY or ScatterValueTypeRegistry.is_geometry_value_type(type_id):
		geometry_type = type_id
		emit_changed()


func infer_dynamic_port_type(
		graph: ScatterGraph,
		remaining_connections: Array[ScatterConnection],
) -> StringName:
	for connection in remaining_connections:
		if connection.to_node_id != node_id or connection.to_port_id != PORT_ID:
			continue
		var source := graph.find_node(connection.from_node_id)
		var port := source.output_port(connection.from_port_id) if source != null else null
		if port != null and ScatterValueTypeRegistry.is_geometry_value_type(port.type_id):
			return port.type_id
	var inferred := ScatterValueTypeRegistry.DYNAMIC_GEOMETRY
	for connection in remaining_connections:
		if connection.from_node_id != node_id or connection.from_port_id != PORT_ID:
			continue
		var target := graph.find_node(connection.to_node_id)
		var port := target.input_port(connection.to_port_id) if target != null else null
		if port == null or not ScatterValueTypeRegistry.is_geometry_value_type(port.type_id):
			continue
		if inferred == ScatterValueTypeRegistry.DYNAMIC_GEOMETRY or ScatterValueTypeRegistry.is_assignable(port.type_id, inferred):
			inferred = port.type_id
	return inferred


func _geometry_port() -> ScatterPort:
	return ScatterPort.new(
		PORT_ID,
		_type_label(),
		geometry_type,
		false,
		true,
		true,
		ScatterValueTypeRegistry.DYNAMIC_GEOMETRY,
	)


func _type_label() -> String:
	match geometry_type:
		ScatterValueTypeRegistry.REGION:
			return "Region"
		ScatterValueTypeRegistry.REGULAR_REGION:
			return "Regular Region"
		ScatterValueTypeRegistry.PATH:
			return "Path"
		_:
			return "Shape"


func _empty_value() -> ScatterValue:
	match geometry_type:
		ScatterValueTypeRegistry.REGULAR_REGION:
			return ScatterBoxRegion.new(Vector3.ZERO, Vector3.ZERO)
		ScatterValueTypeRegistry.PATH:
			return ScatterPathValue.new()
		_:
			return ScatterEmptyRegion.new()


func _transform() -> Transform3D:
	# Godot's Basis.scaled() left-multiplies (S * R), which scales in the
	# parent axes after rotation. Shape TRS uses the conventional local order
	# R * S, so points are scaled first and then rotated.
	return Transform3D(Basis.from_euler(rotation * PI / 180.0).scaled_local(scale), position)


static func _transform_shape(shape: ScatterShapeValue, transform: Transform3D) -> ScatterShapeValue:
	var frame := shape.get_local_transform()
	var local_mapping := frame * transform * frame.affine_inverse()
	if shape is ScatterRegularRegionValue:
		return ScatterTransformedRegularRegion.new(shape as ScatterRegularRegionValue, local_mapping)
	if shape is ScatterRegionValue:
		return ScatterTransformedRegion.new(shape as ScatterRegionValue, local_mapping)
	return ScatterTransformedShape.new(shape, local_mapping)


static func _transform_path(path: ScatterPathValue, transform: Transform3D) -> ScatterPathValue:
	var frame := path.get_local_transform()
	return path.transformed_local(frame * transform * frame.affine_inverse())
