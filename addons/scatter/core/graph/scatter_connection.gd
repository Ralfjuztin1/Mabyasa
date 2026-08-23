@tool
class_name ScatterConnection
extends Resource

@export var from_node_id := 0
@export var from_port_id: StringName = &"output"
@export var to_node_id := 0
@export var to_port_id: StringName = &"input"
@export var order := 0


static func create(
		p_from_node_id: int,
		p_from_port_id: StringName,
		p_to_node_id: int,
		p_to_port_id: StringName,
		p_order := 0,
) -> ScatterConnection:
	var connection := ScatterConnection.new()
	connection.from_node_id = p_from_node_id
	connection.from_port_id = p_from_port_id
	connection.to_node_id = p_to_node_id
	connection.to_port_id = p_to_port_id
	connection.order = p_order
	return connection


func matches(other: ScatterConnection) -> bool:
	return (
		from_node_id == other.from_node_id
		and from_port_id == other.from_port_id
		and to_node_id == other.to_node_id
		and to_port_id == other.to_port_id
		and order == other.order
	)
