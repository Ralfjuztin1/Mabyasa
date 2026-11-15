extends Node3D

## An in-world merchant counting lesson / basket delivery demonstration.
## Actual baskets and a wooden stand are placed in SecondTown, not in a fullscreen UI.
## A small transparent control strip is only used for player choices.

signal lesson_finished()
signal delivery_finished(recipient_id: String)
signal closed()

const BASKET_TEXTURE: Texture2D = preload("res://Assets/SecondTown/merchant_goods_basket.png")
const WORDS: Array[String] = ["metung", "adwa", "atlu"]
const ENGLISH: Array[String] = ["one", "two", "three"]
const GOLD: Color = Color(0.98, 0.77, 0.41, 1.0)
const LIGHT: Color = Color(0.98, 0.94, 0.86, 1.0)
const FAINT: Color = Color(0.74, 0.84, 0.77, 1.0)

var _mode: String = "lesson" # lesson, delivery, or review
var _page: int = 0
var _selected: int = 0
var _needed: int = 1
var _recipient_id: String = ""
var _recipient_name: String = ""
var _delivery_done: bool = false
var _feedback: String = ""

var _previous_camera: Camera3D = null
var _lesson_camera: Camera3D = null
var _basket_root: Node3D = null
var _word_sign: Label3D = null
var _speaker_sign: Label3D = null
var _caption: Label = null
var _button_row: HFlowContainer = null
var _soft_shadow_material: ShaderMaterial = null

# The stand is 0.68m above the floor, with a 0.13m thick top.
const TOP_Y: float = 0.68
const TOP_THICKNESS: float = 0.13
const LEG_TOP: float = TOP_Y - TOP_THICKNESS * 0.5
const LEG_X: float = 1.37
const LEG_Z: float = 0.41


func start_lesson(merchant: Node3D, player: Node3D) -> void:
	_mode = "lesson"
	_page = 0
	_delivery_done = false
	_feedback = ""
	_setup_world(merchant, player)
	_refresh()


func start_delivery(recipient: Node3D, player: Node3D, recipient_id: String, recipient_name: String, amount: int) -> void:
	_mode = "delivery"
	_recipient_id = recipient_id
	_recipient_name = recipient_name
	_needed = amount
	_selected = 0
	_delivery_done = false
	_feedback = ""
	_setup_world(recipient, player)
	_refresh()


func _setup_world(npc: Node3D, player: Node3D) -> void:
	if not is_instance_valid(npc):
		push_error("[MERCHANT WORLD] Cannot show baskets: NPC missing")
		closed.emit()
		return

	# Position the baskets at the merchant's side, oriented toward the player.
	# This is a real world location: the baskets sit on an in-scene wooden stand.
	var to_player: Vector3 = Vector3(0.0, 0.0, 1.0)
	if is_instance_valid(player):
		to_player = player.global_position - npc.global_position
		to_player.y = 0.0
	if to_player.length_squared() < 0.01:
		to_player = Vector3(0.0, 0.0, 1.0)
	to_player = to_player.normalized()
	var right: Vector3 = Vector3.UP.cross(to_player).normalized()
	var stand_position: Vector3 = npc.global_position + right * 2.1 + to_player * 0.35
	# Anchor to the actual terrain, not the NPC's origin (which can be above
	# the floor because the merchant root and collision shape are scaled).
	var ground_y: float = _ground_y_at(stand_position, npc, player)
	global_transform = Transform3D(
		Basis(right, Vector3.UP, to_player),
		Vector3(stand_position.x, ground_y, stand_position.z)
	)

	_build_wooden_stand(npc, player)
	_basket_root = Node3D.new()
	_basket_root.name = "VisibleWorldBaskets"
	add_child(_basket_root)
	_word_sign = _make_world_label(44, GOLD)
	_word_sign.position = Vector3(0.0, 2.05, 0.0)
	add_child(_word_sign)
	_speaker_sign = _make_world_label(28, LIGHT)
	_speaker_sign.position = Vector3(0.0, 2.53, 0.0)
	add_child(_speaker_sign)

	# A short cinematic angle guarantees the real basket props and NPC are seen.
	# Return to the player's original camera as soon as the interaction finishes.
	_previous_camera = get_viewport().get_camera_3d()
	_lesson_camera = Camera3D.new()
	_lesson_camera.name = "MerchantWorldLessonCamera"
	_lesson_camera.fov = 60.0
	_lesson_camera.near = 0.05
	add_child(_lesson_camera)
	_lesson_camera.global_position = npc.global_position + to_player * 4.4 + right * 0.5 + Vector3.UP * 2.25
	_lesson_camera.look_at(npc.global_position + right * 0.95 + Vector3.UP * 1.25, Vector3.UP)
	_lesson_camera.make_current()

	_build_controls()


