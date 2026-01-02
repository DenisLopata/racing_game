extends Node
## AchievementManager - Singleton that tracks and unlocks achievements
## Register as autoload "AchievementManager" in Project Settings

signal achievement_unlocked(achievement_id: String, achievement: Dictionary)

# Achievement definitions
const ACHIEVEMENTS: Dictionary = {
	# Racing achievements
	"first_win": {
		"name": "First Victory",
		"description": "Win your first race",
		"icon": "trophy",
		"category": "racing",
		"condition": "wins >= 1"
	},
	"triple_crown": {
		"name": "Triple Crown",
		"description": "Win 3 races",
		"icon": "trophy",
		"category": "racing",
		"condition": "wins >= 3"
	},
	"champion": {
		"name": "Champion",
		"description": "Win 10 races",
		"icon": "trophy_gold",
		"category": "racing",
		"condition": "wins >= 10"
	},
	"legend": {
		"name": "Living Legend",
		"description": "Win 25 races",
		"icon": "star",
		"category": "racing",
		"condition": "wins >= 25"
	},
	"podium_regular": {
		"name": "Podium Regular",
		"description": "Finish in top 3 ten times",
		"icon": "medal",
		"category": "racing",
		"condition": "podiums >= 10"
	},
	"consistent": {
		"name": "Consistency",
		"description": "Complete 20 races",
		"icon": "check",
		"category": "racing",
		"condition": "total_races >= 20"
	},

	# Skill achievements
	"untouchable": {
		"name": "Untouchable",
		"description": "Win a race with no damage taken",
		"icon": "shield",
		"category": "skill",
		"condition": "special:no_damage_win"
	},
	"survivor": {
		"name": "Survivor",
		"description": "Win with over 50% total damage",
		"icon": "heart",
		"category": "skill",
		"condition": "special:damaged_win"
	},
	"comeback": {
		"name": "Comeback King",
		"description": "Win after being in last place",
		"icon": "arrow_up",
		"category": "skill",
		"condition": "special:comeback_win"
	},
	"perfect_start": {
		"name": "Perfect Start",
		"description": "Lead from start to finish",
		"icon": "flag",
		"category": "skill",
		"condition": "special:led_every_lap"
	},

	# Damage achievements
	"first_crash": {
		"name": "First Scratch",
		"description": "Take damage for the first time",
		"icon": "warning",
		"category": "damage",
		"condition": "special:first_damage"
	},
	"battle_scarred": {
		"name": "Battle Scarred",
		"description": "Accumulate 500% total damage across races",
		"icon": "explosion",
		"category": "damage",
		"condition": "total_damage >= 5.0"
	},
	"phoenix": {
		"name": "Phoenix",
		"description": "Win after using a pit stop",
		"icon": "fire",
		"category": "damage",
		"condition": "special:pit_stop_win"
	},
	"mechanic": {
		"name": "Regular Customer",
		"description": "Repair your car 10 times",
		"icon": "wrench",
		"category": "damage",
		"condition": "total_repairs >= 10"
	},

	# Progression achievements
	"first_purchase": {
		"name": "First Upgrade",
		"description": "Purchase your first part",
		"icon": "cart",
		"category": "progression",
		"condition": "special:first_purchase"
	},
	"collector": {
		"name": "Collector",
		"description": "Own 10 different parts",
		"icon": "box",
		"category": "progression",
		"condition": "owned_parts >= 10"
	},
	"wealthy": {
		"name": "Deep Pockets",
		"description": "Have 10,000 currency at once",
		"icon": "coin",
		"category": "progression",
		"condition": "currency >= 10000"
	},
	"big_spender": {
		"name": "Big Spender",
		"description": "Spend 25,000 currency total",
		"icon": "money",
		"category": "progression",
		"condition": "total_spent >= 25000"
	}
}

# Track unlocked achievements
var _unlocked: Array[String] = []

# Track special conditions for current race
var _race_stats: Dictionary = {
	"damage_taken": 0.0,
	"was_last": false,
	"led_every_lap": true,
	"used_pit_stop": false,
	"current_position": 1
}

# Track lifetime stats not in PlayerProgress
var _lifetime_stats: Dictionary = {
	"total_spent": 0
}

const SAVE_PATH: String = "user://achievements.json"

func _ready() -> void:
	load_achievements()
	_connect_signals()

func _connect_signals() -> void:
	# Connect to PlayerProgress signals
	if PlayerProgress:
		PlayerProgress.currency_changed.connect(_on_currency_changed)
		PlayerProgress.part_purchased.connect(_on_part_purchased)
		PlayerProgress.wins_changed.connect(_on_wins_changed)
		PlayerProgress.damage_changed.connect(_on_damage_changed)
		PlayerProgress.part_repaired.connect(_on_part_repaired)

	# Connect to DamageSystem
	if DamageSystem:
		DamageSystem.damage_taken.connect(_on_damage_taken)

	# Connect to RaceManager
	if RaceManager:
		RaceManager.race_started.connect(_on_race_started)
		RaceManager.race_finished.connect(_on_race_finished)
		RaceManager.car_finished.connect(_on_car_finished)

## Check if an achievement is unlocked
func is_unlocked(achievement_id: String) -> bool:
	return achievement_id in _unlocked

## Get all achievements (with unlock status)
func get_all_achievements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ACHIEVEMENTS.keys():
		var achievement = ACHIEVEMENTS[id].duplicate()
		achievement["id"] = id
		achievement["unlocked"] = is_unlocked(id)
		result.append(achievement)
	return result

