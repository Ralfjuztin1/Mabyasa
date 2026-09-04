extends Node

signal stats_changed
signal leveled_up

# --- CORE DATA (Saved to JSON) ---
var level: int = 1
var current_exp: int = 0
var gold: int = 0
var active_pet_id: String = ""

# Gear tracks the upgrade level. (1 = Base). 
var gear_levels: Dictionary = {
	"sword": 1,
	"armor": 1,
	"helmet": 1
}

# --- STATIC BALANCING DATA (Never saved to JSON) ---
const BASE_HP: int = 100
const BASE_ATK: int = 10
const BASE_DEF: int = 5

const STAT_GROWTH = { "hp": 15, "atk": 3, "def": 2 }
const GEAR_BONUS = { "sword_atk": 4, "armor_def": 3, "helmet_hp": 20 }
const GEAR_UPGRADE_COST_BASE = 150

# --- EXP & LEVELING ---
func get_max_exp(lvl: int) -> int:
	var base_req = int(150 * pow(1.2, lvl - 1))
	
	# Zone Soft-Caps: Massive EXP spikes to prevent low-level zone grinding
	if lvl >= 10 and lvl < 20: return base_req + 15000
	if lvl >= 20 and lvl < 30: return base_req + 65000
	return base_req

func add_exp(amount: int) -> void:
	current_exp += amount
	var leveled = false
	
	while current_exp >= get_max_exp(level):
		current_exp -= get_max_exp(level)
		level += 1
		leveled = true
		
	if leveled:
		leveled_up.emit()
	stats_changed.emit()

# --- DYNAMIC STAT CALCULATORS ---
func get_total_atk() -> int:
	var total = BASE_ATK + ((level - 1) * STAT_GROWTH["atk"])
	total += (gear_levels["sword"] - 1) * GEAR_BONUS["sword_atk"]
	# total += PetManager.get_pet_atk(active_pet_id) # Ready for PetManager integration
	return total

func get_total_def() -> int:
	var total = BASE_DEF + ((level - 1) * STAT_GROWTH["def"])
	total += (gear_levels["armor"] - 1) * GEAR_BONUS["armor_def"]
	return total

func get_total_max_hp() -> int:
	var total = BASE_HP + ((level - 1) * STAT_GROWTH["hp"])
	total += (gear_levels["helmet"] - 1) * GEAR_BONUS["helmet_hp"]
	return total

# --- ECONOMY & UPGRADES ---
func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		stats_changed.emit()
		return true
	return false

func upgrade_gear(gear_type: String) -> bool:
	if not gear_levels.has(gear_type): return false
	
	var cost = GEAR_UPGRADE_COST_BASE * gear_levels[gear_type]
	if spend_gold(cost):
		gear_levels[gear_type] += 1
		stats_changed.emit()
		print("❖ Upgraded ", gear_type, " to Lv.", gear_levels[gear_type])
		return true
	return false

# --- JSON SERIALIZATION ---
func get_save_data() -> Dictionary:
	return {
		"level": level,
		"current_exp": current_exp,
		"gold": gold,
		"gear_levels": gear_levels,
		"active_pet_id": active_pet_id
	}

func load_save_data(data: Dictionary) -> void:
	if data.is_empty(): return
	level = data.get("level", 1)
	current_exp = data.get("current_exp", 0)
	gold = data.get("gold", 0)
	
	var saved_gears = data.get("gear_levels", {})
	for key in saved_gears.keys():
		if gear_levels.has(key):
			gear_levels[key] = saved_gears[key]
			
	active_pet_id = data.get("active_pet_id", "")
	stats_changed.emit()
