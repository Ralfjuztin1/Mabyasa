@tool
class_name ScatterBuildService
extends RefCounted

const MAXIMUM_INSTANCES := 1_000_000


static func build_target(
		target: MultiMeshInstance3D,
		graph: ScatterGraph = null,
		session: ScatterEvaluationSession = null,
		resolver: ScatterGraphResolver = null,
) -> ScatterBuildResult:
	if not is_instance_valid(target):
		return ScatterBuildResult.failure("Target is no longer valid.")
	if graph == null:
		graph = ScatterGraphAttachment.get_graph(target)
	if graph == null:
		return ScatterBuildResult.failure("Target has no Scatter graph.")
	if session == null:
		session = ScatterEvaluationSession.new()
	var target_id := target.get_instance_id()
	if session.visited_targets.has(target_id):
		return ScatterBuildResult.failure("Proxy cycle detected.")
	session.visited_targets[target_id] = true
	var final_output := graph.final_output_node()
	if final_output == null:
		session.visited_targets.erase(target_id)
		return ScatterBuildResult.failure("Scatter graph has no Final Output node.")
	var context := ScatterEvaluationContext.create(target, graph, session)
	context.resolver = resolver if resolver != null else ScatterGraphResolver.new()
	context.maximum_instances = MAXIMUM_INSTANCES
	var plan := ScatterGraphCompiler.compile(graph)
	for diagnostic in plan.diagnostics:
		session.diagnostics.append(diagnostic)
	var outputs := ScatterGraphEvaluator.execute(plan, context) if not plan.has_errors() else null
	session.visited_targets.erase(target_id)
	var result := ScatterBuildResult.new()
	for diagnostic in session.diagnostics:
		if diagnostic.severity == ScatterDiagnostic.Severity.ERROR:
			result.errors.append(diagnostic)
		else:
			result.warnings.append(diagnostic)
	if outputs == null or not result.errors.is_empty():
		result.ok = false
		result.error = result.errors[0].message if not result.errors.is_empty() else "Scatter evaluation failed."
		return result
	var value := outputs.get_value(&"result")
	if not value is ScatterInstances:
		return ScatterBuildResult.failure("Final Output did not produce instance data.")
	result.instances = value as ScatterInstances
	result.instances.limit(MAXIMUM_INSTANCES)
	result.output_counts = session.output_counts.duplicate()
	return result
