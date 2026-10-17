@tool
extends EditorScript

## One-time installer for Mabiyasa's in-game settings menu.
## The installer verifies every expected source block before writing anything,
## then creates backups of every changed file.

const FIXES: Dictionary = {
	"res://Scenes/UI/PauseMenu.gd": [
		{
			"old": "const WORD_BANK_SCENE: PackedScene = preload(\"res://Scenes/UI/WordBank.tscn\")\n",
			"new": "const WORD_BANK_SCENE: PackedScene = preload(\"res://Scenes/UI/WordBank.tscn\")\nconst SETTINGS_MENU_SCENE: PackedScene = preload(\"res://Scenes/UI/SettingsMenu.tscn\")\n"
		},
		{
			"old": "var word_bank: CanvasLayer = null\n",
			"new": "var word_bank: CanvasLayer = null\nvar settings_menu: CanvasLayer = null\nvar _settings_opened_from_pause_menu: bool = false\n"
		},
		{
			"old": "\t\tif is_instance_valid(settings_button):\n\t\t\t_connect_if_needed(\n\t\t\t\tsettings_button.pressed,\n\t\t\t\t_on_unavailable_menu_pressed.bind(\"Settings\")\n\t\t\t)\n",
			"new": "\t\tif is_instance_valid(settings_button):\n\t\t\tsettings_button.disabled = false\n\t\t\tsettings_button.tooltip_text = \"Adjust camera, audio, and display settings.\"\n\t\t\t_connect_if_needed(settings_button.pressed, _on_settings_pressed)\n"
		},
		{
			"old": "\t\t_word_bank_opened_from_pause_menu = false\n\t\tif is_instance_valid(word_bank):\n",
			"new": "\t\t_word_bank_opened_from_pause_menu = false\n\t\t_settings_opened_from_pause_menu = false\n\t\tif is_instance_valid(settings_menu):\n\t\t\tsettings_menu.hide()\n\t\tif is_instance_valid(word_bank):\n"
		},
		{
			"old": "func _on_unavailable_menu_pressed(menu_name: String) -> void:\n",
			"new": "func _on_settings_pressed() -> void:\n\tif not is_instance_valid(settings_menu):\n\t\tsettings_menu = SETTINGS_MENU_SCENE.instantiate() as CanvasLayer\n\t\tif settings_menu == null:\n\t\t\tpush_error(\"[PAUSE MENU] Could not create SettingsMenu.\")\n\t\t\treturn\n\t\tadd_child(settings_menu)\n\t\tif settings_menu.has_signal(\"closed\"):\n\t\t\tsettings_menu.connect(\"closed\", _on_settings_closed)\n\n\t_settings_opened_from_pause_menu = true\n\thide()\n\tsettings_menu.call(\"open\")\n\n\nfunc _on_settings_closed() -> void:\n\tif not _settings_opened_from_pause_menu:\n\t\treturn\n\t_settings_opened_from_pause_menu = false\n\tif get_tree().paused:\n\t\tshow()\n\t\tInput.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)\n\n\nfunc _on_unavailable_menu_pressed(menu_name: String) -> void:\n"
		}
	],
	"res://Scenes/UI/GameMenu.gd": [
		{
			"old": "extends Control\n",
			"new": "extends Control\n\nconst SETTINGS_MENU_SCENE: PackedScene = preload(\"res://Scenes/UI/SettingsMenu.tscn\")\nvar settings_menu: CanvasLayer = null\n"
		},
		{
			"old": "\tInput.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)\n",
			"new": "\tInput.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)\n\t_apply_saved_settings_on_launch()\n"
		},
		{
			"old": "func _animate_panel_pop_in():\n",
			"new": "func _apply_saved_settings_on_launch() -> void:\n\tvar config := ConfigFile.new()\n\tif config.load(\"user://mabiyasa_settings.cfg\") != OK:\n\t\treturn\n\n\tvar master_bus: int = AudioServer.get_bus_index(\"Master\")\n\tif master_bus >= 0:\n\t\tvar volume: float = clampf(float(config.get_value(\"audio\", \"master_volume\", 100.0)), 0.0, 100.0)\n\t\tAudioServer.set_bus_mute(master_bus, volume <= 0.0)\n\t\tAudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(volume / 100.0, 0.0001)))\n\n\tif config.has_section_key(\"display\", \"window_mode\"):\n\t\tmatch clampi(int(config.get_value(\"display\", \"window_mode\", 1)), 0, 2):\n\t\t\t0:\n\t\t\t\tDisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)\n\t\t\t1:\n\t\t\t\tDisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)\n\t\t\t2:\n\t\t\t\tDisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)\n\tif config.has_section_key(\"display\", \"vsync\"):\n\t\tvar enabled: bool = bool(config.get_value(\"display\", \"vsync\", true))\n\t\tDisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)\n\n\nfunc _animate_panel_pop_in():\n"
		},
		{
			"old": "func _on_settings_pressed():\n\tprint(\"Opening Settings...\")",
			"new": "func _on_settings_pressed() -> void:\n\tif not is_instance_valid(settings_menu):\n\t\tsettings_menu = SETTINGS_MENU_SCENE.instantiate() as CanvasLayer\n\t\tif settings_menu == null:\n\t\t\tpush_error(\"[MAIN MENU] Could not create SettingsMenu.\")\n\t\t\treturn\n\t\tadd_child(settings_menu)\n\t\tif settings_menu.has_signal(\"closed\"):\n\t\t\tsettings_menu.connect(\"closed\", _on_settings_closed)\n\n\tsettings_menu.call(\"open\")\n\n\nfunc _on_settings_closed() -> void:\n\t# The main-menu cursor remains visible after settings closes.\n\tInput.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)"
		}
	],
	"res://Scenes/Characters/Player/player.gd": [
		{
			"old": "\tspring_arm.spring_length = camera_distance\n",
			"new": "\tspring_arm.spring_length = camera_distance\n\t_apply_saved_user_settings()\n"
		},
		{
			"old": "func _setup_footstep_audio() -> void:\n",
			"new": "func _apply_saved_user_settings() -> void:\n\tvar settings := ConfigFile.new()\n\tif settings.load(\"user://mabiyasa_settings.cfg\") != OK:\n\t\treturn\n\n\tvar sensitivity_multiplier: float = clampf(\n\t\tfloat(settings.get_value(\"controls\", \"sensitivity_multiplier\", 1.0)),\n\t\t0.25,\n\t\t3.0\n\t)\n\tmouse_sensitivity = 0.003 * sensitivity_multiplier\n\n\tvar camera: Camera3D = get_node_or_null(\"Head/SpringArm3D/Camera3D\") as Camera3D\n\tif is_instance_valid(camera):\n\t\tcamera.fov = clampf(\n\t\t\tfloat(settings.get_value(\"camera\", \"fov\", 75.0)),\n\t\t\t55.0,\n\t\t\t100.0\n\t\t)\n\n\nfunc _setup_footstep_audio() -> void:\n"
		}
	]
}


