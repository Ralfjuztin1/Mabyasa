@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("SpeechBubble3D", "Node3D", preload("speech_bubble.gd"), preload("icon.png"))
	
func _exit_tree() -> void:
	remove_custom_type("SpeechBubble3D")
