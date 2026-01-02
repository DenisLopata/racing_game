extends Node
## ChallengeManager - Handles daily and weekly challenges with rewards
## Daily challenges refresh every 24 hours, weekly every 7 days

signal challenge_completed(challenge_id: String, challenge: Dictionary)
signal challenges_refreshed()

const SAVE_PATH: String = "user://challenges.json"
const DAILY_REFRESH_SECONDS: int = 86400  # 24 hours
const WEEKLY_REFRESH_SECONDS: int = 604800  # 7 days
const DAILY_CHALLENGE_COUNT: int = 3

# Challenge types and their templates
const CHALLENGE_TEMPLATES: Dictionary = {
	# Position-based challenges
	"finish_first": {
		"name": "Victory Lap",
		"description": "Win a race",
		"type": "position",
		"target": 1,
		"compare": "equal",
		"reward": 200,
		"difficulty": "easy"
	},
	"finish_podium": {
		"name": "Podium Finish",
		"description": "Finish in the top 3",
		"type": "position",
		"target": 3,
		"compare": "less_equal",
		"reward": 100,
		"difficulty": "easy"
	},
	"finish_top5": {
		"name": "Top Five",
		"description": "Finish in the top 5",
		"type": "position",
		"target": 5,
		"compare": "less_equal",
		"reward": 75,
		"difficulty": "easy"
	},

	# Damage-based challenges
	"no_damage": {
		"name": "Untouchable",
		"description": "Complete a race with no damage",
		"type": "damage",
		"target": 0.0,
		"compare": "equal",
		"reward": 300,
		"difficulty": "hard"
	},
	"low_damage": {
		"name": "Careful Driver",
		"description": "Finish a race with less than 20% damage",
		"type": "damage",
		"target": 0.2,
		"compare": "less",
		"reward": 150,
		"difficulty": "medium"
	},
	"survive_damage": {
		"name": "Battle Scars",
		"description": "Win a race with over 50% damage",
		"type": "damage_win",
		"target": 0.5,
		"compare": "greater",
		"reward": 250,
		"difficulty": "hard"
	},

	# Lap time challenges
	"fast_lap": {
		"name": "Speed Demon",
		"description": "Set a lap time under 60 seconds",
		"type": "lap_time",
		"target": 60.0,
		"compare": "less",
		"reward": 200,
		"difficulty": "medium"
	},
	"consistent_laps": {
		"name": "Consistency",
		"description": "Complete 3 laps within 5 seconds of each other",
		"type": "lap_consistency",
		"target": 5.0,
		"compare": "less",
		"reward": 175,
		"difficulty": "medium"
	},

	# Race count challenges
	"complete_races": {
		"name": "Dedication",
		"description": "Complete {target} races",
		"type": "race_count",
		"target": 3,
		"compare": "greater_equal",
		"reward": 150,
		"difficulty": "easy"
	},
	"win_races": {
		"name": "Champion",
		"description": "Win {target} races",
		"type": "win_count",
		"target": 2,
		"compare": "greater_equal",
		"reward": 300,
		"difficulty": "medium"
	},

	# Weekly challenges (harder)
	"weekly_wins": {
		"name": "Weekly Champion",
		"description": "Win 5 races this week",
		"type": "win_count",
		"target": 5,
		"compare": "greater_equal",
		"reward": 750,
		"difficulty": "weekly"
	},
	"weekly_races": {
		"name": "Marathon Runner",
		"description": "Complete 10 races this week",
		"type": "race_count",
		"target": 10,
		"compare": "greater_equal",
		"reward": 500,
		"difficulty": "weekly"
	},
	"weekly_podiums": {
		"name": "Podium Streak",
		"description": "Get 7 podium finishes this week",
		"type": "podium_count",
		"target": 7,
		"compare": "greater_equal",
		"reward": 600,
		"difficulty": "weekly"
	},
	"weekly_no_dnf": {
		"name": "Survivor",
		"description": "Complete 8 races without a DNF",
		"type": "consecutive_finishes",
		"target": 8,
		"compare": "greater_equal",
		"reward": 550,
		"difficulty": "weekly"
	}
}

# Daily challenge pool (easier challenges)
const DAILY_POOL: Array[String] = [
	"finish_first", "finish_podium", "finish_top5",
	"low_damage", "no_damage", "survive_damage",
	"fast_lap", "consistent_laps",
	"complete_races", "win_races"
]

# Weekly challenge pool (harder challenges)
const WEEKLY_POOL: Array[String] = [
	"weekly_wins", "weekly_races", "weekly_podiums", "weekly_no_dnf"
]

# Active challenges
var daily_challenges: Array[Dictionary] = []
var weekly_challenge: Dictionary = {}
var last_daily_refresh: int = 0
var last_weekly_refresh: int = 0

func _ready() -> void:
	load_challenges()
	_check_refresh()

