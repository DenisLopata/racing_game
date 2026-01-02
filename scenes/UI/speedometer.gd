class_name Speedometer
extends Control

@onready var hbox: HBoxContainer = $MarginContainer/HBoxContainer
@onready var lbl_speed: Label = $MarginContainer/HBoxContainer/lblSpeed
@onready var lbl_lap: Label = $MarginContainer/HBoxContainer/lblLap
@onready var lbl_lap_time: Label = $MarginContainer/HBoxContainer/lblLapTime
@onready var lbl_stats: Label = $MarginContainer/HBoxContainer/lblStats

# Gear and RPM indicators
@onready var lbl_gear: Label = $MarginContainer/HBoxContainer/GearPanel/lblGear
@onready var rpm_bar: ProgressBar = $MarginContainer/HBoxContainer/GearPanel/RpmContainer/RpmBar

# RPM bar colors
const RPM_COLOR_LOW := Color(0.2, 0.8, 0.2)      # Green - low RPM
const RPM_COLOR_MID := Color(1.0, 0.8, 0.0)      # Yellow - mid RPM
const RPM_COLOR_HIGH := Color(1.0, 0.3, 0.1)    # Red - high RPM / redline

# Damage indicators
@onready var damage_indicators: Dictionary = {
	"engines": $MarginContainer/HBoxContainer/DamagePanel/EngineIndicator,
	"tires": $MarginContainer/HBoxContainer/DamagePanel/TiresIndicator,
	"brakes": $MarginContainer/HBoxContainer/DamagePanel/BrakesIndicator,
	"suspensions": $MarginContainer/HBoxContainer/DamagePanel/SuspensionIndicator,
	"spoilers": $MarginContainer/HBoxContainer/DamagePanel/SpoilerIndicator
}

# Pit stop indicators
@onready var pit_indicator: HBoxContainer = $MarginContainer/HBoxContainer/PitIndicator
@onready var repair_bar: ProgressBar = $MarginContainer/HBoxContainer/PitIndicator/RepairBar
@onready var repair_part_label: Label = $MarginContainer/HBoxContainer/PitIndicator/RepairPart

var lbl_position: Label
var position_notifier: PositionNotifier
var _pit_stop_zone: PitStopZone = null
var _player_car: Node = null
var _flash_timer: float = 0.0
var _flash_parts: Array[String] = []

func _ready() -> void:
	_setup_position_label()
	_setup_position_notifier()
	_connect_damage_signals()
	_update_damage_indicators()

func _process(delta: float) -> void:
	_update_flash(delta)

func _setup_position_label() -> void:
	lbl_position = Label.new()
	lbl_position.text = "P1"
	hbox.add_child(lbl_position)
	hbox.move_child(lbl_position, 0)  # Move to front

func _setup_position_notifier() -> void:
	position_notifier = PositionNotifier.new()
	position_notifier.name = "PositionNotifier"
	# Position at top-right area
	position_notifier.anchor_left = 1.0
	position_notifier.anchor_right = 1.0
	position_notifier.anchor_top = 0.0
	position_notifier.anchor_bottom = 0.0
	position_notifier.offset_left = -220
	position_notifier.offset_right = -20
	position_notifier.offset_top = 60
	position_notifier.offset_bottom = 100
	add_child(position_notifier)

func set_speed(speed: String) -> void:
	lbl_speed.text = speed

func set_lap(lap_number: String) -> void:
	lbl_lap.text = "Lap: " + lap_number

func set_lap_time(lap_time: String) -> void:
	lbl_lap_time.text = "Time: " + lap_time

func set_race_position(pos: int, total: int) -> void:
	if lbl_position:
		lbl_position.text = "P%d/%d" % [pos, total]

		# Color based on position
		match pos:
			1:
				lbl_position.add_theme_color_override("font_color", Color.GOLD)
			2:
				lbl_position.add_theme_color_override("font_color", Color.SILVER)
			3:
				lbl_position.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
			_:
				lbl_position.add_theme_color_override("font_color", Color.WHITE)

	# Update position notifier for alerts
	if position_notifier:
		position_notifier.update_position(pos)

