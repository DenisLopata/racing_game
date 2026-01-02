class_name StatisticsScreen
extends CanvasLayer
## Displays career statistics

signal back_requested()

var panel: Panel
var back_button: Button

func _ready() -> void:
	_build_ui()
	_populate_stats()

func _build_ui() -> void:
	# Main panel
	panel = Panel.new()
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.05
	panel.anchor_bottom = 0.95
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	add_child(panel)

	# Main container
	var margin = MarginContainer.new()
	margin.anchor_left = 0.0
	margin.anchor_right = 1.0
	margin.anchor_top = 0.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "CAREER STATISTICS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Scroll container for stats
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_container.add_theme_constant_override("separation", 20)
	scroll.add_child(stats_container)

	# Back button
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(150, 40)
	back_button.pressed.connect(_on_back_pressed)
	vbox.add_child(back_button)

func _populate_stats() -> void:
	var container = panel.get_node("MarginContainer/VBoxContainer/ScrollContainer/StatsContainer")
	if not container:
		return

	# Clear existing
	for child in container.get_children():
		child.queue_free()

	# Get stats
	var stats = PlayerProgress.get_statistics_summary() if PlayerProgress else {}

	# Racing Statistics Section
	_add_section_header(container, "RACING STATISTICS")
	_add_stat_row(container, "Total Races", str(stats.get("total_races", 0)))
	_add_stat_row(container, "Wins", str(stats.get("wins", 0)), Color.GOLD)
	_add_stat_row(container, "Podiums (Top 3)", str(stats.get("podiums", 0)), Color.SILVER)
	_add_stat_row(container, "DNFs", str(stats.get("dnfs", 0)), Color.RED)
	_add_stat_row(container, "Win Rate", "%.1f%%" % stats.get("win_rate", 0.0))
	_add_stat_row(container, "Avg. Position", "%.1f" % stats.get("average_position", 0.0))

	# Financial Statistics
	_add_section_header(container, "FINANCIAL STATISTICS")
	_add_stat_row(container, "Current Balance", "$%d" % (PlayerProgress.currency if PlayerProgress else 0), Color.GREEN)
	_add_stat_row(container, "Total Earned", "$%d" % stats.get("total_currency_earned", 0))
	_add_stat_row(container, "Total Repairs", str(stats.get("total_repairs", 0)))
	_add_stat_row(container, "Repair Costs", "$%d" % stats.get("total_repair_cost", 0), Color.ORANGE)

	# Damage Statistics
	_add_section_header(container, "DAMAGE STATISTICS")
	_add_stat_row(container, "Total Damage Taken", "%.1f%%" % (stats.get("total_damage_taken", 0.0) * 100))

	# Track Statistics
	_add_section_header(container, "TRACK STATISTICS")
	var favorite = stats.get("favorite_track", "None")
	if favorite != "None":
		favorite = _format_track_name(favorite)
	_add_stat_row(container, "Favorite Track", favorite)

	# Best lap times
	var best_times: Dictionary = stats.get("best_lap_times", {})
	if best_times.size() > 0:
		_add_section_header(container, "BEST LAP TIMES")
		for track_id in best_times.keys():
			var time = best_times[track_id]
			_add_stat_row(container, _format_track_name(track_id), _format_time(time), Color.CYAN)

func _add_section_header(container: VBoxContainer, text: String) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	container.add_child(spacer)

	var header = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color.ORANGE)
	container.add_child(header)

	var line = HSeparator.new()
	container.add_child(line)

func _add_stat_row(container: VBoxContainer, label_text: String, value_text: String, value_color: Color = Color.WHITE) -> void:
	var row = HBoxContainer.new()

	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", value_color)
	row.add_child(value)

	container.add_child(row)

func _format_track_name(track_id: String) -> String:
	if track_id.begins_with("procedural_"):
		var seed_str = track_id.replace("procedural_", "")
		return "Procedural #" + seed_str
	return track_id.replace("_", " ").capitalize()

func _format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = fmod(seconds, 60.0)
	if mins > 0:
		return "%d:%05.2f" % [mins, secs]
	return "%.2fs" % seconds

func _on_back_pressed() -> void:
	back_requested.emit()
	queue_free()
