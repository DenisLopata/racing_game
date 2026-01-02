class_name ChampionshipMenu
extends CanvasLayer
## Championship selection and standings menu

signal back_requested()
signal start_race_requested(track_id: String, ai_difficulty: String)

var championship: ChampionshipManager = null
var panel: Panel
var tier_buttons: Dictionary = {}
var current_view: String = "select"  # "select", "standings", "active"

func _ready() -> void:
	championship = ChampionshipManager.new()
	_build_ui()
	_update_view()

func _build_ui() -> void:
	# Main panel
	panel = Panel.new()
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 0.05
	panel.anchor_bottom = 0.95
	add_child(panel)

	# Main margin container
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.anchor_left = 0.0
	margin.anchor_right = 1.0
	margin.anchor_top = 0.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)

	# Header
	var header = Label.new()
	header.name = "Header"
	header.text = "CHAMPIONSHIP"
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color.GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(header)

	# Content area (changes based on view)
	var content = VBoxContainer.new()
	content.name = "ContentArea"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(150, 40)
	back_btn.pressed.connect(_on_back_pressed)
	main_vbox.add_child(back_btn)

func _update_view() -> void:
	var content = panel.get_node("MarginContainer/MainVBox/ContentArea")
	var header = panel.get_node("MarginContainer/MainVBox/Header")

	# Clear content
	for child in content.get_children():
		child.queue_free()

	if championship.is_championship_active():
		current_view = "active"
		header.text = "CHAMPIONSHIP - %s" % championship._get_championship_info()["name"]
		_build_active_view(content)
	else:
		current_view = "select"
		header.text = "SELECT CHAMPIONSHIP"
		_build_select_view(content)

func _build_select_view(container: VBoxContainer) -> void:
	var tiers = championship.get_all_tiers()

	# Scrollable tier list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(scroll)

	var tier_container = VBoxContainer.new()
	tier_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_container.add_theme_constant_override("separation", 10)
	scroll.add_child(tier_container)

	for tier_data in tiers:
		var tier_card = _create_tier_card(tier_data)
		tier_container.add_child(tier_card)

func _create_tier_card(tier_data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	# Tier info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = tier_data.get("name", "Championship")
	name_label.add_theme_font_size_override("font_size", 18)
	if not tier_data.get("unlocked", false):
		name_label.add_theme_color_override("font_color", Color.DIM_GRAY)
	info_vbox.add_child(name_label)

	var details_label = Label.new()
	details_label.text = "%d Races | %s Difficulty | %.1fx Rewards" % [
		tier_data.get("races", 5),
		tier_data.get("ai_difficulty", "medium").capitalize(),
		tier_data.get("reward_multiplier", 1.0)
	]
	details_label.add_theme_font_size_override("font_size", 12)
	details_label.add_theme_color_override("font_color", Color.LIGHT_GRAY if tier_data.get("unlocked", false) else Color.DIM_GRAY)
	info_vbox.add_child(details_label)

	# Start button
	var start_btn = Button.new()
	start_btn.text = "START" if tier_data.get("unlocked", false) else "LOCKED"
	start_btn.custom_minimum_size = Vector2(100, 40)
	start_btn.disabled = not tier_data.get("unlocked", false)
	start_btn.pressed.connect(_on_tier_selected.bind(tier_data.get("id", "")))
	hbox.add_child(start_btn)

	return card

func _build_active_view(container: VBoxContainer) -> void:
	var info = championship._get_championship_info()

	# Progress info
	var progress_label = Label.new()
	progress_label.text = championship.get_progress_string()
	progress_label.add_theme_font_size_override("font_size", 16)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(progress_label)

	# Next track info
	var track_label = Label.new()
	var track_id = championship.get_current_track()
	var track_data = ConfigManager.get_track(track_id)
	track_label.text = "Next Race: %s" % track_data.get("name", track_id)
	track_label.add_theme_font_size_override("font_size", 14)
	track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(track_label)

	# Separator
	var sep = HSeparator.new()
	container.add_child(sep)

	# Standings header
	var standings_header = Label.new()
	standings_header.text = "STANDINGS"
	standings_header.add_theme_font_size_override("font_size", 16)
	standings_header.add_theme_color_override("font_color", Color.GOLD)
	container.add_child(standings_header)

	# Standings scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var standings_vbox = VBoxContainer.new()
	standings_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(standings_vbox)

	# Add standings rows
	var standings = championship.get_standings_array()
	for data in standings:
		var row = _create_standings_row(data)
		standings_vbox.add_child(row)

	# Action buttons
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 20)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(buttons_hbox)

	var race_btn = Button.new()
	race_btn.text = "START RACE"
	race_btn.custom_minimum_size = Vector2(150, 45)
	race_btn.pressed.connect(_on_start_race_pressed)
	buttons_hbox.add_child(race_btn)

	var abandon_btn = Button.new()
	abandon_btn.text = "Abandon"
	abandon_btn.custom_minimum_size = Vector2(100, 45)
	abandon_btn.pressed.connect(_on_abandon_pressed)
	buttons_hbox.add_child(abandon_btn)

func _create_standings_row(data: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)

	# Position
	var pos_label = Label.new()
	pos_label.text = "P%d" % data.get("position", 0)
	pos_label.custom_minimum_size = Vector2(40, 0)
	pos_label.add_theme_font_size_override("font_size", 14)
	if data.get("is_player", false):
		pos_label.add_theme_color_override("font_color", Color.GREEN)
	row.add_child(pos_label)

	# Driver name
	var name_label = Label.new()
	name_label.text = data.get("driver", "Unknown")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	if data.get("is_player", false):
		name_label.add_theme_color_override("font_color", Color.GREEN)
	row.add_child(name_label)

	# Points
	var points_label = Label.new()
	points_label.text = "%d pts" % data.get("points", 0)
	points_label.custom_minimum_size = Vector2(60, 0)
	points_label.add_theme_font_size_override("font_size", 14)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(points_label)

	# Wins
	var wins_label = Label.new()
	wins_label.text = "%d W" % data.get("wins", 0)
	wins_label.custom_minimum_size = Vector2(40, 0)
	wins_label.add_theme_font_size_override("font_size", 12)
	wins_label.add_theme_color_override("font_color", Color.GOLD)
	row.add_child(wins_label)

	return row

func _on_tier_selected(tier_id: String) -> void:
	if championship.start_championship(tier_id):
		_update_view()

func _on_start_race_pressed() -> void:
	var info = championship._get_championship_info()
	var track_id = championship.get_current_track()
	var ai_difficulty = info.get("ai_difficulty", "medium")

	# Configure game settings for championship race
	GameSettings.selected_track = track_id
	GameSettings.ai_difficulty = ai_difficulty
	GameSettings.is_time_attack = false

	start_race_requested.emit(track_id, ai_difficulty)

func _on_abandon_pressed() -> void:
	championship.abandon_championship()
	_update_view()

func _on_back_pressed() -> void:
	back_requested.emit()
	queue_free()

## Call this after a race completes to update championship state
func on_race_completed(results: Array) -> void:
	if championship.is_championship_active():
		championship.record_race_result(results)
		_update_view()

## Get the championship manager instance
func get_championship_manager() -> ChampionshipManager:
	return championship
