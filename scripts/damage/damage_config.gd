class_name DamageConfig
extends RefCounted
## Configuration for the car damage system

# Impact speed thresholds (pixels/second)
var min_damage_speed: float = 100.0      # Below this, no damage
var severe_damage_speed: float = 300.0   # Above this, major damage

# Damage multipliers by collision type
var collision_multipliers: Dictionary = {
	"car": 1.0,
	"wall": 1.5,
	"scrape": 0.2
}

# Part durability (number of max-speed hits to destroy)
var part_durability: Dictionary = {
	"engines": 5,
	"tires": 3,
	"brakes": 4,
	"suspensions": 4,
	"spoilers": 6
}

# Repair costs per part (base cost at 100% damage)
var repair_costs: Dictionary = {
	"engines": 500,
	"tires": 200,
	"brakes": 300,
	"suspensions": 350,
	"spoilers": 150
}

# Part failure effects (multipliers when part is at 0% health)
var failure_effects: Dictionary = {
	"engines": {"acceleration": 0.1, "max_speed": 0.5},
	"tires": {"grip": 0.1, "drift": 3.0, "lateral_grip": 0.1},
	"brakes": {"brake": 0.05},
	"suspensions": {"rotation": 0.2, "lateral_grip": 0.3},
	"spoilers": {"drag": 2.0}
}

## Load configuration from damage.json
static func load_from_config() -> DamageConfig:
	var config = DamageConfig.new()

	var file = FileAccess.open("res://config/damage.json", FileAccess.READ)
	if not file:
		push_warning("[DamageConfig] Could not load damage.json, using defaults")
		return config

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.parse_string(json_text)
	if json == null:
		push_warning("[DamageConfig] Failed to parse damage.json, using defaults")
		return config

	# Load thresholds
	if json.has("thresholds"):
		var t = json["thresholds"]
		config.min_damage_speed = t.get("min_damage_speed", config.min_damage_speed)
		config.severe_damage_speed = t.get("severe_damage_speed", config.severe_damage_speed)

	# Load collision multipliers
	if json.has("collision_multipliers"):
		config.collision_multipliers = json["collision_multipliers"]

	# Load part durability
	if json.has("part_durability"):
		config.part_durability = json["part_durability"]

	# Load repair costs
	if json.has("repair_costs"):
		config.repair_costs = json["repair_costs"]

	# Load failure effects
	if json.has("failure_effects"):
		config.failure_effects = json["failure_effects"]

	return config

## Calculate damage amount based on impact speed and part durability
func calculate_damage(impact_speed: float, part: String, collision_type: String) -> float:
	if impact_speed < min_damage_speed:
		return 0.0

	# Normalize speed to 0-1 range (min_damage_speed to severe_damage_speed)
	var speed_factor = clampf(
		(impact_speed - min_damage_speed) / (severe_damage_speed - min_damage_speed),
		0.0, 1.5  # Allow up to 150% for very high speed impacts
	)

	# Get collision type multiplier
	var type_mult = collision_multipliers.get(collision_type, 1.0)

	# Get part durability (hits to destroy)
	var durability = part_durability.get(part, 5)

	# Calculate damage as fraction of total health
	# At max speed (factor=1.0), one hit does 1/durability damage
	var base_damage = 1.0 / durability
	var damage = base_damage * speed_factor * type_mult

	return damage

## Get repair cost for a part based on current damage
func get_repair_cost(part: String, damage_percent: float) -> int:
	var base_cost = repair_costs.get(part, 100)
	return int(base_cost * damage_percent)

## Get total repair cost for all parts
func get_total_repair_cost(damage_state: Dictionary) -> int:
	var total = 0
	for part in damage_state:
		var damage_percent = 1.0 - damage_state[part]
		if damage_percent > 0:
			total += get_repair_cost(part, damage_percent)
	return total
