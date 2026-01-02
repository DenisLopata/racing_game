class_name CarDamageState
extends RefCounted
## Tracks damage state for a single car

# Health per part (1.0 = full health, 0.0 = destroyed)
var part_health: Dictionary = {
	"engines": 1.0,
	"tires": 1.0,
	"brakes": 1.0,
	"suspensions": 1.0,
	"spoilers": 1.0
}

# Reference to config for failure effects
var _config: DamageConfig

func _init(config: DamageConfig = null) -> void:
	if config:
		_config = config
	else:
		_config = DamageConfig.load_from_config()

## Apply damage to a specific part
func apply_damage(part: String, amount: float) -> void:
	if not part_health.has(part):
		push_warning("[CarDamageState] Unknown part: %s" % part)
		return

	part_health[part] = maxf(0.0, part_health[part] - amount)

## Get effectiveness multiplier for a part based on its health
## Returns value between failure_effect and 1.0
func get_effectiveness(part: String, stat: String = "") -> float:
	if not part_health.has(part):
		return 1.0

	var health = part_health[part]

	# If part is completely failed, return failure effect
	if health <= 0.0:
		return _get_failure_effect(part, stat)

	# Linear interpolation from failure effect to 1.0 based on health
	var failure_mult = _get_failure_effect(part, stat)
	return lerpf(failure_mult, 1.0, health)

## Get the failure effect multiplier for a part
func _get_failure_effect(part: String, stat: String) -> float:
	if not _config.failure_effects.has(part):
		return 0.1  # Default severe penalty

	var effects = _config.failure_effects[part]

	# If no specific stat requested, return the worst effect
	if stat.is_empty():
		var worst = 1.0
		for key in effects:
			if effects[key] < worst:
				worst = effects[key]
		return worst

	# Return specific stat effect or default
	return effects.get(stat, 0.5)

## Check if a part has completely failed
func is_part_failed(part: String) -> bool:
	if not part_health.has(part):
		return false
	return part_health[part] <= 0.0

## Get health of a specific part
func get_part_health(part: String) -> float:
	return part_health.get(part, 1.0)

## Set health of a specific part (for gradual repairs)
func set_part_health(part: String, health: float) -> void:
	if part_health.has(part):
		part_health[part] = clampf(health, 0.0, 1.0)

## Repair a single part to full health
func repair_part(part: String) -> void:
	if part_health.has(part):
		part_health[part] = 1.0

## Repair all parts to full health
func repair_all() -> void:
	for part in part_health:
		part_health[part] = 1.0

## Check if any part is damaged
func has_damage() -> bool:
	for part in part_health:
		if part_health[part] < 1.0:
			return true
	return false

## Check if any part has failed
func has_failed_parts() -> bool:
	for part in part_health:
		if part_health[part] <= 0.0:
			return true
	return false

## Get total damage percentage (0.0 = no damage, 1.0 = all parts destroyed)
func get_total_damage_percent() -> float:
	var total_damage = 0.0
	for part in part_health:
		total_damage += (1.0 - part_health[part])
	return total_damage / part_health.size()

## Get list of damaged parts (health < 1.0)
func get_damaged_parts() -> Array[String]:
	var damaged: Array[String] = []
	for part in part_health:
		if part_health[part] < 1.0:
			damaged.append(part)
	return damaged

## Get list of failed parts (health = 0.0)
func get_failed_parts() -> Array[String]:
	var failed: Array[String] = []
	for part in part_health:
		if part_health[part] <= 0.0:
			failed.append(part)
	return failed

## Serialize to dictionary for saving
func to_dict() -> Dictionary:
	return part_health.duplicate()

## Create from saved dictionary
static func from_dict(data: Dictionary, config: DamageConfig = null) -> CarDamageState:
	var state = CarDamageState.new(config)
	for part in data:
		if state.part_health.has(part):
			state.part_health[part] = clampf(float(data[part]), 0.0, 1.0)
	return state

## Create a copy of this damage state
func duplicate_state() -> CarDamageState:
	return CarDamageState.from_dict(part_health, _config)