func _run() -> void:
	var updated_text: Dictionary = {}
	var touched_paths: Array[String] = []

	# Validate and prepare all replacements before changing any source file.
	for path_variant: Variant in FIXES.keys():
		var path: String = str(path_variant)
		var source_file := FileAccess.open(path, FileAccess.READ)
		if source_file == null:
			push_error("[SETTINGS INSTALLER] Cannot read: " + path)
			return
		var source: String = source_file.get_as_text()
		source_file.close()
		var changed: bool = false

		for fix_variant: Variant in FIXES[path]:
			var fix: Dictionary = fix_variant
			var old_text: String = str(fix["old"])
			var new_text: String = str(fix["new"])

			if source.contains(new_text):
				continue
			if not source.contains(old_text):
				push_error(
					"[SETTINGS INSTALLER] Expected source block not found in " + path
					+ ".\nNo project scripts have been changed. Your local version may differ from the repository version."
				)
				return
			source = source.replace(old_text, new_text)
			changed = true

		updated_text[path] = source
		if changed:
			touched_paths.append(path)

	if touched_paths.is_empty():
		print("[SETTINGS INSTALLER] Settings integration is already installed.")
		return

	# Create backups before saving any changes.
	for path: String in touched_paths:
		var backup_path: String = path + ".before_settings.bak"
		if FileAccess.file_exists(backup_path):
			print("[SETTINGS INSTALLER] Existing backup kept: " + backup_path)
			continue
		var original := FileAccess.open(path, FileAccess.READ)
		if original == null:
			push_error("[SETTINGS INSTALLER] Cannot open source for backup: " + path)
			return
		var original_text: String = original.get_as_text()
		original.close()
		var backup := FileAccess.open(backup_path, FileAccess.WRITE)
		if backup == null:
			push_error("[SETTINGS INSTALLER] Cannot create backup: " + backup_path)
			return
		backup.store_string(original_text)
		backup.close()

	for path: String in touched_paths:
		var output := FileAccess.open(path, FileAccess.WRITE)
		if output == null:
			push_error("[SETTINGS INSTALLER] Cannot write: " + path)
			return
		output.store_string(str(updated_text[path]))
		output.close()
		print("[SETTINGS INSTALLER] Updated: " + path)

	print("[SETTINGS INSTALLER] Complete. Settings UI is connected to both menus.")
	print("[SETTINGS INSTALLER] Backups use the suffix .before_settings.bak")
	print("[SETTINGS INSTALLER] Return to the editor and let Godot reload the scripts.")
