class_name ChallengesPanel
extends CanvasLayer
## Displays daily and weekly challenges with progress and rewards

signal back_requested()

var panel: Panel
var back_button: Button
var daily_container: VBoxContainer
var weekly_container: VBoxContainer
var daily_timer_label: Label
var weekly_timer_label: Label
var _update_timer: float = 0.0

func _ready() -> void:
	_build_ui()
	_populate_challenges()

	if ChallengeManager:
		ChallengeManager.challenge_completed.connect(_on_challenge_completed)
		ChallengeManager.challenges_refreshed.connect(_on_challenges_refreshed)

func _process(delta: float) -> void:
	# Update timers every second
	_update_timer += delta
	if _update_timer >= 1.0:
		_update_timer = 0.0
		_update_timers()

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
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)

	# Header
	var header = Label.new()
	header.text = "CHALLENGES"
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color.GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(header)

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var content_vbox = VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(content_vbox)

	# Daily Challenges Section
	var daily_section = _create_section("DAILY CHALLENGES", "DailyTimer")
	daily_timer_label = daily_section.get_node("Header/TimerLabel")
	daily_container = daily_section.get_node("ChallengeList")
	content_vbox.add_child(daily_section)

	# Weekly Challenge Section
	var weekly_section = _create_section("WEEKLY CHALLENGE", "WeeklyTimer")
	weekly_timer_label = weekly_section.get_node("Header/TimerLabel")
	weekly_container = weekly_section.get_node("ChallengeList")
	content_vbox.add_child(weekly_section)

	# Back button
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(150, 40)
	back_button.pressed.connect(_on_back_pressed)
	main_vbox.add_child(back_button)

func _create_section(title: String, timer_name: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)

	# Header row with title and timer
	var header_hbox = HBoxContainer.new()
	header_hbox.name = "Header"
	section.add_child(header_hbox)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_label)

	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "Refreshes in: --:--:--"
	timer_label.add_theme_font_size_override("font_size", 14)
	timer_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	header_hbox.add_child(timer_label)

	# Separator
	var sep = HSeparator.new()
	section.add_child(sep)

	# Challenge list
	var challenge_list = VBoxContainer.new()
	challenge_list.name = "ChallengeList"
	challenge_list.add_theme_constant_override("separation", 8)
	section.add_child(challenge_list)

	return section

func _populate_challenges() -> void:
	# Clear existing
	for child in daily_container.get_children():
		child.queue_free()
	for child in weekly_container.get_children():
		child.queue_free()

	if not ChallengeManager:
		return

	# Add daily challenges
	var daily_challenges = ChallengeManager.get_daily_challenges()
	for challenge in daily_challenges:
		var card = _create_challenge_card(challenge)
		daily_container.add_child(card)

	# Add weekly challenge
	var weekly_challenge = ChallengeManager.get_weekly_challenge()
	if not weekly_challenge.is_empty():
		var card = _create_challenge_card(weekly_challenge, true)
		weekly_container.add_child(card)

	_update_timers()

func _create_challenge_card(challenge: Dictionary, is_weekly: bool = false) -> PanelContainer:
	var card = PanelContainer.new()
	card.name = "Challenge_%s" % challenge.get("id", "unknown")

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	margin.add_child(hbox)

	# Status indicator
	var status_rect = ColorRect.new()
	status_rect.custom_minimum_size = Vector2(8, 60)
	if challenge.get("completed", false):
		if challenge.get("claimed", false):
			status_rect.color = Color.DIM_GRAY
		else:
			status_rect.color = Color.GREEN
	else:
		status_rect.color = Color.ORANGE if is_weekly else Color.CYAN
	hbox.add_child(status_rect)

	# Challenge info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Name
	var name_label = Label.new()
	name_label.text = challenge.get("name", "Challenge")
	name_label.add_theme_font_size_override("font_size", 16)
	if challenge.get("claimed", false):
		name_label.add_theme_color_override("font_color", Color.DIM_GRAY)
	elif challenge.get("completed", false):
		name_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		name_label.add_theme_color_override("font_color", Color.WHITE)
	info_vbox.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = challenge.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY if not challenge.get("claimed", false) else Color.DIM_GRAY)
	info_vbox.add_child(desc_label)

	# Progress bar for multi-race challenges
	var challenge_type: String = challenge.get("type", "")
	if challenge_type in ["race_count", "win_count", "podium_count", "consecutive_finishes"]:
		var progress_hbox = HBoxContainer.new()
		progress_hbox.add_theme_constant_override("separation", 8)
		info_vbox.add_child(progress_hbox)

		var progress_bar = ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(150, 16)
		progress_bar.max_value = float(challenge.get("target", 1))
		progress_bar.value = float(challenge.get("progress", 0))
		progress_bar.show_percentage = false
		progress_hbox.add_child(progress_bar)

		var progress_text = Label.new()
		progress_text.text = "%d / %d" % [challenge.get("progress", 0), challenge.get("target", 1)]
		progress_text.add_theme_font_size_override("font_size", 12)
		progress_hbox.add_child(progress_text)

	# Reward and claim button
	var reward_vbox = VBoxContainer.new()
	reward_vbox.add_theme_constant_override("separation", 5)
	hbox.add_child(reward_vbox)

	var reward_label = Label.new()
	reward_label.text = "%d" % challenge.get("reward", 0)
	reward_label.add_theme_font_size_override("font_size", 18)
	reward_label.add_theme_color_override("font_color", Color.GOLD if not challenge.get("claimed", false) else Color.DIM_GRAY)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_vbox.add_child(reward_label)

	if challenge.get("completed", false) and not challenge.get("claimed", false):
		var claim_btn = Button.new()
		claim_btn.text = "CLAIM"
		claim_btn.custom_minimum_size = Vector2(80, 30)
		claim_btn.pressed.connect(_on_claim_pressed.bind(challenge.get("id", "")))
		reward_vbox.add_child(claim_btn)
	else:
		var status_label = Label.new()
		if challenge.get("claimed", false):
			status_label.text = "CLAIMED"
			status_label.add_theme_color_override("font_color", Color.DIM_GRAY)
		elif challenge.get("completed", false):
			status_label.text = "DONE"
			status_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			status_label.text = "IN PROGRESS"
			status_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		status_label.add_theme_font_size_override("font_size", 10)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_vbox.add_child(status_label)

	return card

func _update_timers() -> void:
	if not ChallengeManager:
		return

	# Update daily timer
	var daily_remaining = ChallengeManager.get_daily_time_remaining()
	daily_timer_label.text = "Refreshes in: %s" % _format_time(daily_remaining)

	# Update weekly timer
	var weekly_remaining = ChallengeManager.get_weekly_time_remaining()
	weekly_timer_label.text = "Refreshes in: %s" % _format_time(weekly_remaining)

func _format_time(seconds: int) -> String:
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	var secs: int = seconds % 60

	if hours > 24:
		var days: int = hours / 24
		hours = hours % 24
		return "%dd %02d:%02d:%02d" % [days, hours, minutes, secs]
	else:
		return "%02d:%02d:%02d" % [hours, minutes, secs]

func _on_claim_pressed(challenge_id: String) -> void:
	if ChallengeManager:
		var reward = ChallengeManager.claim_reward(challenge_id)
		if reward > 0:
			print("[ChallengesPanel] Claimed %d reward for %s" % [reward, challenge_id])
			_populate_challenges()

func _on_challenge_completed(_challenge_id: String, _challenge: Dictionary) -> void:
	_populate_challenges()

func _on_challenges_refreshed() -> void:
	_populate_challenges()

func _on_back_pressed() -> void:
	back_requested.emit()
	queue_free()