func set_total_laps(current: int, total: int) -> void:
	lbl_lap.text = "Lap: %d/%d" % [current, total]

## Display car stats from part modifiers
func set_car_stats(modifiers: CarModifiers) -> void:
	if modifiers and lbl_stats:
		lbl_stats.text = "ACC:%.1f SPD:%.1f BRK:%.1f" % [
			modifiers.acceleration_mult,
			modifiers.max_speed_mult,
			modifiers.brake_mult
		]

# =============================================================================
# Gear and RPM Display
# =============================================================================

## Set the current gear display
func set_gear(gear: int) -> void:
	if not lbl_gear:
		return

	var gear_text: String
	match gear:
		-1:
			gear_text = "R"
			lbl_gear.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))  # Red for reverse
		0:
			gear_text = "N"
			lbl_gear.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))  # Gray for neutral
		_:
			gear_text = str(gear)
			lbl_gear.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))  # Yellow for drive

	lbl_gear.text = gear_text

## Set the RPM bar value (0.0 to 1.0)
func set_rpm(rpm_percent: float) -> void:
	if not rpm_bar:
		return

	rpm_percent = clamp(rpm_percent, 0.0, 1.0)
	rpm_bar.value = rpm_percent

	# Color based on RPM level
	var rpm_color: Color
	if rpm_percent < 0.5:
		# Low to mid - green to yellow
		rpm_color = RPM_COLOR_LOW.lerp(RPM_COLOR_MID, rpm_percent * 2.0)
	else:
		# Mid to high - yellow to red
		rpm_color = RPM_COLOR_MID.lerp(RPM_COLOR_HIGH, (rpm_percent - 0.5) * 2.0)

	# Apply color to progress bar fill
	var style = rpm_bar.get_theme_stylebox("fill")
	if style:
		style = style.duplicate()
		if style is StyleBoxFlat:
			style.bg_color = rpm_color
			rpm_bar.add_theme_stylebox_override("fill", style)
	else:
		# Fallback: tint the whole bar
		rpm_bar.modulate = rpm_color

## Set gear and RPM together (convenience function)
func set_gear_rpm(gear: int, rpm_percent: float) -> void:
	set_gear(gear)
	set_rpm(rpm_percent)

## Connect to a car's transmission for automatic updates
func connect_car_transmission(car: Car) -> void:
	if car and car.transmission:
		car.gear_changed.connect(_on_gear_changed)

func _on_gear_changed(gear: int) -> void:
	set_gear(gear)

# =============================================================================
# Damage Indicators
# =============================================================================

## Set the player car reference for damage tracking
func set_player_car(car: Node) -> void:
	_player_car = car
	_update_damage_indicators()

## Connect to damage system signals
func _connect_damage_signals() -> void:
	if DamageSystem:
		DamageSystem.damage_taken.connect(_on_damage_taken)
		DamageSystem.part_failed.connect(_on_part_failed)

## Update all damage indicators based on current state
func _update_damage_indicators() -> void:
	var damage_state: CarDamageState = null

	# Try to get damage state from player progress or damage system
	if PlayerProgress:
		damage_state = PlayerProgress.get_damage_state()
	elif _player_car and DamageSystem:
		damage_state = DamageSystem.get_damage_state(_player_car)

	if not damage_state:
		return

	for part in damage_indicators:
		var indicator: ColorRect = damage_indicators[part]
		if not indicator:
			continue

		var health = damage_state.get_part_health(part)
		indicator.color = _get_health_color(health)

## Get color based on health level
func _get_health_color(health: float) -> Color:
	if health > 0.7:
		return Color.GREEN
	elif health > 0.3:
		return Color.YELLOW
	elif health > 0:
		return Color.RED
	else:
		return Color.DARK_RED

## Handle damage taken signal
func _on_damage_taken(car: Node, part: String, _amount: float, _new_health: float) -> void:
	# Only respond to player car damage
	if car != _player_car and (not PlayerProgress or not car.get("use_player_upgrades")):
		return

	_update_damage_indicators()

	# Flash the damaged part indicator
	if part not in _flash_parts:
		_flash_parts.append(part)
	_flash_timer = 1.0  # Flash for 1 second

