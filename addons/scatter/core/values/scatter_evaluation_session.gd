@tool
class_name ScatterEvaluationSession
extends RefCounted

var visited_targets: Dictionary[int, bool] = {}
var output_counts: Dictionary = {}
var evaluation_cache: Dictionary = {}
var evaluation_cache_hits := 0
var error := ""
var diagnostics: Array[ScatterDiagnostic] = []
