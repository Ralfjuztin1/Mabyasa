class_name ThreadRunner
extends RefCounted

## A simple threading utility for running functions on a background thread
## and retrieving their return values.
##
## Usage:
##   var runner := ThreadRunner.new()
##   runner.finished.connect(_on_thread_finished)
##   runner.run(some_callable, [arg1, arg2])
##
## Or with await:
##   var result = await ThreadRunner.run_async(some_callable, [arg1, arg2])

signal finished(result: Variant)

var _thread: Thread
var _result: Variant = null
var _is_running: bool = false

## Starts running callable with args on a background thread.
## Emits finished(result) when the function returns.
## Returns true if started successfully, false if a thread is already running.
func run(callable: Callable, args: Array = []) -> bool:
	if _is_running:
		push_warning("ThreadRunner is already running a task.")
		return false

	_is_running = true
	_result = null
	_thread = Thread.new()
	var err := _thread.start(_thread_body.bind(callable, args))
	if err != OK:
		push_error("Failed to start thread: %s" % err)
		_is_running = false
		return false
	return true


## Convenience: await this and get the result directly.
static func run_async(callable: Callable, args: Array = []) -> Variant:
	var runner: ThreadRunner = ThreadRunner.new()
	runner.run(callable, args)
	return await runner.finished


## Internal: runs on the worker thread, then defers the completion handler
## back onto the main thread so signals/cleanup happen safely.
func _thread_body(callable: Callable, args: Array) -> void:
	var result: Variant = callable.callv(args)
	# Hop back to the main thread before emitting the signal
	# and joining the thread, so callers see results safely.
	call_deferred("_on_thread_done", result)


func _on_thread_done(result: Variant) -> void:
	_result = result
	if _thread:
		_thread.wait_to_finish()
		_thread = null
	_is_running = false
	finished.emit(result)


## True while a background task is in flight.
func is_running() -> bool:
	return _is_running


## Returns the most recent result (null until the task finishes).
func get_result() -> Variant:
	return _result