## Handle part failed signal
func _on_part_failed(car: Node, part: String) -> void:
	# Only respond to player car
	if car != _player_car and (not PlayerProgress or not car.get("use_player_upgrades")):
		return

	_update_damage_indicators()

	# Keep flashing failed part
	if part not in _flash_parts:
		_flash_parts.append(part)
	_flash_timer = 3.0  # Flash longer for failure

## Update flash effect on damaged indicators
func _update_flash(delta: float) -> void:
	if _flash_timer <= 0 or _flash_parts.is_empty():
		return

	_flash_timer -= delta

	# Flash effect - alternate visibility
	var show = int(_flash_timer * 8) % 2 == 0

	for part in _flash_parts:
		if damage_indicators.has(part):
			var indicator: ColorRect = damage_indicators[part]
			if indicator:
				indicator.visible = show

	# Reset when done
	if _flash_timer <= 0:
		_flash_parts.clear()
		for part in damage_indicators:
			var indicator: ColorRect = damage_indicators[part]
			if indicator:
				indicator.visible = true

# =============================================================================
# Pit Stop Indicators
# =============================================================================

## Connect to a pit stop zone for UI updates
func connect_pit_stop_zone(zone: PitStopZone) -> void:
	if _pit_stop_zone:
		# Disconnect from old zone
		_pit_stop_zone.car_entered_pit.disconnect(_on_car_entered_pit)
		_pit_stop_zone.car_exited_pit.disconnect(_on_car_exited_pit)
		_pit_stop_zone.repair_progress.disconnect(_on_repair_progress)
		_pit_stop_zone.repair_complete.disconnect(_on_repair_complete)

	_pit_stop_zone = zone
	if zone:
		zone.car_entered_pit.connect(_on_car_entered_pit)
		zone.car_exited_pit.connect(_on_car_exited_pit)
		zone.repair_progress.connect(_on_repair_progress)
		zone.repair_complete.connect(_on_repair_complete)

## Handle car entering pit
func _on_car_entered_pit(car: Car) -> void:
	if car != _player_car:
		return

	if pit_indicator:
		pit_indicator.visible = true
		repair_bar.value = 0.0
		repair_part_label.text = ""

## Handle car exiting pit
func _on_car_exited_pit(car: Car) -> void:
	if car != _player_car:
		return

	if pit_indicator:
		pit_indicator.visible = false

	# Update damage indicators after repairs
	_update_damage_indicators()

## Handle repair progress update
func _on_repair_progress(car: Car, progress: float, part: String) -> void:
	if car != _player_car:
		return

	if repair_bar:
		repair_bar.value = progress
	if repair_part_label:
		repair_part_label.text = _get_part_display_name(part)

	# Update damage indicators in real-time
	_update_damage_indicators()

## Handle repair complete
func _on_repair_complete(car: Car) -> void:
	if car != _player_car:
		return

	if repair_part_label:
		repair_part_label.text = "DONE"

	_update_damage_indicators()

## Get display name for a part
func _get_part_display_name(part: String) -> String:
	match part:
		"engines": return "ENGINE"
		"tires": return "TIRES"
		"brakes": return "BRAKES"
		"suspensions": return "SUSP"
		"spoilers": return "SPOILER"
		_: return part.to_upper()

# =============================================================================
# Time Attack Mode
# =============================================================================

## Set the best lap time display
func set_best_lap_time(lap_time: float) -> void:
	if lbl_lap_time:
		lbl_lap_time.text = "Best: %.3f" % lap_time

## Show notification for new best lap
func show_new_best_notification() -> void:
	# Flash the lap time label
	if lbl_lap_time:
		lbl_lap_time.add_theme_color_override("font_color", Color.GOLD)
		# Reset color after a delay
		get_tree().create_timer(2.0).timeout.connect(func():
			if lbl_lap_time:
				lbl_lap_time.remove_theme_color_override("font_color")
		)
