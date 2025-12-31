extends Node
## PlayerProgress - Singleton that tracks player progression, currency, and equipped parts
## Saves/loads from user://player_progress.json
## Uses strongly typed properties and PartData enums

signal currency_changed(new_amount: int)
signal part_unlocked(part_id: String, category: PartData.Category)
signal part_purchased(part_id: String, category: PartData.Category)
signal part_equipped(part_id: String, category: PartData.Category)
signal wins_changed(new_wins: int)
signal car_color_changed(new_color: Color)

const SAVE_PATH: String = "user://player_progress.json"

## Preset car colors
const CAR_COLORS: Array[Color] = [
	Color.WHITE,
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.YELLOW,
	Color.ORANGE,
	Color.PURPLE,
	Color.CYAN,
	Color.HOT_PINK,
	Color.LIME_GREEN
]

## Player stats (strongly typed)
var currency: int = 0
var wins: int = 0
var races_completed: int = 0
var car_color_index: int = 0  # Index into CAR_COLORS

## Parts tracking - category string -> Array of part IDs
## Using strings for JSON compatibility, but validated against PartData.Category
var _unlocked_parts: Dictionary = {}  # "engines" -> ["stock", "basic"]
var _owned_parts: Dictionary = {}     # "engines" -> ["stock"]
var _equipped: Dictionary = {}        # "engines" -> "stock"

func _ready() -> void:
	_init_defaults()
	load_progress()

## Initialize default values with stock parts
func _init_defaults() -> void:
	_equipped.clear()
	_unlocked_parts.clear()
	_owned_parts.clear()

	for category in PartData.get_all_categories():
		var cat_str := PartData.category_to_string(category)
		var default_id := PartData.get_default_id(category)

		_equipped[cat_str] = default_id
		_unlocked_parts[cat_str] = [default_id]
		_owned_parts[cat_str] = [default_id]

