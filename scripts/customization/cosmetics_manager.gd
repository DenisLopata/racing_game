extends Node
## CosmeticsManager - Autoload singleton for managing cosmetic unlocks
## Handles liveries, decals, and wheel designs

signal cosmetic_unlocked(cosmetic_id: String, category: String)

const SAVE_PATH: String = "user://cosmetics.json"

# Cosmetic categories
enum Category { LIVERY, DECAL, WHEELS }

# All available cosmetics
const COSMETICS: Dictionary = {
	# Livery patterns
	"livery_solid": {
		"category": "livery",
		"name": "Solid Color",
		"description": "Clean single color finish",
		"unlock_type": "default",
		"price": 0
	},
	"livery_stripes": {
		"category": "livery",
		"name": "Racing Stripes",
		"description": "Classic dual racing stripes",
		"unlock_type": "purchase",
		"price": 500
	},
	"livery_gradient": {
		"category": "livery",
		"name": "Gradient Fade",
		"description": "Two-tone gradient finish",
		"unlock_type": "purchase",
		"price": 750
	},
	"livery_flames": {
		"category": "livery",
		"name": "Hot Rod Flames",
		"description": "Classic flame pattern",
		"unlock_type": "achievement",
		"achievement_id": "speed_demon",
		"price": 0
	},
	"livery_carbon": {
		"category": "livery",
		"name": "Carbon Fiber",
		"description": "Technical carbon weave pattern",
		"unlock_type": "purchase",
		"price": 1000
	},
	"livery_camo": {
		"category": "livery",
		"name": "Racing Camo",
		"description": "Urban camouflage pattern",
		"unlock_type": "wins",
		"wins_required": 10,
		"price": 0
	},

	# Decals
	"decal_none": {
		"category": "decal",
		"name": "No Decal",
		"description": "Clean look",
		"unlock_type": "default",
		"price": 0
	},
	"decal_number_1": {
		"category": "decal",
		"name": "Number 1",
		"description": "Racing number 1",
		"unlock_type": "achievement",
		"achievement_id": "first_win",
		"price": 0
	},
	"decal_star": {
		"category": "decal",
		"name": "Star",
		"description": "Champion star emblem",
		"unlock_type": "wins",
		"wins_required": 5,
		"price": 0
	},
	"decal_lightning": {
		"category": "decal",
		"name": "Lightning Bolt",
		"description": "Speed lightning decal",
		"unlock_type": "purchase",
		"price": 300
	},
	"decal_skull": {
		"category": "decal",
		"name": "Skull",
		"description": "Intimidating skull design",
		"unlock_type": "achievement",
		"achievement_id": "survivor",
		"price": 0
	},

	# Wheel designs
	"wheels_standard": {
		"category": "wheels",
		"name": "Standard",
		"description": "Factory wheels",
		"unlock_type": "default",
		"price": 0
	},
	"wheels_sport": {
		"category": "wheels",
		"name": "Sport Alloys",
		"description": "Lightweight sport wheels",
		"unlock_type": "purchase",
		"price": 400
	},
	"wheels_gold": {
		"category": "wheels",
		"name": "Gold Rims",
		"description": "Flashy gold finish",
		"unlock_type": "purchase",
		"price": 800
	},
	"wheels_chrome": {
		"category": "wheels",
		"name": "Chrome",
		"description": "Mirror chrome finish",
		"unlock_type": "wins",
		"wins_required": 15,
		"price": 0
	}
}

# Player's owned and equipped cosmetics
var owned_cosmetics: Array[String] = []
var equipped: Dictionary = {
	"livery": "livery_solid",
	"decal": "decal_none",
	"wheels": "wheels_standard"
}

# Secondary color for two-tone liveries
var secondary_color_index: int = 1

func _ready() -> void:
	_init_defaults()
	load_cosmetics()

func _init_defaults() -> void:
	owned_cosmetics.clear()
	# Add default cosmetics
	for cosmetic_id in COSMETICS:
		if COSMETICS[cosmetic_id].get("unlock_type", "") == "default":
			owned_cosmetics.append(cosmetic_id)

## Check and unlock cosmetics based on player progress
func check_unlocks() -> void:
	if not PlayerProgress:
		return

	for cosmetic_id in COSMETICS:
		if cosmetic_id in owned_cosmetics:
			continue

		var data = COSMETICS[cosmetic_id]
		var unlock_type = data.get("unlock_type", "")

		match unlock_type:
			"wins":
				var wins_required = data.get("wins_required", 0)
				if PlayerProgress.wins >= wins_required:
					_unlock_cosmetic(cosmetic_id)
			"achievement":
				var achievement_id = data.get("achievement_id", "")
				if AchievementManager and AchievementManager.is_unlocked(achievement_id):
					_unlock_cosmetic(cosmetic_id)