func _ground_y_at(at: Vector3, npc: Node3D, player: Node3D) -> float:
	# MarchingSquaresTerrain has a physics collider: raycast down to its surface.
	# Exclude the two actors so their capsules never become the "ground".
	var exclusions: Array[RID] = []
	if npc is CollisionObject3D:
		exclusions.append((npc as CollisionObject3D).get_rid())
	if player is CollisionObject3D:
		exclusions.append((player as CollisionObject3D).get_rid())
	var start: Vector3 = Vector3(at.x, at.y + 8.0, at.z)
	var finish: Vector3 = Vector3(at.x, at.y - 15.0, at.z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, finish, 1, exclusions)
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var point: Vector3 = hit["position"]
		return point.y
	# If the landscape has no collider at this point, use the NPC's foot
	# level as a fallback instead of the old floating stand height.
	return npc.global_position.y - 0.15


func _build_wooden_stand(npc: Node3D, player: Node3D) -> void:
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.33, 0.20, 0.10, 1.0)
	wood.roughness = 1.0
	var trim: StandardMaterial3D = StandardMaterial3D.new()
	trim.albedo_color = Color(0.50, 0.31, 0.15, 1.0)
	trim.roughness = 1.0

	# Query the terrain beneath all four legs. On uneven ground the tabletop
	# stays level while each leg extends down to its own contact point.
	var leg_points: Array[Dictionary] = []
	var center_ground: float = global_position.y
	var highest_ground: float = center_ground
	for x: float in [-LEG_X, LEG_X]:
		for z: float in [-LEG_Z, LEG_Z]:
			var leg_world: Vector3 = to_global(Vector3(x, 0.0, z))
			var foot_y: float = _ground_y_at(leg_world, npc, player)
			# Ignore tall props or stray physics hits; those are not terrain.
			if absf(foot_y - center_ground) > 0.5:
				foot_y = center_ground
			leg_points.append({"x": x, "z": z, "foot_y": foot_y})
			highest_ground = maxf(highest_ground, foot_y)

	# A small lift over the highest corner prevents the top/legs clipping
	# uphill ground, without leaving the feet suspended.
	global_position.y = highest_ground
	_add_box("TableTop", Vector3(3.15, TOP_THICKNESS, 1.10), Vector3(0.0, TOP_Y, 0.0), trim)
	for leg: Dictionary in leg_points:
		var foot_local_y: float = float(leg["foot_y"]) - global_position.y
		var leg_height: float = maxf(0.1, LEG_TOP - foot_local_y)
		var leg_center: float = (LEG_TOP + foot_local_y) * 0.5
		_add_box("TableLeg", Vector3(0.14, leg_height, 0.14), Vector3(float(leg["x"]), leg_center, float(leg["z"])), wood)


func _add_box(node_name: String, dimensions: Vector3, at: Vector3, material: Material) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = at
	add_child(mesh_instance)


