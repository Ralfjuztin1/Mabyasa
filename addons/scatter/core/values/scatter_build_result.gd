@tool
class_name ScatterBuildResult
extends RefCounted

var ok := true
var error := ""
var instances := ScatterInstances.new()
var errors: Array[ScatterDiagnostic] = []
var warnings: Array[ScatterDiagnostic] = []
var output_counts: Dictionary = {}


static func failure(message: String) -> ScatterBuildResult:
	var result := ScatterBuildResult.new()
	result.ok = false
	result.error = message
	result.errors.append(ScatterDiagnostic.new(ScatterDiagnostic.Severity.ERROR, &"build_failed", -1, message))
	return result
