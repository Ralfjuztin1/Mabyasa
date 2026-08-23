@tool
class_name ScatterPathEditorExtension
extends ScatterNodeEditorExtension


func draw_gizmo(context: ScatterNodeEditorContext, sink: ScatterGizmoSink) -> void:
	var node := context.node as ScatterPathNode
	if node == null:
		return
	var evaluation := ScatterEvaluationContext.create(context.target, context.graph, ScatterEvaluationSession.new())
	var path := node.evaluate_value(evaluation, ScatterNodeInputs.new()) as ScatterPathValue
	var points := path.get_points_local()
	var lines := PackedVector3Array()
	for index in maxi(0, points.size() - 1):
		lines.append(points[index])
		lines.append(points[index + 1])
	if node.closed and points.size() > 2:
		lines.append(points[-1])
		lines.append(points[0])
	sink.add_lines(lines, &"path")
	var ids := PackedInt32Array()
	for index in points.size():
		ids.append(index)
	sink.add_handles(points, ids)


func get_handle_name(_context: ScatterNodeEditorContext, handle_id: int) -> String:
	return "Path Point %d" % (handle_id + 1)


func get_handle_value(context: ScatterNodeEditorContext, _handle_id: int) -> Variant:
	return (context.node as ScatterPathNode).points.duplicate()


func set_handle(context: ScatterNodeEditorContext, handle_id: int, camera: Camera3D, screen_position: Vector2) -> void:
	var node := context.node as ScatterPathNode
	if node == null or handle_id < 0 or handle_id >= node.points.size():
		return
	var current_world := node.points[handle_id] if node.space == ScatterSpace.Type.GLOBAL else context.target.to_global(node.points[handle_id])
	var normal := camera.global_transform.basis.z.normalized()
	var plane := Plane(normal, normal.dot(current_world))
	var world_position = plane.intersects_ray(camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
	if world_position == null:
		return
	var points := node.points.duplicate()
	points[handle_id] = world_position if node.space == ScatterSpace.Type.GLOBAL else context.target.to_local(world_position)
	node.points = points
	_notify(context)


func commit_handle(context: ScatterNodeEditorContext, restore: Variant, cancel: bool) -> void:
	var node := context.node as ScatterPathNode
	if node == null:
		return
	var previous: PackedVector3Array = restore
	var current := node.points.duplicate()
	if cancel:
		node.points = previous
		_notify(context)
		return
	if current == previous or context.undo_redo == null:
		return
	context.undo_redo.create_action("Move Scatter Path Point", UndoRedo.MERGE_DISABLE, context.target)
	context.undo_redo.add_do_property(node, &"points", current)
	context.undo_redo.add_undo_property(node, &"points", previous)
	context.undo_redo.add_do_method(self, "_notify", context)
	context.undo_redo.add_undo_method(self, "_notify", context)
	context.undo_redo.commit_action(false)


func _notify(context: ScatterNodeEditorContext) -> void:
	if context.graph != null:
		context.graph.emit_changed()
	if is_instance_valid(context.target):
		context.target.update_gizmos()
	if context.changed.is_valid():
		context.changed.call()