func _check_refresh() -> void:
	var current_time: int = int(Time.get_unix_time_from_system())

	# Check daily refresh
	if current_time - last_daily_refresh >= DAILY_REFRESH_SECONDS or daily_challenges.is_empty():
		_generate_daily_challenges()
		last_daily_refresh = current_time
		save_challenges()
		challenges_refreshed.emit()

	# Check weekly refresh
	if current_time - last_weekly_refresh >= WEEKLY_REFRESH_SECONDS or weekly_challenge.is_empty():
		_generate_weekly_challenge()
		last_weekly_refresh = current_time
		save_challenges()
		challenges_refreshed.emit()

func _generate_daily_challenges() -> void:
	daily_challenges.clear()

	# Shuffle and pick unique challenges
	var available: Array = DAILY_POOL.duplicate()
	available.shuffle()

	for i in range(min(DAILY_CHALLENGE_COUNT, available.size())):
		var template_id: String = available[i]
		var template: Dictionary = CHALLENGE_TEMPLATES[template_id].duplicate(true)

		# Create unique challenge instance
		var challenge: Dictionary = {
			"id": "%s_%d" % [template_id, i],
			"template_id": template_id,
			"name": template.get("name", "Challenge"),
			"description": _format_description(template),
			"type": template.get("type", ""),
			"target": template.get("target", 0),
			"compare": template.get("compare", "equal"),
			"reward": template.get("reward", 100),
			"progress": 0,
			"completed": false,
			"claimed": false
		}
		daily_challenges.append(challenge)

	print("[ChallengeManager] Generated %d daily challenges" % daily_challenges.size())

func _generate_weekly_challenge() -> void:
	var available: Array = WEEKLY_POOL.duplicate()
	available.shuffle()

	var template_id: String = available[0]
	var template: Dictionary = CHALLENGE_TEMPLATES[template_id].duplicate(true)

	weekly_challenge = {
		"id": "weekly_%s" % template_id,
		"template_id": template_id,
		"name": template.get("name", "Weekly Challenge"),
		"description": _format_description(template),
		"type": template.get("type", ""),
		"target": template.get("target", 0),
		"compare": template.get("compare", "equal"),
		"reward": template.get("reward", 500),
		"progress": 0,
		"completed": false,
		"claimed": false
	}

	print("[ChallengeManager] Generated weekly challenge: %s" % weekly_challenge["name"])

func _format_description(template: Dictionary) -> String:
	var desc: String = template.get("description", "")
	var target = template.get("target", 0)
	return desc.replace("{target}", str(target))

# =============================================================================
# Challenge Progress Tracking
# =============================================================================

## Called after each race to update challenge progress
func on_race_completed(result: Dictionary) -> void:
	var position: int = result.get("position", 0)
	var is_dnf: bool = result.get("dnf", false)
	var damage_percent: float = result.get("damage_percent", 0.0)
	var best_lap: float = result.get("best_lap", 0.0)
	var lap_times: Array = result.get("lap_times", [])

	# Update daily challenges
	for challenge in daily_challenges:
		if challenge["completed"]:
			continue
		_update_challenge_progress(challenge, result)

	# Update weekly challenge
	if not weekly_challenge.is_empty() and not weekly_challenge["completed"]:
		_update_challenge_progress(weekly_challenge, result)

	save_challenges()

func _update_challenge_progress(challenge: Dictionary, result: Dictionary) -> void:
	var challenge_type: String = challenge.get("type", "")
	var target = challenge.get("target", 0)
	var compare: String = challenge.get("compare", "equal")

	var position: int = result.get("position", 0)
	var is_dnf: bool = result.get("dnf", false)
	var damage_percent: float = result.get("damage_percent", 0.0)
	var best_lap: float = result.get("best_lap", 0.0)
	var lap_times: Array = result.get("lap_times", [])

	match challenge_type:
		"position":
			if not is_dnf and _compare_value(position, target, compare):
				_complete_challenge(challenge)

		"damage":
			if not is_dnf and _compare_value(damage_percent, target, compare):
				_complete_challenge(challenge)

		"damage_win":
			if not is_dnf and position == 1 and _compare_value(damage_percent, target, compare):
				_complete_challenge(challenge)

		"lap_time":
			if not is_dnf and best_lap > 0 and _compare_value(best_lap, target, compare):
				_complete_challenge(challenge)

		"lap_consistency":
			if not is_dnf and lap_times.size() >= 3:
				var max_diff: float = _get_lap_time_spread(lap_times)
				if _compare_value(max_diff, target, compare):
					_complete_challenge(challenge)

		"race_count":
			challenge["progress"] = challenge.get("progress", 0) + 1
			if _compare_value(challenge["progress"], target, compare):
				_complete_challenge(challenge)

		"win_count":
			if not is_dnf and position == 1:
				challenge["progress"] = challenge.get("progress", 0) + 1
				if _compare_value(challenge["progress"], target, compare):
					_complete_challenge(challenge)

		"podium_count":
			if not is_dnf and position >= 1 and position <= 3:
				challenge["progress"] = challenge.get("progress", 0) + 1
				if _compare_value(challenge["progress"], target, compare):
					_complete_challenge(challenge)

		"consecutive_finishes":
			if is_dnf:
				challenge["progress"] = 0  # Reset on DNF
			else:
				challenge["progress"] = challenge.get("progress", 0) + 1
				if _compare_value(challenge["progress"], target, compare):
					_complete_challenge(challenge)

