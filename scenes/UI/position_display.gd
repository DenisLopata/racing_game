class_name PositionDisplay
extends Control
## Displays the player's current race position (P1, P2, etc.)

@onready var position_label: Label = $PositionLabel
@onready var total_label: Label = $TotalLabel

var current_position: int = 1
var total_cars: int = 1

func _ready() -> void:
	# Update display periodically
	var timer = Timer.new()
	timer.wait_time = 0.1  # Update 10 times per second
	timer.autostart = true
	timer.timeout.connect(_update_position)
	add_child(timer)

func _update_position() -> void:
	if not RaceManager.is_racing():
		return

	# Get total cars
	total_cars = RaceManager.registered_cars.size()

	# This would need the player car reference to get their position
	# For now, we'll set it from outside
	_refresh_display()

func set_position(pos: int, total: int = -1) -> void:
	current_position = pos
	if total > 0:
		total_cars = total
	_refresh_display()

func _refresh_display() -> void:
	if position_label:
		position_label.text = "P%d" % current_position

		# Color based on position
		match current_position:
			1:
				position_label.add_theme_color_override("font_color", Color.GOLD)
			2:
				position_label.add_theme_color_override("font_color", Color.SILVER)
			3:
				position_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))  # Bronze
			_:
				position_label.add_theme_color_override("font_color", Color.WHITE)

	if total_label:
		total_label.text = "/%d" % total_cars
