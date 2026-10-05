class_name CutsceneParallel
extends Node

## Runs all child CutsceneAction / CutsceneParallel nodes at the same time.
## The group finishes when every child finishes.

@export var enabled: bool = true

var _remaining: int = 0
var _finished: bool = false


func execute(director: CutsceneDirector) -> void:
	if not enabled:
		return

	var runnable: Array[Node] = []

	for child in get_children():
		if child is CutsceneAction or child is CutsceneParallel:
			runnable.append(child)

	if runnable.is_empty():
		return

	_remaining = runnable.size()
	_finished = false

	for child in runnable:
		_run_child(child, director)

	while not _finished:
		await get_tree().process_frame


func _run_child(child: Node, director: CutsceneDirector) -> void:
	await child.execute(director)

	_remaining -= 1

	if _remaining <= 0:
		_finished = true
