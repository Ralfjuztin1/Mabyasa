extends RefCounted

## Central rules for Mabiyasa's gear tempering system.
## Gear levels remain stored in PlayerProgression so existing saves and
## the existing combat-stat calculations continue to work.

const MAX_GEAR_LEVEL: int = 8
const BASE_UPGRADE_COST: int = 150
const COST_GROWTH: float = 1.7
const BASE_SUCCESS_CHANCE: float = 90.0
const CHANCE_DECREASE_PER_LEVEL: float = 8.0
const MIN_SUCCESS_CHANCE: float = 42.0
const LANGUAGE_BONUS: float = 10.0
const MAX_SUCCESS_CHANCE_WITH_BONUS: float = 95.0

const GEAR_DATA: Dictionary = {
	"sword": {
		"name": "Yatu Ironblade",
		"slot": "WEAPON",
		"stat_label": "Attack",
		"stat_short": "ATK",
		"stat_key": "atk",
		"bonus_per_level": 4,
		"description": "A village-forged blade. Better tempering gives each strike more force.",
		"flavor": "A steady hand makes a truer edge."
	},
	"armor": {
		"name": "Laharweave Armor",
		"slot": "ARMOR",
		"stat_label": "Defense",
		"stat_short": "DEF",
		"stat_key": "def",
		"bonus_per_level": 3,
		"description": "Layered village armor reinforced to absorb harder blows.",
		"flavor": "Strong threads hold when the road turns rough."
	},
	"helmet": {
		"name": "Pandan Guard Helm",
		"slot": "HELMET",
		"stat_label": "Max HP",
		"stat_short": "HP",
		"stat_key": "hp",
		"bonus_per_level": 20,
		"description": "A light headpiece reinforced to keep you standing longer.",
		"flavor": "Protect the head, and the journey continues."
	}
}


static func get_gear_definition(gear_type: String) -> Dictionary:
	var value: Variant = GEAR_DATA.get(gear_type, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func get_current_level(gear_type: String) -> int:
	if not GEAR_DATA.has(gear_type) or PlayerProgression == null:
		return 1
	return maxi(int(PlayerProgression.gear_levels.get(gear_type, 1)), 1)


static func get_upgrade_cost(current_level: int) -> int:
	if current_level >= MAX_GEAR_LEVEL:
		return 0
	var raw_cost: float = float(BASE_UPGRADE_COST) * pow(COST_GROWTH, maxi(current_level - 1, 0))
	# Round to the nearest 25 Gold for cleaner prices in the UI.
	return maxi(25, int(round(raw_cost / 25.0)) * 25)


static func get_success_chance(current_level: int, bonus: float = 0.0) -> float:
	if current_level >= MAX_GEAR_LEVEL:
		return 0.0
	var base_chance: float = BASE_SUCCESS_CHANCE - float(maxi(current_level - 1, 0)) * CHANCE_DECREASE_PER_LEVEL
	base_chance = maxf(base_chance, MIN_SUCCESS_CHANCE)
	return minf(base_chance + clampf(bonus, 0.0, LANGUAGE_BONUS), MAX_SUCCESS_CHANCE_WITH_BONUS)


static func get_upgrade_info(gear_type: String, bonus: float = 0.0) -> Dictionary:
	var definition: Dictionary = get_gear_definition(gear_type)
	if definition.is_empty():
		return {}

	var level: int = get_current_level(gear_type)
	var bonus_per_level: int = int(definition.get("bonus_per_level", 0))
	var current_bonus: int = maxi(level - 1, 0) * bonus_per_level
	var next_bonus: int = level * bonus_per_level
	var is_max_level: bool = level >= MAX_GEAR_LEVEL

	return {
		"id": gear_type,
		"name": str(definition.get("name", gear_type.capitalize())),
		"slot": str(definition.get("slot", "GEAR")),
		"stat_label": str(definition.get("stat_label", "Stat")),
		"stat_short": str(definition.get("stat_short", "STAT")),
		"stat_key": str(definition.get("stat_key", "")),
		"bonus_per_level": bonus_per_level,
		"current_level": level,
		"next_level": mini(level + 1, MAX_GEAR_LEVEL),
		"current_bonus": current_bonus,
		"next_bonus": next_bonus,
		"cost": get_upgrade_cost(level),
		"success_chance": get_success_chance(level, bonus),
		"base_success_chance": get_success_chance(level, 0.0),
		"is_max_level": is_max_level,
		"description": str(definition.get("description", "")),
		"flavor": str(definition.get("flavor", ""))
	}


static func attempt_upgrade(gear_type: String, bonus: float = 0.0) -> Dictionary:
	var info: Dictionary = get_upgrade_info(gear_type, bonus)
	if info.is_empty():
		return {"attempted": false, "success": false, "message": "That piece of gear cannot be tempered."}

	if bool(info.get("is_max_level", false)):
		return {
			"attempted": false,
			"success": false,
			"message": "This gear has reached its maximum level.",
			"cost": 0,
			"chance": 0.0
		}

	var cost: int = int(info.get("cost", 0))
	var chance: float = float(info.get("success_chance", 0.0))

	if PlayerProgression == null:
		return {"attempted": false, "success": false, "message": "Player progression is not available."}

	if int(PlayerProgression.gold) < cost:
		return {
			"attempted": false,
			"success": false,
			"message": "Not enough Gold. The forge will wait.",
			"cost": cost,
			"chance": chance
		}

	if not PlayerProgression.spend_gold(cost):
		return {
			"attempted": false,
			"success": false,
			"message": "Could not pay the forging cost.",
			"cost": cost,
			"chance": chance
		}

	var previous_level: int = int(info.get("current_level", 1))
	var roll: float = randf() * 100.0
	var succeeded: bool = roll < chance

	if succeeded:
		PlayerProgression.gear_levels[gear_type] = previous_level + 1

		# Keep HP within the new maximum after a helmet upgrade.
		PlayerProgression.ensure_hp_initialized()
		PlayerProgression.current_hp = mini(
			int(PlayerProgression.current_hp),
			int(PlayerProgression.get_total_max_hp())
		)
		PlayerProgression.stats_changed.emit()
		PlayerProgression.hp_changed.emit()

		_request_save()

		return {
			"attempted": true,
			"success": true,
			"message": "%s reached Level %d!" % [str(info.get("name", gear_type.capitalize())), previous_level + 1],
			"cost": cost,
			"chance": chance,
			"old_level": previous_level,
			"new_level": previous_level + 1,
			"roll": roll
		}

	# A failed strike costs Gold but never destroys or downgrades existing gear.
	PlayerProgression.stats_changed.emit()
	_request_save()

	return {
		"attempted": true,
		"success": false,
		"message": "The strike slipped. Gold was spent, but your gear is safe.",
		"cost": cost,
		"chance": chance,
		"old_level": previous_level,
		"new_level": previous_level,
		"roll": roll
	}


static func get_current_player_stat(stat_key: String) -> int:
	if PlayerProgression == null:
		return 0
	match stat_key:
		"atk":
			return int(PlayerProgression.get_total_atk())
		"def":
			return int(PlayerProgression.get_total_def())
		"hp":
			return int(PlayerProgression.get_total_max_hp())
		_:
			return 0


static func get_current_gear_bonus(gear_type: String) -> int:
	var definition: Dictionary = get_gear_definition(gear_type)
	if definition.is_empty():
		return 0
	var level: int = get_current_level(gear_type)
	return maxi(level - 1, 0) * int(definition.get("bonus_per_level", 0))


static func _request_save() -> void:
	if is_instance_valid(GameManager) and GameManager.has_method("request_save"):
		GameManager.request_save()