func _make_world_label(text_size: int, font_color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.font_size = text_size
	label.pixel_size = 0.006
	label.modulate = font_color
	label.outline_size = 12
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _build_controls() -> void:
	# Deliberately NO fullscreen panel or background dimmer. The town is visible.
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MerchantWorldControls"
	layer.layer = 85
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var viewport_control: Control = Control.new()
	viewport_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(viewport_control)

	var bottom_center: CenterContainer = CenterContainer.new()
	bottom_center.anchor_left = 0.0
	bottom_center.anchor_right = 1.0
	bottom_center.anchor_top = 1.0
	bottom_center.anchor_bottom = 1.0
	bottom_center.offset_top = -158.0
	bottom_center.offset_bottom = -17.0
	bottom_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_control.add_child(bottom_center)

	var bar: PanelContainer = PanelContainer.new()
	bar.custom_minimum_size = Vector2(580.0, 0.0)
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	box_style.bg_color = Color(0.015, 0.055, 0.038, 0.83)
	box_style.border_color = Color(0.82, 0.63, 0.31, 0.85)
	box_style.set_border_width_all(1)
	box_style.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("panel", box_style)
	bottom_center.add_child(bar)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	bar.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_color_override("font_color", LIGHT)
	_caption.add_theme_font_size_override("font_size", 16)
	content.add_child(_caption)

	_button_row = HFlowContainer.new()
	_button_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("h_separation", 9)
	_button_row.add_theme_constant_override("v_separation", 6)
	content.add_child(_button_row)


func _refresh() -> void:
	if not is_instance_valid(_basket_root) or not is_instance_valid(_caption):
		return
	_clear_baskets()
	_clear_buttons()

	if _mode == "lesson" or _mode == "review":
		var number: int = _page + 1
		_word_sign.text = "%s  =  %d %s" % [WORDS[_page].to_upper(), number, "BASKET" if number == 1 else "BASKETS"]
		_speaker_sign.text = "MERCHANT: %s means %s" % [WORDS[_page].capitalize(), ENGLISH[_page]]
		_caption.text = "Count the baskets in the town.  %d / 3" % number
		_spawn_baskets(number)
		if _page > 0:
			_add_button("< PREVIOUS", _previous_page)
		if _page < 2:
			_add_button("NEXT: %s >" % WORDS[_page + 1].to_upper(), _next_page, true)
		else:
			_add_button("REVIEW FROM METUNG", _restart_pages)
			_add_button("BACK TO DELIVERY" if _mode == "review" else "PROCEED TO DELIVERIES", _next_page, true)
		if _mode == "review" and _page < 2:
			_add_button("BACK TO DELIVERY", _return_from_review)
		if _mode == "lesson":
			_add_button("LEAVE", _exit)
		return

	_word_sign.text = "%s  =  %d %s" % [WORDS[_selected].to_upper(), _selected + 1, "BASKET" if _selected == 0 else "BASKETS"]
	_speaker_sign.text = "DELIVERY FOR %s" % _recipient_name.to_upper()
	_spawn_baskets(_selected + 1)
	if _delivery_done:
		_caption.text = str({
			"berto": "Berto: The fields are drying. The well isn't giving enough water.",
			"mila": "Mila: I saw strange markings beside the old well.",
			"nena": "Nena: We hear strange noises near the old well. Ask the Elder."
		}.get(_recipient_id, "Delivery complete!"))
		_add_button("RETURN TO TOWN", _exit, true)
		return

	_caption.text = _feedback if not _feedback.is_empty() else "%s asked for %s basket%s. Choose the word, then confirm." % [_recipient_name, WORDS[_needed - 1], "" if _needed == 1 else "s"]
	for i: int in range(WORDS.size()):
		_add_button(WORDS[i].to_upper(), _select_quantity.bind(i), i == _selected)
	_add_button("CONFIRM DELIVERY", _confirm_delivery, true)
	_add_button("REVIEW NUMBERS", _review_numbers)
	_add_button("LEAVE", _exit)


func _clear_baskets() -> void:
	for child: Node in _basket_root.get_children():
		_basket_root.remove_child(child)
		child.queue_free()


func _spawn_baskets(count: int) -> void:
	for i: int in range(count):
		var sprite: Sprite3D = Sprite3D.new()
		sprite.name = "Basket_%d" % (i + 1)
		sprite.texture = BASKET_TEXTURE
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = true
		# Transparent pixels must be discarded for accurate shadow silhouettes.
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.pixel_size = 0.92 / maxf(float(BASKET_TEXTURE.get_width()), float(BASKET_TEXTURE.get_height()))
		var basket_x: float = (float(i) - float(count - 1) * 0.5) * 0.92
		sprite.position = Vector3(basket_x, 1.60, 0.0)
		sprite.modulate.a = 0.0
		_basket_root.add_child(sprite)
		_add_contact_shadow(basket_x)
		var tween: Tween = sprite.create_tween().set_parallel(true)
		tween.tween_property(sprite, "position:y", 1.20, 0.38).set_delay(float(i) * 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.18).set_delay(float(i) * 0.16)


func _add_contact_shadow(basket_x: float) -> void:
	# A subtle diffuse shadow anchors the 2D billboard to the tabletop,
	# even on renderers where billboard shadow casting is inconsistent.
	if _soft_shadow_material == null:
		var shadow_shader: Shader = Shader.new()
		shadow_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float falloff = pow(clamp(1.0 - dot(p, p), 0.0, 1.0), 1.8);
    ALBEDO = vec3(0.035, 0.025, 0.014);
    ALPHA = 0.32 * falloff;
}
"""
		_soft_shadow_material = ShaderMaterial.new()
		_soft_shadow_material.shader = shadow_shader
	var shadow: MeshInstance3D = MeshInstance3D.new()
	shadow.name = "BasketContactShadow"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(0.62, 0.35)
	shadow.mesh = plane
	shadow.material_override = _soft_shadow_material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = Vector3(basket_x, TOP_Y + TOP_THICKNESS * 0.5 + 0.012, 0.0)
	_basket_root.add_child(shadow)


func _clear_buttons() -> void:
	for child: Node in _button_row.get_children():
		_button_row.remove_child(child)
		child.queue_free()


func _add_button(title: String, callback: Callable, primary: bool = false) -> void:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(110.0, 38.0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", LIGHT)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.32, 0.22, 0.97) if primary else Color(0.07, 0.16, 0.12, 0.96)
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(6)
	button.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.27, 0.43, 0.29, 1.0)
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(callback)
	_button_row.add_child(button)


func _previous_page() -> void:
	_page = maxi(_page - 1, 0)
	_refresh()


func _next_page() -> void:
	if _page < 2:
		_page += 1
		_refresh()
		return
	if _mode == "review":
		_return_from_review()
		return
	lesson_finished.emit()
	closed.emit()


func _restart_pages() -> void:
	_page = 0
	_refresh()


func _review_numbers() -> void:
	_mode = "review"
	_page = 0
	_feedback = ""
	_refresh()


func _return_from_review() -> void:
	_mode = "delivery"
	_refresh()


func _select_quantity(index: int) -> void:
	_selected = index
	_feedback = ""
	_refresh()


func _confirm_delivery() -> void:
	if _delivery_done:
		return
	if _selected + 1 != _needed:
		_feedback = "Not quite. Try again or REVIEW NUMBERS."
		_refresh()
		return
	_delivery_done = true
	delivery_finished.emit(_recipient_id)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_exit()
	elif event.is_action_pressed("ui_left") and (_mode == "lesson" or _mode == "review") and _page > 0:
		get_viewport().set_input_as_handled()
		_previous_page()
	elif event.is_action_pressed("ui_right") and (_mode == "lesson" or _mode == "review"):
		get_viewport().set_input_as_handled()
		_next_page()


func _exit() -> void:
	closed.emit()


func restore_camera() -> void:
	if is_instance_valid(_previous_camera) and _previous_camera.is_inside_tree():
		_previous_camera.make_current()
	elif is_instance_valid(_lesson_camera) and _lesson_camera.is_current():
		_lesson_camera.clear_current(true)


func _exit_tree() -> void:
	restore_camera()
