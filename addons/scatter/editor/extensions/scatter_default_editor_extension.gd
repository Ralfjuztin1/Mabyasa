@tool
class_name ScatterDefaultEditorExtension
extends ScatterNodeEditorExtension


func draw_gizmo(context: ScatterNodeEditorContext, sink: ScatterGizmoSink) -> void:
	if context == null or context.node == null:
		return
	var ports := context.node.get_output_ports()
	if ports.is_empty():
		return
	for value in _selected_values(context):
		if value is ScatterRegionValue:
			var lines := PackedVector3Array()
			for edge in (value as ScatterRegionValue).get_edges():
				lines.append(edge.a)
				lines.append(edge.b)
			sink.add_lines(lines)
		elif value is ScatterPathValue:
			var lines := PackedVector3Array()
			var path := value as ScatterPathValue
			var points := path.get_points_local()
			var segment_count := points.size() if path.is_closed() and points.size() > 1 else maxi(0, points.size() - 1)
			for index in segment_count:
				lines.append(points[index])
				lines.append(points[(index + 1) % points.size()])
			sink.add_lines(lines, &"path")
		elif value is ScatterInstances:
			var lines := PackedVector3Array()
			var instances := value as ScatterInstances
			var amount := mini(2000, instances.transforms.size())
			for index in amount:
				var transform := instances.transforms[index]
				var radius := 0.12
				lines.append(transform.origin - transform.basis.x.normalized() * radius)
				lines.append(transform.origin + transform.basis.x.normalized() * radius)
				lines.append(transform.origin - transform.basis.y.normalized() * radius)
				lines.append(transform.origin + transform.basis.y.normalized() * radius)
				lines.append(transform.origin - transform.basis.z.normalized() * radius)
				lines.append(transform.origin + transform.basis.z.normalized() * radius)
			sink.add_lines(lines, &"instances")


func _selected_values(context: ScatterNodeEditorContext) -> Array[ScatterValue]:
	var result: Array[ScatterValue] = []
	var plan := ScatterGraphCompiler.compile(context.graph)
	if not plan.has_errors():
		var session := ScatterEvaluationSession.new()
		var evaluation := ScatterEvaluationContext.create(context.target, context.graph, session)
		ScatterGraphEvaluator.execute(plan, evaluation)
		var outputs: ScatterNodeOutputs = session.evaluation_cache.get(evaluation.cache_key(context.node.node_id))
		if outputs != null:
			for port in context.node.get_output_ports():
				var value := outputs.get_value(port.id)
				if value != null:
					result.append(value)
			return result
	# Disconnected source nodes can still provide a useful standalone preview.
	if context.node.get_input_ports().is_empty():
		var evaluation := ScatterEvaluationContext.create(context.target, context.graph, ScatterEvaluationSession.new())
		var value := context.node.evaluate_value(evaluation, ScatterNodeInputs.new())
		if value != null:
			result.append(value)
	return result
