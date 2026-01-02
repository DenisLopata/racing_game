class_name DrivingHUD
extends Control
## Enhanced driving HUD with drift, weight transfer, and vehicle state indicators

# References to UI elements (set up in _ready or from scene)
var drift_angle_label: Label
var drift_score_label: Label
var drift_combo_label: Label
var handbrake_indicator: ColorRect
var weight_front_bar: ProgressBar
var weight_rear_bar: ProgressBar
var weight_left_bar: ProgressBar
var weight_right_bar: ProgressBar
var slip_angle_label: Label
var tachometer: Control

# Drift scoring
var drift_score: int = 0
var drift_combo: int = 0
var drift_combo_timer: float = 0.0
var is_currently_drifting: bool = false
var drift_duration: float = 0.0

# Constants
const DRIFT_COMBO_TIMEOUT: float = 2.0
const MIN_DRIFT_ANGLE_FOR_SCORE: float = 15.0
const DRIFT_SCORE_PER_SECOND: int = 100
const COMBO_MULTIPLIER_STEP: int = 500  # Score needed per combo level

# Colors
const COLOR_DRIFT_ACTIVE := Color(1.0, 0.5, 0.0)  # Orange
const COLOR_DRIFT_INACTIVE := Color(0.3, 0.3, 0.3)
const COLOR_HANDBRAKE_ON := Color(1.0, 0.2, 0.2)  # Red
const COLOR_HANDBRAKE_OFF := Color(0.2, 0.2, 0.2)
const COLOR_WEIGHT_HIGH := Color(1.0, 0.8, 0.2)  # Yellow
const COLOR_WEIGHT_NORMAL := Color(0.4, 0.4, 0.4)

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	# Create main container
	var main_container = VBoxContainer.new()
	main_container.name = "DrivingHUDContainer"
	main_container.anchor_right = 1.0
	main_container.anchor_bottom = 1.0
	add_child(main_container)

	# Create top-right panel for drift info
	var drift_panel = _create_drift_panel()
	drift_panel.anchor_left = 1.0
	drift_panel.anchor_right = 1.0
	drift_panel.offset_left = -150
	drift_panel.offset_right = -10
	drift_panel.offset_top = 10
	drift_panel.offset_bottom = 120
	add_child(drift_panel)

	# Create weight transfer display (bottom-left)
	var weight_panel = _create_weight_panel()
	weight_panel.anchor_top = 1.0
	weight_panel.anchor_bottom = 1.0
	weight_panel.offset_left = 10
	weight_panel.offset_right = 100
	weight_panel.offset_top = -100
	weight_panel.offset_bottom = -50
	add_child(weight_panel)

	# Create handbrake indicator (near speedometer)
	handbrake_indicator = ColorRect.new()
	handbrake_indicator.name = "HandbrakeIndicator"
	handbrake_indicator.custom_minimum_size = Vector2(40, 20)
	handbrake_indicator.color = COLOR_HANDBRAKE_OFF
	handbrake_indicator.anchor_top = 1.0
	handbrake_indicator.anchor_bottom = 1.0
	handbrake_indicator.offset_left = 120
	handbrake_indicator.offset_right = 170
	handbrake_indicator.offset_top = -65
	handbrake_indicator.offset_bottom = -45
	add_child(handbrake_indicator)

	var hb_label = Label.new()
	hb_label.text = "HB"
	hb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb_label.anchor_right = 1.0
	hb_label.anchor_bottom = 1.0
	handbrake_indicator.add_child(hb_label)

	# Create slip angle debug display (top-left, can be toggled)
	var debug_panel = _create_debug_panel()
	debug_panel.offset_left = 10
	debug_panel.offset_right = 150
	debug_panel.offset_top = 10
	debug_panel.offset_bottom = 80
	debug_panel.visible = false  # Hidden by default
	add_child(debug_panel)

func _create_drift_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = "DriftPanel"

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	# Drift angle
	var angle_hbox = HBoxContainer.new()
	vbox.add_child(angle_hbox)

	var angle_title = Label.new()
	angle_title.text = "DRIFT"
	angle_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	angle_hbox.add_child(angle_title)

	angle_hbox.add_child(_create_spacer())

	drift_angle_label = Label.new()
	drift_angle_label.text = "0°"
	drift_angle_label.add_theme_color_override("font_color", COLOR_DRIFT_INACTIVE)
	drift_angle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	angle_hbox.add_child(drift_angle_label)

	# Drift score
	drift_score_label = Label.new()
	drift_score_label.text = "0"
	drift_score_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	drift_score_label.add_theme_font_size_override("font_size", 24)
	drift_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(drift_score_label)

	# Combo
	drift_combo_label = Label.new()
	drift_combo_label.text = ""
	drift_combo_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
	drift_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(drift_combo_label)

	return panel

