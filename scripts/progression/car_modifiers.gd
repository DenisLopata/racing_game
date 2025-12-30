class_name CarModifiers
extends RefCounted
## Calculates combined stat multipliers from equipped car parts
## All multipliers are strongly typed floats

## Physics multipliers
var acceleration_mult: float = 1.0
var max_speed_mult: float = 1.0
var brake_mult: float = 1.0
var rotation_mult: float = 1.0
var drag_mult: float = 1.0

## Grip/Drift multipliers
var grip_mult: float = 1.0
var drift_mult: float = 1.0
var friction_mult: float = 1.0
var lateral_grip_mult: float = 1.0

## Create modifiers from equipped parts
## equipped: Dictionary mapping PartData.Category -> part_id (String)
static func from_equipped(equipped: Dictionary) -> CarModifiers:
	var modifiers = CarModifiers.new()

	for category in PartData.get_all_categories():
		var cat_string := PartData.category_to_string(category)
		var part_id: String = equipped.get(cat_string, PartData.get_default_id(category))
		var part: PartData = _get_part_data(category, part_id)

		if part:
			modifiers._apply_part(part)

	return modifiers

## Apply a part's multipliers
func _apply_part(part: PartData) -> void:
	acceleration_mult *= part.acceleration_mult
	max_speed_mult *= part.max_speed_mult
	brake_mult *= part.brake_mult
	rotation_mult *= part.rotation_mult
	drag_mult *= part.drag_mult
	grip_mult *= part.grip_mult
	drift_mult *= part.drift_mult
	friction_mult *= part.friction_mult
	lateral_grip_mult *= part.lateral_grip_mult

## Get PartData from ConfigManager
static func _get_part_data(category: PartData.Category, part_id: String) -> PartData:
	var cat_string := PartData.category_to_string(category)
	var data: Dictionary = ConfigManager.get_part(cat_string, part_id)
	if data.is_empty():
		return null
	return PartData.from_dict(part_id, category, data)

## Create default modifiers (all 1.0)
static func defaults() -> CarModifiers:
	return CarModifiers.new()

## Get a summary string for debugging
func get_summary() -> String:
	return "CarModifiers: accel=%.2f speed=%.2f brake=%.2f rot=%.2f grip=%.2f drift=%.2f" % [
		acceleration_mult, max_speed_mult, brake_mult, rotation_mult, grip_mult, drift_mult
	]
