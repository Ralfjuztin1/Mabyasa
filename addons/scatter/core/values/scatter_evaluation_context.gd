@tool
class_name ScatterEvaluationContext
extends RefCounted

var target: MultiMeshInstance3D
var graph: ScatterGraph
var session: ScatterEvaluationSession
var resolver: ScatterGraphResolver
var maximum_instances := 1_000_000


static func create(
		p_target: MultiMeshInstance3D,
		p_graph: ScatterGraph,
		p_session: ScatterEvaluationSession,
) -> ScatterEvaluationContext:
	var context := ScatterEvaluationContext.new()
	context.target = p_target
	context.graph = p_graph
	context.session = p_session
	context.resolver = ScatterGraphResolver.new()
	return context


func with_target(p_target: MultiMeshInstance3D, p_graph: ScatterGraph) -> ScatterEvaluationContext:
	var copy := ScatterEvaluationContext.create(p_target, p_graph, session)
	copy.maximum_instances = maximum_instances
	copy.resolver = resolver
	return copy


func random_for(node: ScatterNode) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = node.custom_seed if node.override_seed else graph.seed ^ (node.node_id * 0x45d9f3b)
	return rng


func add_warning(code: StringName, node_id: int, message: String, details := {}) -> void:
	session.diagnostics.append(ScatterDiagnostic.new(ScatterDiagnostic.Severity.WARNING, code, node_id, message, details))


func add_error(code: StringName, node_id: int, message: String, details := {}) -> void:
	session.diagnostics.append(ScatterDiagnostic.new(ScatterDiagnostic.Severity.ERROR, code, node_id, message, details))


func cache_key(node_id: int) -> String:
	return "%d:%d:%d" % [
		graph.get_instance_id() if graph != null else 0,
		target.get_instance_id() if is_instance_valid(target) else 0,
		node_id,
	]
