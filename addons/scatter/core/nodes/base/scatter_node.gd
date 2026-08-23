@tool
@abstract
class_name ScatterNode
extends Resource

@export var node_id := 0
@export var graph_position := Vector2.ZERO
@export var enabled := true
@export var override_seed := false
@export var custom_seed := 0


@abstract func get_type_id() -> StringName


@abstract func get_caption() -> String


@abstract func get_category() -> StringName


@abstract func get_input_ports() -> Array[ScatterPort]


@abstract func get_output_ports() -> Array[ScatterPort]


@abstract func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue


func evaluate(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterNodeOutputs:
	var ports := get_output_ports()
	if ports.is_empty():
		return ScatterNodeOutputs.new()
	return ScatterNodeOutputs.single(ports[0].id, evaluate_value(context, inputs))


func evaluate_disabled(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterNodeOutputs:
	var ports := get_output_ports()
	if ports.is_empty():
		return ScatterNodeOutputs.new()
	return ScatterNodeOutputs.single(ports[0].id, evaluate_disabled_value(context, inputs))


func evaluate_disabled_value(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	for port in get_input_ports():
		var value := inputs.first(port.id)
		if value != null:
			return value
	return null


func prepare_input_context(
		_port_id: StringName,
		context: ScatterEvaluationContext,
		_inputs: ScatterNodeInputs,
) -> ScatterEvaluationContext:
	return context


func get_color() -> Color:
	return Color("657383")


func get_description() -> String:
	return get_caption()


func supports_seed() -> bool:
	return false


func can_disable() -> bool:
	return true


func is_deletable() -> bool:
	return true


func validate(_context: ScatterEvaluationContext) -> PackedStringArray:
	return PackedStringArray()


func is_dynamic_port_type(_port_id: StringName, _is_output: bool) -> bool:
	return false


func get_dynamic_port_type(_port_id: StringName, _is_output: bool) -> StringName:
	return &""


func propose_dynamic_port_type(
		_port_id: StringName,
		_is_output: bool,
		_peer_type: StringName,
) -> StringName:
	return &""


func set_dynamic_port_type(_type_id: StringName) -> void:
	pass


func infer_dynamic_port_type(
		_graph: ScatterGraph,
		_remaining_connections: Array[ScatterConnection],
) -> StringName:
	return &""


func input_port(port_id: StringName) -> ScatterPort:
	for port in get_input_ports():
		if port.id == port_id:
			return port
	return null


func output_port(port_id: StringName) -> ScatterPort:
	for port in get_output_ports():
		if port.id == port_id:
			return port
	return null
