class_name ResultsScreen
extends CanvasLayer
## Displays race results when the race ends

@onready var results_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ResultsContainer
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var save_track_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/SaveTrackButton
@onready var restart_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/RestartButton
@onready var quit_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/QuitButton

signal restart_requested()
signal quit_requested()

var track_saved: bool = false
var damage_report_container: VBoxContainer = null

func _ready() -> void:
	hide()
	save_track_button.pressed.connect(_on_save_track_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func show_results(results: Array, player_car: Car) -> void:
	# Clear previous results
	for child in results_container.get_children():
		child.queue_free()

	# Reset save state
	track_saved = false

	# Show save button only for procedural tracks
	if GameSettings.is_procedural_track:
		save_track_button.visible = true
		save_track_button.text = "Save Track"
		save_track_button.disabled = false
	else:
		save_track_button.visible = false

	# Find player result
	var player_position = 1
	var player_result: Dictionary = {}
	for result in results:
		if result["car"] == player_car:
			player_position = result["position"]
			player_result = result
			break

	# Check for DNF
	var player_dnf = player_result.get("dnf", false)

	# Set title based on position or DNF
	if player_dnf:
		title_label.text = "DNF - " + player_result.get("dnf_reason", "Car Totaled")
		title_label.add_theme_color_override("font_color", Color.RED)
	else:
		match player_position:
			1:
				title_label.text = "YOU WON!"
				title_label.add_theme_color_override("font_color", Color.GOLD)
			2:
				title_label.text = "2nd Place!"
				title_label.add_theme_color_override("font_color", Color.SILVER)
			3:
				title_label.text = "3rd Place!"
				title_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
			_:
				title_label.text = "Race Complete"
				title_label.add_theme_color_override("font_color", Color.WHITE)

	# Add result entries
	for result in results:
		var entry = _create_result_entry(result, player_car)
		results_container.add_child(entry)

	# Add damage report for player
	if player_result.has("damage_report") and player_result["damage_report"] != null:
		_add_damage_report_section(player_result["damage_report"])

	show()

func _create_result_entry(result: Dictionary, player_car: Car) -> HBoxContainer:
	var entry = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 20)

	var is_dnf = result.get("dnf", false)

	# Position
	var pos_label = Label.new()
	if is_dnf:
		pos_label.text = "DNF"
		pos_label.add_theme_color_override("font_color", Color.RED)
	else:
		pos_label.text = "P%d" % result["position"]
		match result["position"]:
			1:
				pos_label.add_theme_color_override("font_color", Color.GOLD)
			2:
				pos_label.add_theme_color_override("font_color", Color.SILVER)
			3:
				pos_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
	pos_label.custom_minimum_size = Vector2(50, 0)
	entry.add_child(pos_label)

	# Name
	var name_label = Label.new()
	var car_name = "YOU" if result["car"] == player_car else result["car"].name
	name_label.text = car_name
	name_label.custom_minimum_size = Vector2(100, 0)
	if result["car"] == player_car:
		name_label.add_theme_color_override("font_color", Color.YELLOW)
	elif is_dnf:
		name_label.add_theme_color_override("font_color", Color.GRAY)
	entry.add_child(name_label)

	# Time or DNF reason
	var time_label = Label.new()
	if is_dnf:
		time_label.text = result.get("dnf_reason", "Totaled")
		time_label.add_theme_color_override("font_color", Color.GRAY)
	else:
		time_label.text = "%.2fs" % result["total_time"]
	time_label.custom_minimum_size = Vector2(120, 0)
	entry.add_child(time_label)

	# Best Lap (only if completed at least one lap)
	var best_lap_label = Label.new()
	if result["best_lap"] > 0:
		best_lap_label.text = "Best: %.2fs" % result["best_lap"]
	else:
		best_lap_label.text = ""
	if is_dnf:
		best_lap_label.add_theme_color_override("font_color", Color.GRAY)
	entry.add_child(best_lap_label)

	return entry

func _on_restart_pressed() -> void:
	restart_requested.emit()
	hide()

func _on_quit_pressed() -> void:
	quit_requested.emit()

func _on_save_track_pressed() -> void:
	if track_saved:
		return

	# Generate a name based on seed
	var track_name = "Track_%d" % GameSettings.procedural_seed
	GameSettings.save_favorite_track(track_name)

	# Update button to show saved
	track_saved = true
	save_track_button.text = "Saved!"
	save_track_button.disabled = true

func _add_damage_report_section(report: DamageReport) -> void:
	# Clear previous damage report if any
	if damage_report_container:
		damage_report_container.queue_free()

	damage_report_container = VBoxContainer.new()
	damage_report_container.add_theme_constant_override("separation", 8)

	# Separator
	var separator = HSeparator.new()
	damage_report_container.add_child(separator)

	# Header
	var header = Label.new()
	header.text = "DAMAGE REPORT"
	header.add_theme_color_override("font_color", Color.ORANGE)
	damage_report_container.add_child(header)

	var summary = report.get_summary()

	# Part health comparison
	var parts = ["engines", "tires", "brakes", "suspensions", "spoilers"]
	for part in parts:
		var pre_health = summary["pre_race_health"].get(part, 1.0)
		var post_health = summary["post_race_health"].get(part, 1.0)
		var damage_delta = pre_health - post_health

		# Only show parts that took damage
		if damage_delta > 0.01:
			var part_row = _create_damage_row(part, pre_health, post_health)
			damage_report_container.add_child(part_row)

	# Summary stats
	var stats_row = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 30)

	# Collision count
	var collisions_label = Label.new()
	collisions_label.text = "Impacts: %d" % summary["event_count"]
	stats_row.add_child(collisions_label)

	# Worst impact
	if summary["worst_impact_speed"] > 0:
		var worst_label = Label.new()
		worst_label.text = "Worst: %.0f km/h" % (summary["worst_impact_speed"] * 0.1)
		stats_row.add_child(worst_label)

	damage_report_container.add_child(stats_row)

	# Repair cost
	if summary["total_repair_cost"] > 0:
		var cost_label = Label.new()
		cost_label.text = "Repair Cost: $%d" % summary["total_repair_cost"]
		cost_label.add_theme_color_override("font_color", Color.YELLOW)
		damage_report_container.add_child(cost_label)

	results_container.add_child(damage_report_container)

func _create_damage_row(part: String, pre_health: float, post_health: float) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Part name
	var name_label = Label.new()
	name_label.text = DamageReport.get_part_display_name(part)
	name_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(name_label)

	# Before health
	var before_label = Label.new()
	before_label.text = DamageReport.format_health(pre_health)
	before_label.custom_minimum_size = Vector2(50, 0)
	before_label.add_theme_color_override("font_color", _get_health_color(pre_health))
	row.add_child(before_label)

	# Arrow
	var arrow_label = Label.new()
	arrow_label.text = "->"
	row.add_child(arrow_label)

	# After health
	var after_label = Label.new()
	after_label.text = DamageReport.format_health(post_health)
	after_label.custom_minimum_size = Vector2(50, 0)
	after_label.add_theme_color_override("font_color", _get_health_color(post_health))
	row.add_child(after_label)

	# Damage amount
	var damage = pre_health - post_health
	var damage_label = Label.new()
	damage_label.text = "(-%s)" % DamageReport.format_health(damage)
	damage_label.add_theme_color_override("font_color", Color.RED)
	row.add_child(damage_label)

	return row

func _get_health_color(health: float) -> Color:
	if health > 0.7:
		return Color.GREEN
	elif health > 0.3:
		return Color.YELLOW
	else:
		return Color.RED
