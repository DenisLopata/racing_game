class_name AIDifficulty
extends Resource
## Resource that defines AI difficulty settings

@export var difficulty_name: String = "Medium"

## Speed factors
@export_range(0.5, 1.0) var max_speed_percent: float = 0.85
@export_range(0.5, 1.0) var acceleration_factor: float = 0.9
@export_range(0.5, 1.0) var brake_factor: float = 0.85

## Path following
@export_range(0.2, 0.5) var lookahead_factor: float = 0.3
@export_range(0.5, 1.0) var path_adherence: float = 0.9
@export_range(0.0, 0.3) var reaction_delay: float = 0.1

## Mistakes
@export_range(0.0, 0.1) var mistake_chance: float = 0.02
@export_range(0.1, 0.5) var mistake_severity: float = 0.3
@export_range(0.1, 0.5) var mistake_duration: float = 0.2

## Corner handling
@export_range(50.0, 200.0) var corner_brake_distance: float = 100.0

## Apply this difficulty to an AI controller
func apply_to_controller(controller: AIController) -> void:
	controller.max_speed_percent = max_speed_percent
	controller.lookahead_factor = lookahead_factor
	controller.path_adherence = path_adherence
	controller.reaction_delay = reaction_delay
	controller.mistake_chance = mistake_chance
	controller.corner_brake_distance = corner_brake_distance

## Create preset difficulties
static func create_easy() -> AIDifficulty:
	var diff = AIDifficulty.new()
	diff.difficulty_name = "Easy"
	diff.max_speed_percent = 0.70
	diff.lookahead_factor = 0.25
	diff.path_adherence = 0.7
	diff.reaction_delay = 0.2
	diff.mistake_chance = 0.05
	diff.corner_brake_distance = 150.0
	return diff

static func create_medium() -> AIDifficulty:
	var diff = AIDifficulty.new()
	diff.difficulty_name = "Medium"
	diff.max_speed_percent = 0.85
	diff.lookahead_factor = 0.3
	diff.path_adherence = 0.85
	diff.reaction_delay = 0.1
	diff.mistake_chance = 0.02
	diff.corner_brake_distance = 100.0
	return diff

static func create_hard() -> AIDifficulty:
	var diff = AIDifficulty.new()
	diff.difficulty_name = "Hard"
	diff.max_speed_percent = 0.95
	diff.lookahead_factor = 0.35
	diff.path_adherence = 0.95
	diff.reaction_delay = 0.05
	diff.mistake_chance = 0.005
	diff.corner_brake_distance = 80.0
	return diff

static func create_expert() -> AIDifficulty:
	var diff = AIDifficulty.new()
	diff.difficulty_name = "Expert"
	diff.max_speed_percent = 1.0
	diff.lookahead_factor = 0.4
	diff.path_adherence = 1.0
	diff.reaction_delay = 0.02
	diff.mistake_chance = 0.0
	diff.corner_brake_distance = 60.0
	return diff
