@tool
class_name ScatterPaintEditorExtension
extends ScatterNodeEditorExtension


func draw_gizmo(context: ScatterNodeEditorContext, sink: ScatterGizmoSink) -> void:
	var node := context.node as ScatterPaintRegionNode
	if node == null:
		return
	var evaluation := ScatterEvaluationContext.create(context.target, context.graph, ScatterEvaluationSession.new())
	var region := node.evaluate_value(evaluation, ScatterNodeInputs.new()) as ScatterPaintRegion
	var lines := PackedVector3Array()
	for stroke in region.strokes:
		lines.append_array(ScatterBrushGeometry.circle(stroke.position, stroke.normal, stroke.radius, false))
	sink.add_lines(lines, &"paint")
