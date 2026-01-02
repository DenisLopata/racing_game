class_name ChampionshipManager
extends RefCounted
## Manages championship/season mode with multi-race progression

signal championship_started(championship: Dictionary)
signal race_completed(race_index: int, results: Array)
signal championship_completed(final_standings: Array)
signal points_updated(standings: Array)

const SAVE_PATH: String = "user://championship.json"

# Point distribution for positions (F1-style)
const POINTS_TABLE: Array[int] = [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]

# Championship tiers
const TIERS: Dictionary = {
	"rookie": {
		"name": "Rookie Cup",
		"races": 3,
		"unlock_requirement": 0,  # Always unlocked
		"reward_multiplier": 1.0,
		"ai_difficulty": "easy"
	},
	"amateur": {
		"name": "Amateur League",
		"races": 5,
		"unlock_requirement": 1,  # Beat Rookie
		"reward_multiplier": 1.5,
		"ai_difficulty": "medium"
	},
	"professional": {
		"name": "Pro Championship",
		"races": 5,
		"unlock_requirement": 2,  # Beat Amateur
		"reward_multiplier": 2.0,
		"ai_difficulty": "hard"
	},
	"master": {
		"name": "Master Series",
		"races": 7,
		"unlock_requirement": 3,  # Beat Pro
		"reward_multiplier": 3.0,
		"ai_difficulty": "expert"
	}
}

# Current championship state
var is_active: bool = false
var current_tier: String = ""
var current_race_index: int = 0
var championship_tracks: Array[String] = []
var standings: Dictionary = {}  # car_name -> {points, wins, podiums, races}
var race_results: Array = []  # Array of race result summaries
var player_name: String = "Player"

# Drivers in championship (includes player)
var drivers: Array[String] = []
const AI_DRIVER_NAMES: Array[String] = [
	"Martinez", "Chen", "Petrov", "Williams", "Nakamura",
	"Schmidt", "Costa", "Anderson", "Park", "Singh"
]

func _init() -> void:
	load_state()

## Start a new championship
func start_championship(tier: String, num_opponents: int = 7) -> bool:
	if tier not in TIERS:
		push_warning("[Championship] Unknown tier: %s" % tier)
		return false

	var tier_data = TIERS[tier]

	# Check unlock requirement
	if not is_tier_unlocked(tier):
		push_warning("[Championship] Tier %s is locked" % tier)
		return false

	# Reset state
	is_active = true
	current_tier = tier
	current_race_index = 0
	race_results.clear()
	standings.clear()

	# Setup drivers
	drivers.clear()
	drivers.append(player_name)

	# Add AI drivers
	var available_ai = AI_DRIVER_NAMES.duplicate()
	available_ai.shuffle()
	for i in min(num_opponents, available_ai.size()):
		drivers.append(available_ai[i])

	# Initialize standings
	for driver in drivers:
		standings[driver] = {
			"points": 0,
			"wins": 0,
			"podiums": 0,
			"races": 0,
			"best_finish": 99
		}

	# Select tracks for championship
	_select_championship_tracks(tier_data["races"])

	save_state()
	championship_started.emit(_get_championship_info())

	print("[Championship] Started %s with %d races, %d drivers" % [tier_data["name"], tier_data["races"], drivers.size()])
	return true

## Select tracks for the championship
func _select_championship_tracks(num_races: int) -> void:
	championship_tracks.clear()

	# Get available tracks from config
	var all_tracks = ConfigManager.get_all_tracks()
	var unlocked_tracks: Array[String] = []

	for track in all_tracks:
		if not track.get("locked", false) and not track.get("is_procedural", false):
			unlocked_tracks.append(track["id"])

	# Shuffle and select
	unlocked_tracks.shuffle()

	# If we need more races than tracks, repeat some
	while championship_tracks.size() < num_races:
		for track_id in unlocked_tracks:
			championship_tracks.append(track_id)
			if championship_tracks.size() >= num_races:
				break

## Record race results and update standings
func record_race_result(results: Array) -> void:
	if not is_active:
		return

	var race_summary: Dictionary = {
		"race_index": current_race_index,
		"track_id": get_current_track(),
		"positions": []
	}

	# Process each finisher
	for i in results.size():
		var result = results[i]
		var car = result.get("car")
		var driver_name = _get_driver_name_for_car(car)

		if driver_name.is_empty():
			continue

		var position = i + 1
		var points = _get_points_for_position(position)
		var is_dnf = result.get("dnf", false)

		if is_dnf:
			points = 0
			position = -1

		# Update standings
		if driver_name in standings:
			standings[driver_name]["points"] += points
			standings[driver_name]["races"] += 1

			if position == 1:
				standings[driver_name]["wins"] += 1
			if position >= 1 and position <= 3:
				standings[driver_name]["podiums"] += 1
			if position > 0 and position < standings[driver_name]["best_finish"]:
				standings[driver_name]["best_finish"] = position

		race_summary["positions"].append({
			"driver": driver_name,
			"position": position,
			"points": points,
			"dnf": is_dnf
		})

	race_results.append(race_summary)
	current_race_index += 1

	points_updated.emit(get_standings_array())
	race_completed.emit(current_race_index - 1, race_summary["positions"])

	# Check if championship is complete
	if current_race_index >= get_total_races():
		_complete_championship()
	else:
		save_state()

