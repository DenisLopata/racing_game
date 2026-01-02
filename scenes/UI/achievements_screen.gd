class_name AchievementsScreen
extends CanvasLayer
## Displays all achievements and their unlock status

signal back_requested()

var panel: Panel
var back_button: Button
var category_buttons: Dictionary = {}
var current_category: String = "all"

const CATEGORIES = ["all", "racing", "skill", "damage", "progression"]

func _ready() -> void:
	_build_ui()
	_populate_achievements()

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
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# Header
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title = Label.new()
	title.text = "ACHIEVEMENTS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	# Progress display
	var progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.text = "0 / 0"
	progress_label.add_theme_font_size_override("font_size", 18)
	header_hbox.add_child(progress_label)

	# Category tabs
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(tabs_hbox)

	for category in CATEGORIES:
		var btn = Button.new()
		btn.text = category.capitalize() if category != "all" else "All"
		btn.custom_minimum_size = Vector2(80, 30)
		btn.pressed.connect(_on_category_pressed.bind(category))
		tabs_hbox.add_child(btn)
		category_buttons[category] = btn

	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)

	# Scrollable achievement list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var achievements_grid = GridContainer.new()
	achievements_grid.name = "AchievementsGrid"
	achievements_grid.columns = 2
	achievements_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievements_grid.add_theme_constant_override("h_separation", 15)
	achievements_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(achievements_grid)

	# Back button
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(150, 40)
	back_button.pressed.connect(_on_back_pressed)
	main_vbox.add_child(back_button)

	# Highlight current category
	_update_category_buttons()

func _populate_achievements() -> void:
	var grid = panel.get_node("MarginContainer/VBoxContainer/ScrollContainer/AchievementsGrid")
	if not grid:
		return

	# Clear existing
	for child in grid.get_children():
		child.queue_free()

	# Get achievements
	var achievements: Array[Dictionary] = []
	if AchievementManager:
		if current_category == "all":
			achievements = AchievementManager.get_all_achievements()
		else:
			achievements = AchievementManager.get_achievements_by_category(current_category)

	# Update progress
	var progress_label = panel.get_node("MarginContainer/VBoxContainer/HBoxContainer/ProgressLabel")
	if progress_label and AchievementManager:
		var progress = AchievementManager.get_progress()
		progress_label.text = "%d / %d" % [progress["unlocked"], progress["total"]]

	# Add achievement cards
	for achievement in achievements:
		var card = _create_achievement_card(achievement)
		grid.add_child(card)

func _create_achievement_card(achievement: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 80)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	margin.add_child(hbox)

	# Icon placeholder (colored rect)
	var icon_rect = ColorRect.new()
	icon_rect.custom_minimum_size = Vector2(50, 50)
	if achievement.get("unlocked", false):
		icon_rect.color = _get_category_color(achievement.get("category", ""))
	else:
		icon_rect.color = Color(0.3, 0.3, 0.3)
	hbox.add_child(icon_rect)

	# Text container
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	# Name
	var name_label = Label.new()
	name_label.text = achievement.get("name", "Unknown")
	if achievement.get("unlocked", false):
		name_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		name_label.add_theme_color_override("font_color", Color.GRAY)
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = achievement.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	if achievement.get("unlocked", false):
		desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	else:
		desc_label.add_theme_color_override("font_color", Color.DIM_GRAY)
	vbox.add_child(desc_label)

	# Status
	var status_label = Label.new()
	if achievement.get("unlocked", false):
		status_label.text = "UNLOCKED"
		status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_label.text = "LOCKED"
		status_label.add_theme_color_override("font_color", Color.DIM_GRAY)
	status_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(status_label)

	return card

func _get_category_color(category: String) -> Color:
	match category:
		"racing":
			return Color.GOLD
		"skill":
			return Color.CYAN
		"damage":
			return Color.ORANGE_RED
		"progression":
			return Color.GREEN
		_:
			return Color.WHITE

func _update_category_buttons() -> void:
	for category in category_buttons:
		var btn: Button = category_buttons[category]
		if category == current_category:
			btn.add_theme_color_override("font_color", Color.GOLD)
		else:
			btn.remove_theme_color_override("font_color")

func _on_category_pressed(category: String) -> void:
	current_category = category
	_update_category_buttons()
	_populate_achievements()

func _on_back_pressed() -> void:
	back_requested.emit()
	queue_free()
