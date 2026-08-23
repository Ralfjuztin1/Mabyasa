@tool
class_name ScatterRecipeSidebar
extends VBoxContainer

signal recipe_selected(session_key: String)

var _recipes: ItemList
var _syncing := false


func _ready() -> void:
	name = "RecipeSidebar"
	custom_minimum_size.x = 220.0
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_recipes = ItemList.new()
	_recipes.name = "Recipes"
	_recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Match Godot's editor file sidebars: the secondary variation paints the
	# empty list area with the editor panel background while following its theme.
	_recipes.theme_type_variation = &"ItemListSecondary"
	_recipes.select_mode = ItemList.SELECT_SINGLE
	_recipes.allow_reselect = true
	_recipes.item_selected.connect(_item_selected)
	add_child(_recipes)


func sync_sessions(sessions: Dictionary, active_key: String) -> void:
	if _recipes == null:
		return
	_syncing = true
	_recipes.clear()
	var keys: Array = sessions.keys()
	var recipe_icon: Texture2D = EditorInterface.get_editor_theme().get_icon(&"File", &"EditorIcons")
	keys.sort_custom(func(a: String, b: String) -> bool:
		var session_a := sessions.get(a) as ScatterRecipeEditSession
		var session_b := sessions.get(b) as ScatterRecipeEditSession
		return session_a.recipe_path.naturalnocasecmp_to(session_b.recipe_path) < 0
	)
	for key_variant in keys:
		var key := String(key_variant)
		var session := sessions.get(key) as ScatterRecipeEditSession
		if session == null:
			continue
		var label := session.display_name()
		if session.dirty:
			label += "(*)"
		var index := _recipes.add_item(label, recipe_icon)
		_recipes.set_item_metadata(index, key)
		_recipes.set_item_tooltip(index, session.recipe_path)
		if key == active_key:
			_recipes.select(index)
	_syncing = false


func recipe_count() -> int:
	return _recipes.item_count if _recipes != null else 0


func recipe_label(index: int) -> String:
	return _recipes.get_item_text(index) if _recipes != null and index >= 0 and index < _recipes.item_count else ""


func _item_selected(index: int) -> void:
	if _syncing or _recipes == null:
		return
	var key := String(_recipes.get_item_metadata(index))
	if not key.is_empty():
		recipe_selected.emit(key)
