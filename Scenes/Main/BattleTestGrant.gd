extends Node

func _ready() -> void:
	if LanguageProgress:
		LanguageProgress.debug_grant(PackedStringArray([
			"mayap_a_abak",
			"mayap_a_gatpanapun",
			"mayap_a_bengi"
		]))
		print("[BATTLE TEST] First Town greetings granted.")