## Save progress to file
func save_progress() -> void:
	var data: Dictionary = {
		"currency": currency,
		"wins": wins,
		"races_completed": races_completed,
		"car_color_index": car_color_index,
		"unlocked_parts": _unlocked_parts,
		"owned_parts": _owned_parts,
		"equipped": _equipped
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("[PlayerProgress] Saved to %s" % SAVE_PATH)

## Load progress from file
func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[PlayerProgress] No save file found, using defaults")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()

		var data = JSON.parse_string(content)
		if data and data is Dictionary:
			currency = int(data.get("currency", 0))
			wins = int(data.get("wins", 0))
			races_completed = int(data.get("races_completed", 0))
			car_color_index = int(data.get("car_color_index", 0))

			# Load parts data with fallback to defaults
			var loaded_unlocked: Dictionary = data.get("unlocked_parts", {})
			var loaded_owned: Dictionary = data.get("owned_parts", {})
			var loaded_equipped: Dictionary = data.get("equipped", {})

			for category in PartData.get_all_categories():
				var cat_str := PartData.category_to_string(category)
				if cat_str in loaded_unlocked:
					_unlocked_parts[cat_str] = loaded_unlocked[cat_str]
				if cat_str in loaded_owned:
					_owned_parts[cat_str] = loaded_owned[cat_str]
				if cat_str in loaded_equipped:
					_equipped[cat_str] = loaded_equipped[cat_str]

			print("[PlayerProgress] Loaded: %d currency, %d wins" % [currency, wins])

# =============================================================================
# Currency Management
# =============================================================================

## Add currency (from race rewards)
func add_currency(amount: int) -> void:
	currency += amount
	currency_changed.emit(currency)
	save_progress()

## Remove currency (for purchases)
func spend_currency(amount: int) -> bool:
	if currency >= amount:
		currency -= amount
		currency_changed.emit(currency)
		save_progress()
		return true
	return false

## Check if player can afford a price
func can_afford(price: int) -> bool:
	return currency >= price

# =============================================================================
# Race Completion
# =============================================================================

## Add a win and check for unlocks
func add_win() -> void:
	wins += 1
	wins_changed.emit(wins)
	check_unlocks()
	save_progress()

## Complete a race (track stats, award currency)
func complete_race(position: int) -> int:
	races_completed += 1

	# Calculate reward from config
	var rewards: Dictionary = ConfigManager.get_position_rewards()
	var reward: int = int(rewards.get(str(position), rewards.get("default", 50)))

	# Add completion bonus
	var race_rewards: Dictionary = ConfigManager.get_race_rewards()
	var completion_bonus: int = int(race_rewards.get("completion_bonus", 25))
	reward += completion_bonus

	add_currency(reward)

	# Track win
	if position == 1:
		add_win()
	else:
		save_progress()

	return reward

# =============================================================================
# Part Unlocking
# =============================================================================

## Check if a part is unlocked (by wins requirement)
func is_unlocked(category: PartData.Category, part_id: String) -> bool:
	var cat_str := PartData.category_to_string(category)
	if cat_str in _unlocked_parts:
		return part_id in _unlocked_parts[cat_str]
	return false

## Check if a part is unlocked (string category version)
func is_unlocked_str(category_str: String, part_id: String) -> bool:
	var category := PartData.string_to_category(category_str)
	return is_unlocked(category, part_id)

## Check all parts for new unlocks based on current wins
func check_unlocks() -> void:
	for category in PartData.get_all_categories():
		var cat_str := PartData.category_to_string(category)
		var parts_in_category: Dictionary = ConfigManager.get_parts_category(cat_str)

		for part_id: String in parts_in_category.keys():
			var part_data: Dictionary = parts_in_category[part_id]
			var unlock_wins: int = int(part_data.get("unlock_wins", 0))

			if wins >= unlock_wins and not is_unlocked(category, part_id):
				_unlock_part(category, part_id)

## Internal: Unlock a part
func _unlock_part(category: PartData.Category, part_id: String) -> void:
	var cat_str := PartData.category_to_string(category)

	if cat_str not in _unlocked_parts:
		_unlocked_parts[cat_str] = []

	if part_id not in _unlocked_parts[cat_str]:
		_unlocked_parts[cat_str].append(part_id)
		part_unlocked.emit(part_id, category)
		print("[PlayerProgress] Unlocked %s in %s!" % [part_id, cat_str])

# =============================================================================
# Part Ownership
# =============================================================================

## Check if a part is owned
func is_owned(category: PartData.Category, part_id: String) -> bool:
	var cat_str := PartData.category_to_string(category)
	if cat_str in _owned_parts:
		return part_id in _owned_parts[cat_str]
	return false

## Check if a part is owned (string category version)
func is_owned_str(category_str: String, part_id: String) -> bool:
	var category := PartData.string_to_category(category_str)
	return is_owned(category, part_id)

## Purchase a part
func purchase_part(category: PartData.Category, part_id: String) -> bool:
	var cat_str := PartData.category_to_string(category)

	# Check if unlocked
	if not is_unlocked(category, part_id):
		print("[PlayerProgress] Part not unlocked: %s/%s" % [cat_str, part_id])
		return false

	# Check if already owned
	if is_owned(category, part_id):
		print("[PlayerProgress] Part already owned: %s/%s" % [cat_str, part_id])
		return false

	# Get price from config
	var part_data: Dictionary = ConfigManager.get_part(cat_str, part_id)
	var price: int = int(part_data.get("price", 0))

	# Check if can afford
	if not can_afford(price):
		print("[PlayerProgress] Cannot afford %s/%s (need %d, have %d)" % [cat_str, part_id, price, currency])
		return false

	# Purchase
	spend_currency(price)

	if cat_str not in _owned_parts:
		_owned_parts[cat_str] = []
	_owned_parts[cat_str].append(part_id)

	part_purchased.emit(part_id, category)
	print("[PlayerProgress] Purchased %s in %s for %d" % [part_id, cat_str, price])
	save_progress()
	return true

## Purchase a part (string category version)
func purchase_part_str(category_str: String, part_id: String) -> bool:
	var category := PartData.string_to_category(category_str)
	return purchase_part(category, part_id)

# =============================================================================
# Part Equipment
# =============================================================================

## Equip a part
func equip_part(category: PartData.Category, part_id: String) -> bool:
	var cat_str := PartData.category_to_string(category)

	# Check if owned
	if not is_owned(category, part_id):
		print("[PlayerProgress] Cannot equip unowned part: %s/%s" % [cat_str, part_id])
		return false

	_equipped[cat_str] = part_id
	part_equipped.emit(part_id, category)
	save_progress()
	return true

## Equip a part (string category version)
func equip_part_str(category_str: String, part_id: String) -> bool:
	var category := PartData.string_to_category(category_str)
	return equip_part(category, part_id)

## Get currently equipped part for a category
func get_equipped(category: PartData.Category) -> String:
	var cat_str := PartData.category_to_string(category)
	return _equipped.get(cat_str, PartData.get_default_id(category))

## Get currently equipped part (string category version)
func get_equipped_str(category_str: String) -> String:
	var category := PartData.string_to_category(category_str)
	return get_equipped(category)

## Get all equipped parts as Dictionary (for CarModifiers)
func get_all_equipped() -> Dictionary:
	return _equipped.duplicate()

## Get PartData for an equipped part
func get_equipped_part_data(category: PartData.Category) -> PartData:
	var cat_str := PartData.category_to_string(category)
	var part_id: String = get_equipped(category)
	var data: Dictionary = ConfigManager.get_part(cat_str, part_id)
	if data.is_empty():
		return null
	return PartData.from_dict(part_id, category, data)

# =============================================================================
# Utility
# =============================================================================

## Get all unlocked parts for a category
func get_unlocked_parts(category: PartData.Category) -> Array:
	var cat_str := PartData.category_to_string(category)
	return _unlocked_parts.get(cat_str, []).duplicate()

## Get all owned parts for a category
func get_owned_parts(category: PartData.Category) -> Array:
	var cat_str := PartData.category_to_string(category)
	return _owned_parts.get(cat_str, []).duplicate()

# =============================================================================
# Car Color
# =============================================================================

## Get current car color
func get_car_color() -> Color:
	if car_color_index >= 0 and car_color_index < CAR_COLORS.size():
		return CAR_COLORS[car_color_index]
	return Color.WHITE

## Set car color by index
func set_car_color(index: int) -> void:
	if index >= 0 and index < CAR_COLORS.size():
		car_color_index = index
		car_color_changed.emit(get_car_color())
		save_progress()

## Get all available colors
func get_available_colors() -> Array[Color]:
	return CAR_COLORS

## Reset progress (for testing or new game)
func reset_progress() -> void:
	currency = 0
	wins = 0
	races_completed = 0
	car_color_index = 0
	_init_defaults()
	save_progress()
	print("[PlayerProgress] Progress reset!")
