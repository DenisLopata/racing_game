class_name DamageReport
extends RefCounted
## Tracks damage events during a race for post-race summary

# Health state before and after race
var pre_race_health: Dictionary = {}
var post_race_health: Dictionary = {}

# Damage events: [{time: float, part: String, amount: float, impact_speed: float}]
var damage_events: Array = []

# Summary statistics
var worst_impact_speed: float = 0.0
var worst_impact_part: String = ""
var total_damage_taken: float = 0.0
var total_repair_cost: int = 0

# Timing
var race_start_time: float = 0.0
var race_end_time: float = 0.0

# DNF info
var is_dnf: bool = false
var dnf_reason: String = ""

## Record a damage event
func record_event(part: String, amount: float, impact_speed: float) -> void:
	var event_time = Time.get_ticks_msec() / 1000.0 - race_start_time

	damage_events.append({
		"time": event_time,
		"part": part,
		"amount": amount,
		"impact_speed": impact_speed
	})

	total_damage_taken += amount

	# Track worst impact
	if impact_speed > worst_impact_speed:
		worst_impact_speed = impact_speed
		worst_impact_part = part

## Finalize the report at race end
func finalize(config: DamageConfig) -> void:
	race_end_time = Time.get_ticks_msec() / 1000.0

	# Calculate repair cost
	if config:
		total_repair_cost = config.get_total_repair_cost(post_race_health)

## Get damage delta for a specific part
func get_part_damage_delta(part: String) -> float:
	var pre = pre_race_health.get(part, 1.0)
	var post = post_race_health.get(part, 1.0)
	return pre - post

## Get total damage delta (sum of all part damage)
func get_total_damage_delta() -> float:
	var total: float = 0.0
	for part in post_race_health.keys():
		total += get_part_damage_delta(part)
	return total

## Get final damage as percentage (0.0 to 1.0)
## Calculates average damage across all parts
func get_final_damage_percent() -> float:
	if post_race_health.is_empty():
		return 0.0

	var total_damage: float = 0.0
	for part in post_race_health.keys():
		total_damage += (1.0 - post_race_health[part])

	return total_damage / post_race_health.size()

## Get number of damage events
func get_event_count() -> int:
	return damage_events.size()

## Get the most damaged part
func get_most_damaged_part() -> String:
	var worst_part: String = ""
	var worst_delta: float = 0.0

	for part in post_race_health.keys():
		var delta = get_part_damage_delta(part)
		if delta > worst_delta:
			worst_delta = delta
			worst_part = part

	return worst_part

## Get events for a specific part
func get_events_for_part(part: String) -> Array:
	var part_events: Array = []
	for event in damage_events:
		if event["part"] == part:
			part_events.append(event)
	return part_events

## Get a summary dictionary for display
func get_summary() -> Dictionary:
	return {
		"pre_race_health": pre_race_health.duplicate(),
		"post_race_health": post_race_health.duplicate(),
		"event_count": damage_events.size(),
		"worst_impact_speed": worst_impact_speed,
		"worst_impact_part": worst_impact_part,
		"total_damage_taken": total_damage_taken,
		"total_damage_delta": get_total_damage_delta(),
		"total_repair_cost": total_repair_cost,
		"most_damaged_part": get_most_damaged_part(),
		"race_duration": race_end_time - race_start_time,
		"is_dnf": is_dnf,
		"dnf_reason": dnf_reason
	}

## Get display-friendly part name
static func get_part_display_name(part: String) -> String:
	match part:
		"engines": return "Engine"
		"tires": return "Tires"
		"brakes": return "Brakes"
		"suspensions": return "Suspension"
		"spoilers": return "Spoiler"
		_: return part.capitalize()

## Format health as percentage string
static func format_health(health: float) -> String:
	return "%.0f%%" % (health * 100)

## Format time as mm:ss.ms
static func format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = fmod(seconds, 60.0)
	return "%d:%05.2f" % [mins, secs]
