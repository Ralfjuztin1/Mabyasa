extends Node

## Account-owned food inventory shared by exploration, the market, and battles.
signal inventory_changed
signal battle_food_selected(item_id: String)

const FOOD_RESOURCES: Array[Resource] = [
	preload("res://Resources/Foods/tibuk_tibuk.tres"),
	preload("res://Resources/Foods/tamales.tres"),
	preload("res://Resources/Foods/bringhe.tres"),
	preload("res://Resources/Foods/bulanglang.tres"),
	preload("res://Resources/Foods/sisig.tres")
]

## Food ID -> quantity. This dictionary is serialized per account.
var food_quantities: Dictionary = {}
var _food_resources_by_id: Dictionary = {}
var _active_menu: Node = null
var _mouse_mode_before_menu: int = Input.MOUSE_MODE_CAPTURED
var _paused_tree_before_menu: bool = false
var _paused_tree_by_menu: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_food_resource_lookup()


func _build_food_resource_lookup() -> void:
	_food_resources_by_id.clear()
	for food_resource: Resource in FOOD_RESOURCES:
		if food_resource == null:
			continue
		var item_id: String = str(food_resource.get("id")).strip_edges()
		if item_id.is_empty():
			push_warning("[INVENTORY] Food resource has an empty ID: %s" % food_resource.resource_path)
			continue
		if _food_resources_by_id.has(item_id):
			push_warning("[INVENTORY] Duplicate food ID: %s" % item_id)
			continue
		_food_resources_by_id[item_id] = food_resource


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ESCAPE and is_instance_valid(_active_menu):
		_active_menu.queue_free()
		get_viewport().set_input_as_handled()
		return

	if key_event.physical_keycode != KEY_I and key_event.keycode != KEY_I:
		return
	if get_tree().paused:
		return

	var focused_control: Control = get_viewport().gui_get_focus_owner()
	if focused_control is LineEdit or focused_control is TextEdit:
		return
	if is_instance_valid(_active_menu):
		return
	if BattleManager != null and BattleManager.battle_active:
		return

	open_inventory()
	get_viewport().set_input_as_handled()


func get_food_database() -> Dictionary:
	_ensure_food_resources()
	var result: Dictionary = {}
	for item_id: Variant in _food_resources_by_id.keys():
		result[str(item_id)] = _food_to_dictionary(_food_resources_by_id[item_id] as Resource)
	return result


func get_food(item_id: String) -> Dictionary:
	_ensure_food_resources()
	var resource: Resource = _food_resources_by_id.get(item_id) as Resource
	if resource == null:
		return {}
	return _food_to_dictionary(resource)


func _food_to_dictionary(resource: Resource) -> Dictionary:
	return {
		"id": str(resource.get("id")),
		"name": str(resource.get("display_name")),
		"description": str(resource.get("description")),
		"icon": resource.get("icon") as Texture2D,
		"price": int(resource.get("price")),
		"heal_amount": int(resource.get("heal_amount")),
		"heal_per_turn": int(resource.get("heal_per_turn")),
		"duration": int(resource.get("duration"))
	}


func _ensure_food_resources() -> void:
	if _food_resources_by_id.is_empty():
		_build_food_resource_lookup()


func get_quantity(item_id: String) -> int:
	return maxi(int(food_quantities.get(item_id, 0)), 0)


func get_total_food_count() -> int:
	var total: int = 0
	for value: Variant in food_quantities.values():
		total += maxi(int(value), 0)
	return total


func get_owned_foods() -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in food_quantities.keys():
		var item_id: String = str(key)
		var quantity: int = get_quantity(item_id)
		if quantity > 0 and not get_food(item_id).is_empty():
			result[item_id] = quantity
	return result


func can_buy_food(item_id: String, quantity: int = 1) -> bool:
	if get_food(item_id).is_empty() or quantity < 1 or quantity > 99:
		return false
	var food: Dictionary = get_food(item_id)
	var total_price: int = int(food.get("price", 0)) * quantity
	return PlayerProgression != null and PlayerProgression.gold >= total_price


