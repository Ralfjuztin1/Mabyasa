extends Node

## Add this node as a direct child of FirstTown, beside WorldEnvironment
## and DirectionalLight3D. It updates the world lighting when TimeManager
## changes the logical time state. A separate, cool moon light is created at
## runtime so night does not depend on the daytime sun remaining bright.

@export_range(0.0, 10.0, 0.25) var transition_duration: float = 2.0

var _world_environment: WorldEnvironment
var _sun_light: DirectionalLight3D
var _moon_light: DirectionalLight3D
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _transition_tween: Tween


func _ready() -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		push_error("[WORLD TIME] WorldTimeController has no parent.")
		return

	_world_environment = scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_sun_light = scene_root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D

	if _world_environment == null:
		push_error("[WORLD TIME] Could not find sibling node 'WorldEnvironment'.")
		return

	if _sun_light == null:
		push_error("[WORLD TIME] Could not find sibling node 'DirectionalLight3D'.")
		return

	if _world_environment.environment == null:
		push_error("[WORLD TIME] WorldEnvironment has no Environment resource.")
		return

	# Use a scene-local Environment resource so shared assets are not modified.
	_environment = _world_environment.environment.duplicate(true) as Environment
	if _environment == null:
		push_error("[WORLD TIME] Could not duplicate the Environment resource.")
		return
	_world_environment.environment = _environment

	if _environment.sky != null:
		var local_sky: Sky = _environment.sky.duplicate(true) as Sky
		if local_sky != null:
			_environment.sky = local_sky
			if local_sky.sky_material is ProceduralSkyMaterial:
				_sky_material = local_sky.sky_material.duplicate(true) as ProceduralSkyMaterial
				if _sky_material != null:
					local_sky.sky_material = _sky_material

	# Find an existing MoonLight, or create one automatically for this scene.
	_moon_light = scene_root.get_node_or_null("MoonLight") as DirectionalLight3D
	if _moon_light == null:
		_moon_light = DirectionalLight3D.new()
		_moon_light.name = "MoonLight"
		scene_root.add_child(_moon_light)
	_moon_light.rotation_degrees = Vector3(-35.0, 145.0, 0.0)
	_moon_light.light_color = Color(0.62, 0.73, 1.0)
	_moon_light.light_energy = 0.0
	# Keep the additional light inexpensive on lower-end hardware.
	_moon_light.shadow_enabled = false

	# Explicit ambient color gives the town a gentle blue fill at night.
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR

	if not GameEvents.time_updated.is_connected(_on_time_updated):
		GameEvents.time_updated.connect(_on_time_updated)

	_apply_time(TimeManager.get_current_time(), false)


func _exit_tree() -> void:
	if is_instance_valid(_transition_tween) and _transition_tween.is_running():
		_transition_tween.kill()

	if is_instance_valid(GameEvents) and GameEvents.time_updated.is_connected(_on_time_updated):
		GameEvents.time_updated.disconnect(_on_time_updated)


func _on_time_updated(new_time: String) -> void:
	_apply_time(new_time, true)