func _unlock_cosmetic(cosmetic_id: String) -> void:
	if cosmetic_id in owned_cosmetics:
		return

	owned_cosmetics.append(cosmetic_id)
	var data = COSMETICS.get(cosmetic_id, {})
	var category = data.get("category", "")
	cosmetic_unlocked.emit(cosmetic_id, category)
	save_cosmetics()
	print("[Cosmetics] Unlocked: %s" % data.get("name", cosmetic_id))

## Purchase a cosmetic
func purchase_cosmetic(cosmetic_id: String) -> bool:
	if cosmetic_id in owned_cosmetics:
		return false  # Already owned

	if cosmetic_id not in COSMETICS:
		return false

	var data = COSMETICS[cosmetic_id]
	var price = data.get("price", 0)

	if not PlayerProgress or not PlayerProgress.can_afford(price):
		return false

	PlayerProgress.spend_currency(price)
	_unlock_cosmetic(cosmetic_id)
	return true

## Equip a cosmetic
func equip_cosmetic(cosmetic_id: String) -> bool:
	if cosmetic_id not in owned_cosmetics:
		return false

	var data = COSMETICS.get(cosmetic_id, {})
	var category = data.get("category", "")

	if category in equipped:
		equipped[category] = cosmetic_id
		save_cosmetics()
		return true

	return false

## Get equipped cosmetic for a category
func get_equipped(category: String) -> String:
	return equipped.get(category, "")

## Get cosmetic data
func get_cosmetic_data(cosmetic_id: String) -> Dictionary:
	return COSMETICS.get(cosmetic_id, {})

## Check if cosmetic is owned
func is_owned(cosmetic_id: String) -> bool:
	return cosmetic_id in owned_cosmetics

## Check if cosmetic is unlockable (but not yet unlocked)
func is_unlockable(cosmetic_id: String) -> bool:
	if cosmetic_id in owned_cosmetics:
		return false

	var data = COSMETICS.get(cosmetic_id, {})
	var unlock_type = data.get("unlock_type", "")

	return unlock_type in ["wins", "achievement"]

## Check if cosmetic is purchasable
func is_purchasable(cosmetic_id: String) -> bool:
	if cosmetic_id in owned_cosmetics:
		return false

	var data = COSMETICS.get(cosmetic_id, {})
	return data.get("unlock_type", "") == "purchase"

## Get all cosmetics in a category
func get_cosmetics_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for cosmetic_id in COSMETICS:
		var data = COSMETICS[cosmetic_id]
		if data.get("category", "") == category:
			var item = data.duplicate()
			item["id"] = cosmetic_id
			item["owned"] = cosmetic_id in owned_cosmetics
			item["equipped"] = equipped.get(category, "") == cosmetic_id
			result.append(item)

	return result

## Get unlock progress text for a cosmetic
func get_unlock_progress(cosmetic_id: String) -> String:
	var data = COSMETICS.get(cosmetic_id, {})
	var unlock_type = data.get("unlock_type", "")

	match unlock_type:
		"purchase":
			return "Purchase for %d" % data.get("price", 0)
		"wins":
			var required = data.get("wins_required", 0)
			var current = PlayerProgress.wins if PlayerProgress else 0
			return "Win %d races (%d/%d)" % [required, current, required]
		"achievement":
			var achievement_id = data.get("achievement_id", "")
			if AchievementManager:
				var achievement = AchievementManager.get_achievement(achievement_id)
				return "Unlock: %s" % achievement.get("name", achievement_id)
			return "Unlock achievement"
		_:
			return ""

## Set secondary color index (for two-tone liveries)
func set_secondary_color(index: int) -> void:
	secondary_color_index = index
	save_cosmetics()

func get_secondary_color() -> Color:
	if PlayerProgress:
		var colors = PlayerProgress.get_available_colors()
		if secondary_color_index >= 0 and secondary_color_index < colors.size():
			return colors[secondary_color_index]
	return Color.GRAY

# =============================================================================
# Save/Load
# =============================================================================

func save_cosmetics() -> void:
	var data: Dictionary = {
		"owned": owned_cosmetics,
		"equipped": equipped,
		"secondary_color_index": secondary_color_index
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_cosmetics() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()

		var data = JSON.parse_string(content)
		if data and data is Dictionary:
			# Load owned
			owned_cosmetics.clear()
			for cosmetic_id in data.get("owned", []):
				owned_cosmetics.append(cosmetic_id)

			# Ensure defaults are always owned
			for cosmetic_id in COSMETICS:
				if COSMETICS[cosmetic_id].get("unlock_type", "") == "default":
					if cosmetic_id not in owned_cosmetics:
						owned_cosmetics.append(cosmetic_id)

			# Load equipped
			var loaded_equipped = data.get("equipped", {})
			for category in loaded_equipped:
				if category in equipped:
					equipped[category] = loaded_equipped[category]

			secondary_color_index = int(data.get("secondary_color_index", 1))

			print("[Cosmetics] Loaded %d owned cosmetics" % owned_cosmetics.size())