func buy_food(item_id: String, quantity: int = 1) -> bool:
	if not can_buy_food(item_id, quantity):
		return false
	var food: Dictionary = get_food(item_id)
	var total_cost: int = int(food.get("price", 0)) * quantity
	if not PlayerProgression.spend_gold(total_cost):
		return false
	food_quantities[item_id] = get_quantity(item_id) + quantity
	inventory_changed.emit()
	_request_account_save()
	return true


func consume_food(item_id: String) -> bool:
	if get_food(item_id).is_empty() or get_quantity(item_id) <= 0:
		return false
	var remaining: int = get_quantity(item_id) - 1
	if remaining <= 0:
		food_quantities.erase(item_id)
	else:
		food_quantities[item_id] = remaining
	inventory_changed.emit()
	_request_account_save()
	return true


## Outside combat, timed healing is applied immediately as its total amount because
## exploration has no enemy turns. In battle, its turns are handled by BattleManager.
func use_food(item_id: String) -> bool:
	var food: Dictionary = get_food(item_id)
	if food.is_empty() or get_quantity(item_id) <= 0:
		return false
	if BattleManager != null and BattleManager.battle_active:
		return BattleManager.player_use_food(item_id)
	if PlayerProgression == null:
		return false

	var total_healing: int = int(food.get("heal_amount", 0)) + (
		int(food.get("heal_per_turn", 0)) * int(food.get("duration", 0))
	)
	PlayerProgression.ensure_hp_initialized()
	if PlayerProgression.current_hp >= PlayerProgression.get_total_max_hp():
		return false
	if total_healing <= 0 or not consume_food(item_id):
		return false

	PlayerProgression.heal(total_healing)
	_request_account_save()
	return true


func open_inventory() -> void:
	_open_menu("inventory")


func open_market() -> void:
	_open_menu("market")


func open_battle_food_picker() -> void:
	_open_menu("battle")


func _open_menu(menu_mode: String) -> void:
	if is_instance_valid(_active_menu):
		_active_menu.queue_free()
		_active_menu = null
		_restore_menu_state()

	var packed: PackedScene = load("res://Scenes/UI/FoodMenu.tscn") as PackedScene
	if packed == null:
		push_error("[INVENTORY] Could not load FoodMenu.tscn.")
		return

	_mouse_mode_before_menu = Input.mouse_mode
	_paused_tree_before_menu = get_tree().paused
	_paused_tree_by_menu = menu_mode in ["inventory", "market"] and not _paused_tree_before_menu

	var menu: Node = packed.instantiate()
	menu.set("mode", menu_mode)
	if menu.has_signal("food_selected"):
		menu.food_selected.connect(_on_menu_food_selected)
	menu.tree_exited.connect(_on_menu_closed.bind(menu))
	_active_menu = menu
	get_tree().root.add_child(menu)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _paused_tree_by_menu:
		get_tree().paused = true


func _on_menu_food_selected(item_id: String) -> void:
	battle_food_selected.emit(item_id)


func _on_menu_closed(menu: Node) -> void:
	if _active_menu != menu:
		return
	_active_menu = null
	_restore_menu_state()


func _restore_menu_state() -> void:
	if _paused_tree_by_menu and is_inside_tree() and get_tree().paused:
		get_tree().paused = false
	_paused_tree_by_menu = false

	if not is_inside_tree():
		return
	if get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(_mouse_mode_before_menu)


func get_save_data() -> Dictionary:
	return {"food_quantities": food_quantities.duplicate(true)}


func load_save_data(data: Dictionary) -> void:
	food_quantities.clear()
	var saved: Variant = data.get("food_quantities", {})
	if saved is Dictionary:
		for key: Variant in (saved as Dictionary).keys():
			var item_id: String = str(key)
			var quantity: int = maxi(int((saved as Dictionary).get(key, 0)), 0)
			if not get_food(item_id).is_empty() and quantity > 0:
				food_quantities[item_id] = quantity
	inventory_changed.emit()


## Called at login/logout before restoring another account's own save.
## This method deliberately does not request a save.
func reset_for_account() -> void:
	if is_instance_valid(_active_menu):
		_active_menu.queue_free()
		_active_menu = null
	_restore_menu_state()
	food_quantities.clear()
	inventory_changed.emit()


func _request_account_save() -> void:
	if GameManager != null and GameManager.has_method("request_save"):
		GameManager.request_save()