## Get achievements by category
func get_achievements_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ACHIEVEMENTS.keys():
		if ACHIEVEMENTS[id]["category"] == category:
			var achievement = ACHIEVEMENTS[id].duplicate()
			achievement["id"] = id
			achievement["unlocked"] = is_unlocked(id)
			result.append(achievement)
	return result

## Get unlock progress (unlocked / total)
func get_progress() -> Dictionary:
	return {
		"unlocked": _unlocked.size(),
		"total": ACHIEVEMENTS.size()
	}

## Unlock an achievement
func unlock(achievement_id: String) -> void:
	if achievement_id in _unlocked:
		return

	if achievement_id not in ACHIEVEMENTS:
		push_warning("Unknown achievement: %s" % achievement_id)
		return

	_unlocked.append(achievement_id)
	save_achievements()

	var achievement = ACHIEVEMENTS[achievement_id].duplicate()
	achievement["id"] = achievement_id
	achievement_unlocked.emit(achievement_id, achievement)
	print("[Achievements] Unlocked: %s" % ACHIEVEMENTS[achievement_id]["name"])

## Check all achievements against current stats
func check_all() -> void:
	for id in ACHIEVEMENTS.keys():
		if is_unlocked(id):
			continue

		var condition = ACHIEVEMENTS[id]["condition"]
		if _evaluate_condition(condition):
			unlock(id)

## Evaluate an achievement condition
func _evaluate_condition(condition: String) -> bool:
	if condition.begins_with("special:"):
		return false  # Special conditions checked elsewhere

	# Parse condition like "wins >= 10"
	var parts = condition.split(" ")
	if parts.size() != 3:
		return false

	var stat_name = parts[0]
	var operator = parts[1]
	var value = float(parts[2])

	var current_value = _get_stat_value(stat_name)

	match operator:
		">=":
			return current_value >= value
		">":
			return current_value > value
		"==":
			return current_value == value
		"<=":
			return current_value <= value
		"<":
			return current_value < value

	return false

## Get current value of a stat
func _get_stat_value(stat_name: String) -> float:
	if not PlayerProgress:
		return 0.0

	var stats = PlayerProgress.get_statistics_summary()

	match stat_name:
		"wins":
			return float(PlayerProgress.wins)
		"total_races":
			return float(stats.get("total_races", 0))
		"podiums":
			return float(stats.get("podiums", 0))
		"currency":
			return float(PlayerProgress.currency)
		"total_damage":
			return stats.get("total_damage_taken", 0.0)
		"total_repairs":
			return float(stats.get("total_repairs", 0))
		"owned_parts":
			return float(_count_owned_parts())
		"total_spent":
			return float(_lifetime_stats.get("total_spent", 0))

	return 0.0

func _count_owned_parts() -> int:
	if not PlayerProgress:
		return 0

	var count = 0
	for category in PartData.get_all_categories():
		count += PlayerProgress.get_owned_parts(category).size()
	return count

# =============================================================================
# Signal Handlers
# =============================================================================

func _on_currency_changed(new_amount: int) -> void:
	check_all()

func _on_part_purchased(_part_id: String, _category) -> void:
	# Track spending
	# Note: Would need to track amount spent, simplified here
	if not is_unlocked("first_purchase"):
		unlock("first_purchase")
	check_all()

func _on_wins_changed(_new_wins: int) -> void:
	check_all()

func _on_damage_changed(_part: String, _new_health: float) -> void:
	if not is_unlocked("first_crash"):
		unlock("first_crash")

func _on_part_repaired(_part: String) -> void:
	check_all()

func _on_damage_taken(car: Node, _part: String, amount: float, _new_health: float) -> void:
	# Only track player damage
	if car.get("use_player_upgrades"):
		_race_stats["damage_taken"] += amount

func _on_race_started() -> void:
	# Reset race-specific tracking
	_race_stats = {
		"damage_taken": 0.0,
		"was_last": false,
		"led_every_lap": true,
		"used_pit_stop": false,
		"current_position": 1
	}

func _on_race_finished(_results: Array) -> void:
	check_all()

func _on_car_finished(car: Car, position: int, _total_time: float) -> void:
	if not car.get("use_player_upgrades"):
		return

	# Check special win conditions
	if position == 1:
		# Untouchable - win with no damage
		if _race_stats["damage_taken"] < 0.01:
			unlock("untouchable")

		# Survivor - win with heavy damage
		if _race_stats["damage_taken"] > 0.5:
			unlock("survivor")

		# Comeback - win after being last
		if _race_stats["was_last"]:
			unlock("comeback")

		# Perfect start - led every lap
		if _race_stats["led_every_lap"]:
			unlock("perfect_start")

		# Phoenix - win after pit stop
		if _race_stats["used_pit_stop"]:
			unlock("phoenix")

## Called when player uses pit stop
func on_pit_stop_used() -> void:
	_race_stats["used_pit_stop"] = true

## Called when player position changes
func on_position_changed(new_position: int, total_cars: int) -> void:
	_race_stats["current_position"] = new_position

	# Track if was ever in last place
	if new_position == total_cars:
		_race_stats["was_last"] = true

	# Track if ever lost the lead
	if new_position > 1:
		_race_stats["led_every_lap"] = false

# =============================================================================
# Save/Load
# =============================================================================

func save_achievements() -> void:
	var data = {
		"unlocked": _unlocked,
		"lifetime_stats": _lifetime_stats
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_achievements() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()

		var data = JSON.parse_string(content)
		if data and data is Dictionary:
			var loaded_unlocked = data.get("unlocked", [])
			_unlocked.clear()
			for id in loaded_unlocked:
				_unlocked.append(id)

			_lifetime_stats = data.get("lifetime_stats", {})

		print("[Achievements] Loaded %d unlocked achievements" % _unlocked.size())
