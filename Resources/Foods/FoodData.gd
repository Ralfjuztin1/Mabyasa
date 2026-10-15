extends Resource
class_name FoodData

## Reusable data definition for a purchasable and usable food item.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_range(0, 999999, 1) var price: int = 0
@export_range(0, 999999, 1) var heal_amount: int = 0
@export_range(0, 999999, 1) var heal_per_turn: int = 0
@export_range(0, 999, 1) var duration: int = 0