func _compare_value(value, target, compare: String) -> bool:
	match compare:
		"equal":
			return value == target
		"less":
			return value < target
		"less_equal":
			return value <= target
		"greater":
			return value > target
		"greater_equal":
			return value >= target
		_:
			return false

func _get_lap_time_spread(lap_times: Array) -> float:
	if lap_times.size() < 2:
		return 0.0

	var min_time: float = lap_times[0]
	var max_time: float = lap_times[0]

	for time in lap_times:
		min_time = min(min_time, time)
		max_time = max(max_time, time)

	return max_time - min_time

func _complete_challenge(challenge: Dictionary) -> void:
	if challenge["completed"]:
		return

	challenge["completed"] = true
	print("[ChallengeManager] Challenge completed: %s" % challenge["name"])
	challenge_completed.emit(challenge["id"], challenge)

# =============================================================================
# Reward Claiming
# =============================================================================

## Claim reward for a completed challenge
func claim_reward(challenge_id: String) -> int:
	# Check daily challenges
	for challenge in daily_challenges:
		if challenge["id"] == challenge_id:
			return _claim_challenge_reward(challenge)

	# Check weekly challenge
	if weekly_challenge.get("id", "") == challenge_id:
		return _claim_challenge_reward(weekly_challenge)

	return 0

func _claim_challenge_reward(challenge: Dictionary) -> int:
	if not challenge["completed"] or challenge["claimed"]:
		return 0

	challenge["claimed"] = true
	var reward: int = int(challenge.get("reward", 0))

	if PlayerProgress:
		PlayerProgress.add_currency(reward)

	save_challenges()
	print("[ChallengeManager] Claimed reward: %d for %s" % [reward, challenge["name"]])
	return reward

# =============================================================================
# Getters
# =============================================================================

## Get all daily challenges
func get_daily_challenges() -> Array[Dictionary]:
	return daily_challenges

## Get the weekly challenge
func get_weekly_challenge() -> Dictionary:
	return weekly_challenge

## Get time until daily refresh (seconds)
func get_daily_time_remaining() -> int:
	var current_time: int = int(Time.get_unix_time_from_system())
	var elapsed: int = current_time - last_daily_refresh
	return max(0, DAILY_REFRESH_SECONDS - elapsed)

## Get time until weekly refresh (seconds)
func get_weekly_time_remaining() -> int:
	var current_time: int = int(Time.get_unix_time_from_system())
	var elapsed: int = current_time - last_weekly_refresh
	return max(0, WEEKLY_REFRESH_SECONDS - elapsed)

## Check if any challenges are completed but unclaimed
func has_unclaimed_rewards() -> bool:
	for challenge in daily_challenges:
		if challenge["completed"] and not challenge["claimed"]:
			return true

	if not weekly_challenge.is_empty():
		if weekly_challenge["completed"] and not weekly_challenge["claimed"]:
			return true

	return false

## Get total unclaimed rewards
func get_unclaimed_reward_total() -> int:
	var total: int = 0

	for challenge in daily_challenges:
		if challenge["completed"] and not challenge["claimed"]:
			total += int(challenge.get("reward", 0))

	if not weekly_challenge.is_empty():
		if weekly_challenge["completed"] and not weekly_challenge["claimed"]:
			total += int(weekly_challenge.get("reward", 0))

	return total

# =============================================================================
# Save/Load
# =============================================================================

func save_challenges() -> void:
	var data: Dictionary = {
		"daily_challenges": daily_challenges,
		"weekly_challenge": weekly_challenge,
		"last_daily_refresh": last_daily_refresh,
		"last_weekly_refresh": last_weekly_refresh
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_challenges() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[ChallengeManager] No save file, generating new challenges")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()

		var data = JSON.parse_string(content)
		if data and data is Dictionary:
			# Load daily challenges
			var loaded_daily: Array = data.get("daily_challenges", [])
			daily_challenges.clear()
			for challenge in loaded_daily:
				daily_challenges.append(challenge)

			# Load weekly challenge
			weekly_challenge = data.get("weekly_challenge", {})

			# Load timestamps
			last_daily_refresh = int(data.get("last_daily_refresh", 0))
			last_weekly_refresh = int(data.get("last_weekly_refresh", 0))

			print("[ChallengeManager] Loaded %d daily challenges" % daily_challenges.size())
