class_name PartData
extends Resource
## Strongly typed part data loaded from config

## Part category enum
enum Category {
	ENGINES,
	TIRES,
	SPOILERS,
	BRAKES,
	SUSPENSIONS
}

## Part tier enum
enum Tier {
	STOCK = 0,
	BASIC = 1,
	SPORT = 2,
	PRO = 3,
	RACING = 4
}

## Basic info
@export var id: String = ""
@export var category: Category = Category.ENGINES
@export var name: String = ""
@export var description: String = ""
@export var tier: Tier = Tier.STOCK
@export var price: int = 0
@export var unlock_wins: int = 0

## Stat multipliers
@export var acceleration_mult: float = 1.0
@export var max_speed_mult: float = 1.0
@export var brake_mult: float = 1.0
@export var rotation_mult: float = 1.0
@export var drag_mult: float = 1.0
@export var grip_mult: float = 1.0
@export var drift_mult: float = 1.0
@export var friction_mult: float = 1.0
@export var lateral_grip_mult: float = 1.0

## Create from dictionary (loaded from JSON)
static func from_dict(part_id: String, cat: Category, data: Dictionary) -> PartData:
	var part = PartData.new()
	part.id = part_id
	part.category = cat
	part.name = data.get("name", part_id.capitalize())
	part.description = data.get("description", "")
	part.tier = data.get("tier", 0) as Tier
	part.price = data.get("price", 0)
	part.unlock_wins = data.get("unlock_wins", 0)

	# Load multipliers
	part.acceleration_mult = data.get("acceleration_mult", 1.0)
	part.max_speed_mult = data.get("max_speed_mult", 1.0)
	part.brake_mult = data.get("brake_mult", 1.0)
	part.rotation_mult = data.get("rotation_mult", 1.0)
	part.drag_mult = data.get("drag_mult", 1.0)
	part.grip_mult = data.get("grip_mult", 1.0)
	part.drift_mult = data.get("drift_mult", 1.0)
	part.friction_mult = data.get("friction_mult", 1.0)
	part.lateral_grip_mult = data.get("lateral_grip_mult", 1.0)

	return part

## Get category string for config lookup
static func category_to_string(cat: Category) -> String:
	match cat:
		Category.ENGINES: return "engines"
		Category.TIRES: return "tires"
		Category.SPOILERS: return "spoilers"
		Category.BRAKES: return "brakes"
		Category.SUSPENSIONS: return "suspensions"
	return "engines"

## Get category from string
static func string_to_category(s: String) -> Category:
	match s.to_lower():
		"engines": return Category.ENGINES
		"tires": return Category.TIRES
		"spoilers": return Category.SPOILERS
		"brakes": return Category.BRAKES
		"suspensions": return Category.SUSPENSIONS
	return Category.ENGINES

## Get default part ID for a category
static func get_default_id(cat: Category) -> String:
	if cat == Category.SPOILERS:
		return "none"
	return "stock"

## Get all categories
static func get_all_categories() -> Array[Category]:
	return [Category.ENGINES, Category.TIRES, Category.SPOILERS, Category.BRAKES, Category.SUSPENSIONS]