## Get driver name for a car (player or AI)
func _get_driver_name_for_car(car: Node) -> String:
	if car == null:
		return ""

	if car.get("use_player_upgrades"):
		return player_name

	# AI car - match by index
	var car_name = car.name  # e.g., "AICar_0"
	if car_name.begins_with("AICar_"):
		var index = car_name.substr(6).to_int()
		if index + 1 < drivers.size():  # +1 because player is index 0
			return drivers[index + 1]

	return car_name

## Get points for a finishing position
func _get_points_for_position(position: int) -> int:
	if position <= 0 or position > POINTS_TABLE.size():
		return 0
	return POINTS_TABLE[position - 1]

## Complete the championship
func _complete_championship() -> void:
	is_active = false

	var final_standings = get_standings_array()

	# Award prizes based on player finish
	var player_finish = get_player_standing_position()
	var tier_data = TIERS.get(current_tier, {})
	var multiplier = tier_data.get("reward_multiplier", 1.0)

	# Base reward for completing championship
	var base_reward = 500
	var position_bonus = [1000, 500, 250, 100, 50]

	var reward = int(base_reward * multiplier)
	if player_finish > 0 and player_finish <= position_bonus.size():
		reward += int(position_bonus[player_finish - 1] * multiplier)

	# Award currency
	if PlayerProgress:
		PlayerProgress.add_currency(reward)

	# Record championship win for unlocking next tier
	if player_finish == 1:
		_record_championship_win()

	championship_completed.emit(final_standings)
	save_state()

	print("[Championship] Completed! Player finished P%d, earned %d credits" % [player_finish, reward])

## Record a championship win for tier progression
func _record_championship_win() -> void:
	# This would be tracked in PlayerProgress for unlock requirements
	# For now, we'll save it in the championship state
	pass

## Get standings as sorted array
func get_standings_array() -> Array:
	var standings_list: Array = []

	for driver in standings:
		var data = standings[driver].duplicate()
		data["driver"] = driver
		data["is_player"] = (driver == player_name)
		standings_list.append(data)

	# Sort by points (descending), then wins, then best finish
	standings_list.sort_custom(func(a, b):
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		if a["wins"] != b["wins"]:
			return a["wins"] > b["wins"]
		return a["best_finish"] < b["best_finish"]
	)

	# Assign positions
	for i in standings_list.size():
		standings_list[i]["position"] = i + 1

	return standings_list

## Get player's current standing position
func get_player_standing_position() -> int:
	var standings_list = get_standings_array()
	for data in standings_list:
		if data["driver"] == player_name:
			return data["position"]
	return -1

## Get current track for next race
func get_current_track() -> String:
	if current_race_index < championship_tracks.size():
		return championship_tracks[current_race_index]
	return ""

## Get total races in current championship
func get_total_races() -> int:
	return championship_tracks.size()

## Get championship info dictionary
func _get_championship_info() -> Dictionary:
	var tier_data = TIERS.get(current_tier, {})
	return {
		"tier": current_tier,
		"name": tier_data.get("name", "Championship"),
		"races": get_total_races(),
		"current_race": current_race_index,
		"tracks": championship_tracks.duplicate(),
		"ai_difficulty": tier_data.get("ai_difficulty", "medium"),
		"reward_multiplier": tier_data.get("reward_multiplier", 1.0)
	}

## Check if a tier is unlocked
func is_tier_unlocked(tier: String) -> bool:
	if tier not in TIERS:
		return false

	var requirement = TIERS[tier]["unlock_requirement"]

	# Rookie is always unlocked
	if requirement == 0:
		return true

	# Check if previous tiers have been won
	# For now, simplified - would need to track in PlayerProgress
	return true  # Unlock all for testing

## Get all championship tiers
func get_all_tiers() -> Array:
	var tiers: Array = []
	for tier_id in TIERS:
		var data = TIERS[tier_id].duplicate()
		data["id"] = tier_id
		data["unlocked"] = is_tier_unlocked(tier_id)
		tiers.append(data)
	return tiers

## Check if championship is active
func is_championship_active() -> bool:
	return is_active

## Get progress string (e.g., "Race 2 of 5")
func get_progress_string() -> String:
	if not is_active:
		return ""
	return "Race %d of %d" % [current_race_index + 1, get_total_races()]

## Abandon current championship
func abandon_championship() -> void:
	is_active = false
	current_tier = ""
	current_race_index = 0
	championship_tracks.clear()
	standings.clear()
	race_results.clear()
	drivers.clear()
	save_state()
	print("[Championship] Abandoned")

# =============================================================================
# Save/Load
# =============================================================================

func save_state() -> void:
	var data: Dictionary = {
		"is_active": is_active,
		"current_tier": current_tier,
		"current_race_index": current_race_index,
		"championship_tracks": championship_tracks,
		"standings": standings,
		"race_results": race_results,
		"drivers": drivers
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()

		var data = JSON.parse_string(content)
		if data and data is Dictionary:
			is_active = data.get("is_active", false)
			current_tier = data.get("current_tier", "")
			current_race_index = int(data.get("current_race_index", 0))

			championship_tracks.clear()
			for track in data.get("championship_tracks", []):
				championship_tracks.append(track)

			standings = data.get("standings", {})
			race_results = data.get("race_results", [])

			drivers.clear()
			for driver in data.get("drivers", []):
				drivers.append(driver)

			print("[Championship] Loaded state: %s, race %d/%d" % [current_tier, current_race_index, get_total_races()])