func _apply_time(time_name: String, animate: bool = true) -> void:
	if _environment == null or _sun_light == null or _moon_light == null:
		return

	var settings: Dictionary = _get_time_settings(time_name.to_lower().strip_edges())
	if settings.is_empty():
		push_warning("[WORLD TIME] Unknown time state: " + time_name)
		return

	if is_instance_valid(_transition_tween) and _transition_tween.is_running():
		_transition_tween.kill()

	if not animate or transition_duration <= 0.0:
		_set_properties(settings)
		print("[WORLD TIME] Applied: ", time_name.capitalize())
		return

	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(_sun_light, "light_energy", settings["light_energy"], transition_duration)
	_transition_tween.tween_property(_sun_light, "light_color", settings["light_color"], transition_duration)
	_transition_tween.tween_property(_sun_light, "rotation_degrees", settings["light_rotation"], transition_duration)
	_transition_tween.tween_property(_moon_light, "light_energy", settings["moon_energy"], transition_duration)
	_transition_tween.tween_property(_environment, "ambient_light_color", settings["ambient_color"], transition_duration)
	_transition_tween.tween_property(_environment, "ambient_light_energy", settings["ambient_energy"], transition_duration)
	_transition_tween.tween_property(_environment, "tonemap_exposure", settings["exposure"], transition_duration)

	if _sky_material != null:
		_transition_tween.tween_property(_sky_material, "sky_top_color", settings["sky_top"], transition_duration)
		_transition_tween.tween_property(_sky_material, "sky_horizon_color", settings["sky_horizon"], transition_duration)
		_transition_tween.tween_property(_sky_material, "ground_horizon_color", settings["ground_horizon"], transition_duration)
		_transition_tween.tween_property(_sky_material, "ground_bottom_color", settings["ground_bottom"], transition_duration)

	print("[WORLD TIME] Transitioning to: ", time_name.capitalize())


func _set_properties(settings: Dictionary) -> void:
	_sun_light.light_energy = settings["light_energy"]
	_sun_light.light_color = settings["light_color"]
	_sun_light.rotation_degrees = settings["light_rotation"]
	_moon_light.light_energy = settings["moon_energy"]
	_environment.ambient_light_color = settings["ambient_color"]
	_environment.ambient_light_energy = settings["ambient_energy"]
	_environment.tonemap_exposure = settings["exposure"]

	if _sky_material != null:
		_sky_material.sky_top_color = settings["sky_top"]
		_sky_material.sky_horizon_color = settings["sky_horizon"]
		_sky_material.ground_horizon_color = settings["ground_horizon"]
		_sky_material.ground_bottom_color = settings["ground_bottom"]


func _get_time_settings(time_name: String) -> Dictionary:
	match time_name:
		"morning":
			return {
				"light_energy": 0.9,
				"light_color": Color(1.0, 0.79, 0.61),
				"light_rotation": Vector3(-25.0, -35.0, 0.0),
				"moon_energy": 0.0,
				"ambient_color": Color(0.48, 0.43, 0.43),
				"ambient_energy": 0.75,
				"exposure": 1.25,
				"sky_top": Color(0.17, 0.30, 0.52),
				"sky_horizon": Color(0.84, 0.58, 0.43),
				"ground_horizon": Color(0.52, 0.44, 0.40),
				"ground_bottom": Color(0.09, 0.10, 0.13)
			}

		"afternoon":
			return {
				"light_energy": 1.15,
				"light_color": Color(1.0, 0.93, 0.80),
				"light_rotation": Vector3(-58.0, -35.0, 0.0),
				"moon_energy": 0.0,
				"ambient_color": Color(0.58, 0.60, 0.64),
				"ambient_energy": 0.7,
				"exposure": 1.7,
				"sky_top": Color(0.36, 0.49, 0.61),
				"sky_horizon": Color(0.79, 0.63, 0.57),
				"ground_horizon": Color(0.66, 0.67, 0.69),
				"ground_bottom": Color(0.19, 0.20, 0.22)
			}

		"night":
			return {
				# Turn down the sun and use a separate cool moonlight.
				"light_energy": 0.0,
				"light_color": Color(0.40, 0.48, 0.78),
				"light_rotation": Vector3(-18.0, 145.0, 0.0),
				"moon_energy": 0.7,
				"ambient_color": Color(0.34, 0.42, 0.62),
				"ambient_energy": 0.8,
				"exposure": 1.15,
				"sky_top": Color(0.025, 0.04, 0.11),
				"sky_horizon": Color(0.12, 0.16, 0.26),
				"ground_horizon": Color(0.10, 0.13, 0.20),
				"ground_bottom": Color(0.015, 0.02, 0.045)
			}

		_:
			return {}
