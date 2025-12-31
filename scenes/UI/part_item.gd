extends PanelContainer
## PartItem - Reusable component for displaying a single part in the garage

signal buy_pressed(category: PartData.Category, part_id: String)
signal equip_pressed(category: PartData.Category, part_id: String)

enum State { LOCKED, UNLOCKED, OWNED, EQUIPPED }

var part_id: String
var category: PartData.Category
var current_state: State = State.LOCKED

@onready var tier_label: Label = $HBoxContainer/TierLabel
@onready var name_label: Label = $HBoxContainer/InfoContainer/NameLabel
@onready var stats_label: Label = $HBoxContainer/InfoContainer/StatsLabel
@onready var requirement_label: Label = $HBoxContainer/RequirementLabel
@onready var action_button: Button = $HBoxContainer/ActionButton

const COLOR_LOCKED := Color(0.5, 0.5, 0.5, 1)
const COLOR_NORMAL := Color(1, 1, 1, 1)
const COLOR_EQUIPPED := Color(0.4, 1, 0.4, 1)

func _ready() -> void:
	action_button.pressed.connect(_on_action_button_pressed)

## Setup the part item with data
func setup(p_category: PartData.Category, p_part_id: String, part_data: Dictionary) -> void:
	part_id = p_part_id
	category = p_category

	# Set tier stars
	var tier: int = int(part_data.get("tier", 0))
	tier_label.text = _get_tier_stars(tier)

	# Set name
	name_label.text = part_data.get("name", part_id.capitalize())

	# Set stats based on category
	stats_label.text = _get_stats_text(category, part_data)

	# Determine state
	var is_unlocked := PlayerProgress.is_unlocked(category, part_id)
	var is_owned := PlayerProgress.is_owned(category, part_id)
	var is_equipped := PlayerProgress.get_equipped(category) == part_id

	if is_equipped:
		current_state = State.EQUIPPED
	elif is_owned:
		current_state = State.OWNED
	elif is_unlocked:
		current_state = State.UNLOCKED
	else:
		current_state = State.LOCKED

	# Apply visual state
	_apply_state(part_data)

## Get tier stars string
func _get_tier_stars(tier: int) -> String:
	var star := "*"
	return star.repeat(tier + 1)

## Get stats text based on category
func _get_stats_text(cat: PartData.Category, data: Dictionary) -> String:
	match cat:
		PartData.Category.ENGINES:
			return "Accel: %.2fx  Speed: %.2fx" % [
				data.get("acceleration_mult", 1.0),
				data.get("max_speed_mult", 1.0)
			]
		PartData.Category.TIRES:
			return "Grip: %.2fx  Drift: %.2fx" % [
				data.get("grip_mult", 1.0),
				data.get("drift_mult", 1.0)
			]
		PartData.Category.SPOILERS:
			return "Drag: %.2fx  Handling: %.2fx" % [
				data.get("drag_mult", 1.0),
				data.get("rotation_mult", 1.0)
			]
		PartData.Category.BRAKES:
			return "Brake: %.2fx" % data.get("brake_mult", 1.0)
		PartData.Category.SUSPENSIONS:
			return "Handling: %.2fx  Stability: %.2fx" % [
				data.get("rotation_mult", 1.0),
				data.get("lateral_grip_mult", 1.0)
			]
	return ""

## Apply visual state to the item
func _apply_state(part_data: Dictionary) -> void:
	var price: int = int(part_data.get("price", 0))
	var unlock_wins: int = int(part_data.get("unlock_wins", 0))

	match current_state:
		State.LOCKED:
			tier_label.modulate = COLOR_LOCKED
			name_label.modulate = COLOR_LOCKED
			stats_label.modulate = COLOR_LOCKED
			requirement_label.text = "Wins: %d" % unlock_wins
			requirement_label.modulate = COLOR_LOCKED
			action_button.text = "LOCKED"
			action_button.disabled = true

		State.UNLOCKED:
			tier_label.modulate = COLOR_NORMAL
			name_label.modulate = COLOR_NORMAL
			stats_label.modulate = Color(0.7, 0.7, 0.7, 1)
			requirement_label.text = "%d" % price if price > 0 else ""
			requirement_label.modulate = Color(1, 0.85, 0.3, 1)  # Gold color
			action_button.text = "BUY"
			action_button.disabled = not PlayerProgress.can_afford(price)

		State.OWNED:
			tier_label.modulate = COLOR_NORMAL
			name_label.modulate = COLOR_NORMAL
			stats_label.modulate = Color(0.7, 0.7, 0.7, 1)
			requirement_label.text = "OWNED"
			requirement_label.modulate = Color(0.7, 0.7, 0.7, 1)
			action_button.text = "EQUIP"
			action_button.disabled = false

		State.EQUIPPED:
			tier_label.modulate = COLOR_EQUIPPED
			name_label.modulate = COLOR_EQUIPPED
			stats_label.modulate = Color(0.7, 1, 0.7, 1)
			requirement_label.text = ""
			action_button.text = "EQUIPPED"
			action_button.disabled = true

## Handle action button press
func _on_action_button_pressed() -> void:
	match current_state:
		State.UNLOCKED:
			buy_pressed.emit(category, part_id)
		State.OWNED:
			equip_pressed.emit(category, part_id)