func _create_weight_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = "WeightPanel"

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	panel.add_child(grid)

	# Top row: empty, front, empty
	grid.add_child(_create_spacer_rect())
	weight_front_bar = _create_weight_bar("F")
	grid.add_child(weight_front_bar)
	grid.add_child(_create_spacer_rect())

	# Middle row: left, car icon, right
	weight_left_bar = _create_weight_bar("L")
	weight_left_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	grid.add_child(weight_left_bar)

	var car_icon = ColorRect.new()
	car_icon.custom_minimum_size = Vector2(20, 20)
	car_icon.color = Color(0.5, 0.5, 0.5)
	grid.add_child(car_icon)

	weight_right_bar = _create_weight_bar("R")
	grid.add_child(weight_right_bar)

	# Bottom row: empty, rear, empty
	grid.add_child(_create_spacer_rect())
	weight_rear_bar = _create_weight_bar("B")
	weight_rear_bar.fill_mode = ProgressBar.FILL_TOP_TO_BOTTOM
	grid.add_child(weight_rear_bar)
	grid.add_child(_create_spacer_rect())

	return panel

func _create_weight_bar(tooltip: String) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(20, 20)
	bar.max_value = 1.0
	bar.value = 0.5
	bar.show_percentage = false
	bar.tooltip_text = tooltip
	return bar

func _create_debug_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = "DebugPanel"

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "DEBUG"
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	vbox.add_child(title)

	slip_angle_label = Label.new()
	slip_angle_label.text = "Slip: 0.0°"
	slip_angle_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(slip_angle_label)

	return panel

func _create_spacer() -> Control:
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer

func _create_spacer_rect() -> Control:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 20)
	return spacer

# =============================================================================
# Update Functions
# =============================================================================

func _process(delta: float) -> void:
	_update_drift_combo(delta)

## Update drift display
func update_drift(slip_angle: float, is_drifting: bool, speed: float) -> void:
	var abs_angle = abs(slip_angle)

	# Update angle display
	if drift_angle_label:
		drift_angle_label.text = "%d°" % int(abs_angle)
		if is_drifting:
			drift_angle_label.add_theme_color_override("font_color", COLOR_DRIFT_ACTIVE)
		else:
			drift_angle_label.add_theme_color_override("font_color", COLOR_DRIFT_INACTIVE)

	# Update drift scoring
	if is_drifting and speed > 50:
		if not is_currently_drifting:
			# Started new drift
			is_currently_drifting = true
			drift_duration = 0.0

		drift_duration += get_process_delta_time()

		# Score based on angle and duration
		var angle_mult = clamp(abs_angle / 45.0, 0.5, 2.0)
		var speed_mult = clamp(speed / 200.0, 0.5, 1.5)
		var score_delta = int(DRIFT_SCORE_PER_SECOND * angle_mult * speed_mult * get_process_delta_time())

		drift_score += score_delta * (1 + drift_combo)
		drift_combo_timer = DRIFT_COMBO_TIMEOUT

	elif is_currently_drifting:
		# Ended drift
		is_currently_drifting = false
		if drift_duration > 0.5:  # Minimum drift duration for combo
			drift_combo += 1

	# Update score display
	if drift_score_label:
		drift_score_label.text = str(drift_score)

func _update_drift_combo(delta: float) -> void:
	if drift_combo_timer > 0:
		drift_combo_timer -= delta
		if drift_combo_timer <= 0 and not is_currently_drifting:
			# Combo expired
			drift_combo = 0

	# Update combo display
	if drift_combo_label:
		if drift_combo > 0:
			drift_combo_label.text = "x%d COMBO!" % (drift_combo + 1)
			# Pulse effect
			var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.1
			drift_combo_label.scale = Vector2(pulse, pulse)
		else:
			drift_combo_label.text = ""

## Update handbrake indicator
func update_handbrake(is_active: bool) -> void:
	if handbrake_indicator:
		handbrake_indicator.color = COLOR_HANDBRAKE_ON if is_active else COLOR_HANDBRAKE_OFF

## Update weight transfer display
func update_weight_transfer(front: float, rear: float, left: float, right: float) -> void:
	if weight_front_bar:
		weight_front_bar.value = front
		weight_front_bar.modulate = COLOR_WEIGHT_HIGH if front > 0.6 else COLOR_WEIGHT_NORMAL

	if weight_rear_bar:
		weight_rear_bar.value = rear
		weight_rear_bar.modulate = COLOR_WEIGHT_HIGH if rear > 0.6 else COLOR_WEIGHT_NORMAL

	if weight_left_bar:
		weight_left_bar.value = left
		weight_left_bar.modulate = COLOR_WEIGHT_HIGH if left > 0.6 else COLOR_WEIGHT_NORMAL

	if weight_right_bar:
		weight_right_bar.value = right
		weight_right_bar.modulate = COLOR_WEIGHT_HIGH if right > 0.6 else COLOR_WEIGHT_NORMAL

## Update slip angle debug display
func update_slip_angle(angle: float) -> void:
	if slip_angle_label:
		slip_angle_label.text = "Slip: %.1f°" % angle

## Toggle debug display visibility
func toggle_debug() -> void:
	var debug_panel = get_node_or_null("DebugPanel")
	if debug_panel:
		debug_panel.visible = not debug_panel.visible

## Get current drift score (for end-of-race summary)
func get_drift_score() -> int:
	return drift_score

## Reset drift score (for new race)
func reset_drift_score() -> void:
	drift_score = 0
	drift_combo = 0
	drift_combo_timer = 0.0
	is_currently_drifting = false
