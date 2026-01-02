class_name CircularTachometer
extends Control
## Circular tachometer/RPM gauge that draws a semicircular dial

# Display settings
@export var radius: float = 50.0
@export var thickness: float = 8.0
@export var start_angle: float = 135.0  # Degrees, 0 = right, CCW
@export var end_angle: float = 45.0     # Full sweep
@export var show_redline: bool = true
@export var redline_start: float = 0.8  # When redline zone starts (0-1)

# Colors
@export var bg_color: Color = Color(0.15, 0.15, 0.15, 0.8)
@export var low_rpm_color: Color = Color(0.2, 0.8, 0.2)      # Green
@export var mid_rpm_color: Color = Color(1.0, 0.8, 0.0)      # Yellow
@export var high_rpm_color: Color = Color(1.0, 0.3, 0.1)     # Red
@export var redline_color: Color = Color(1.0, 0.1, 0.1, 0.8)
@export var needle_color: Color = Color(1.0, 0.9, 0.8)
@export var tick_color: Color = Color(0.7, 0.7, 0.7)

# Current values
var current_rpm: float = 0.0  # 0.0 to 1.0
var current_gear: int = 1
var target_rpm: float = 0.0

# Animation
var needle_smoothing: float = 10.0

# Internal
var _center: Vector2
var _sweep_angle: float  # Total angle sweep in radians

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2 + 20, radius + 30)
	_calculate_sweep()

func _calculate_sweep() -> void:
	# Calculate total sweep angle
	var start_rad = deg_to_rad(start_angle)
	var end_rad = deg_to_rad(end_angle)

	# Handle wrap-around (e.g., 135 to 45 = 270 degrees)
	if end_angle < start_angle:
		_sweep_angle = deg_to_rad(360 - start_angle + end_angle)
	else:
		_sweep_angle = end_rad - start_rad

func _process(delta: float) -> void:
	# Smooth needle movement
	current_rpm = lerpf(current_rpm, target_rpm, delta * needle_smoothing)
	queue_redraw()

func _draw() -> void:
	_center = Vector2(size.x / 2, size.y - 15)

	# Draw background arc
	_draw_arc_thick(_center, radius, deg_to_rad(start_angle), _sweep_angle, bg_color, thickness + 4)

	# Draw RPM segments
	_draw_rpm_arc()

	# Draw redline zone
	if show_redline:
		_draw_redline_zone()

	# Draw tick marks
	_draw_tick_marks()

	# Draw needle
	_draw_needle()

	# Draw center cap
	draw_circle(_center, 6, Color(0.3, 0.3, 0.3))
	draw_circle(_center, 4, Color(0.5, 0.5, 0.5))

	# Draw gear indicator
	_draw_gear_indicator()

func _draw_arc_thick(center: Vector2, arc_radius: float, start_rad: float, sweep_rad: float, color: Color, arc_thickness: float) -> void:
	var points = 32
	var inner_radius = arc_radius - arc_thickness / 2
	var outer_radius = arc_radius + arc_thickness / 2

	var polygon_points = PackedVector2Array()

	# Outer arc (counter-clockwise from start to end)
	for i in range(points + 1):
		var t = float(i) / float(points)
		var angle = start_rad - t * sweep_rad  # Negative because we go CCW
		polygon_points.append(center + Vector2(cos(angle), -sin(angle)) * outer_radius)

	# Inner arc (clockwise back to start)
	for i in range(points, -1, -1):
		var t = float(i) / float(points)
		var angle = start_rad - t * sweep_rad
		polygon_points.append(center + Vector2(cos(angle), -sin(angle)) * inner_radius)

	if polygon_points.size() >= 3:
		draw_polygon(polygon_points, [color])

func _draw_rpm_arc() -> void:
	if current_rpm <= 0.01:
		return

	# Calculate color based on RPM
	var rpm_color: Color
	if current_rpm < 0.5:
		rpm_color = low_rpm_color.lerp(mid_rpm_color, current_rpm * 2.0)
	else:
		rpm_color = mid_rpm_color.lerp(high_rpm_color, (current_rpm - 0.5) * 2.0)

	# Draw filled arc up to current RPM
	var sweep = _sweep_angle * current_rpm
	_draw_arc_thick(_center, radius, deg_to_rad(start_angle), sweep, rpm_color, thickness)

func _draw_redline_zone() -> void:
	# Draw redline zone as a background indicator
	var redline_sweep = _sweep_angle * (1.0 - redline_start)
	var redline_start_angle = deg_to_rad(start_angle) - _sweep_angle * redline_start

	_draw_arc_thick(_center, radius + thickness / 2 + 2, redline_start_angle, redline_sweep, redline_color, 3)

func _draw_tick_marks() -> void:
	var major_ticks = 5  # Number of major tick marks
	var minor_ticks = 2  # Minor ticks between major

	for i in range(major_ticks + 1):
		var t = float(i) / float(major_ticks)
		var angle = deg_to_rad(start_angle) - t * _sweep_angle

		var dir = Vector2(cos(angle), -sin(angle))
		var inner_point = _center + dir * (radius - thickness / 2 - 4)
		var outer_point = _center + dir * (radius + thickness / 2 + 4)

		draw_line(inner_point, outer_point, tick_color, 2.0)

		# Draw minor ticks (except after last major)
		if i < major_ticks:
			for j in range(1, minor_ticks + 1):
				var minor_t = t + (float(j) / float(minor_ticks + 1)) / float(major_ticks)
				var minor_angle = deg_to_rad(start_angle) - minor_t * _sweep_angle
				var minor_dir = Vector2(cos(minor_angle), -sin(minor_angle))
				var minor_inner = _center + minor_dir * (radius - thickness / 2 - 2)
				var minor_outer = _center + minor_dir * (radius + thickness / 2 + 2)
				draw_line(minor_inner, minor_outer, tick_color.darkened(0.3), 1.0)

func _draw_needle() -> void:
	var needle_angle = deg_to_rad(start_angle) - current_rpm * _sweep_angle
	var needle_dir = Vector2(cos(needle_angle), -sin(needle_angle))

	# Needle points
	var needle_tip = _center + needle_dir * (radius + 5)
	var needle_base = _center - needle_dir * 8

	# Draw needle with some width
	var perpendicular = Vector2(-needle_dir.y, needle_dir.x)
	var needle_points = PackedVector2Array([
		needle_tip,
		needle_base + perpendicular * 3,
		needle_base - perpendicular * 3
	])

	draw_polygon(needle_points, [needle_color])

	# Highlight if in redline
	if current_rpm >= redline_start:
		# Pulse effect
		var pulse = 0.5 + sin(Time.get_ticks_msec() * 0.015) * 0.5
		draw_polygon(needle_points, [high_rpm_color.lerp(Color.WHITE, pulse * 0.3)])

func _draw_gear_indicator() -> void:
	var gear_text: String
	var gear_color: Color

	match current_gear:
		-1:
			gear_text = "R"
			gear_color = Color(1.0, 0.4, 0.4)
		0:
			gear_text = "N"
			gear_color = Color(0.7, 0.7, 0.7)
		_:
			gear_text = str(current_gear)
			gear_color = Color(1.0, 0.9, 0.3)

	# Draw gear number below center
	var font = ThemeDB.fallback_font
	var font_size = 18
	var text_size = font.get_string_size(gear_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = _center + Vector2(-text_size.x / 2, 20)

	draw_string(font, text_pos, gear_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, gear_color)

## Set the current RPM (0.0 to 1.0)
func set_rpm(rpm_percent: float) -> void:
	target_rpm = clampf(rpm_percent, 0.0, 1.0)

## Set the current gear
func set_gear(gear: int) -> void:
	current_gear = gear

## Set both RPM and gear
func set_rpm_gear(rpm_percent: float, gear: int) -> void:
	set_rpm(rpm_percent)
	set_gear(gear)

## Configure tachometer style
func configure(style: String) -> void:
	match style:
		"racing":
			low_rpm_color = Color(0.1, 0.6, 0.1)
			mid_rpm_color = Color(0.9, 0.7, 0.0)
			high_rpm_color = Color(0.9, 0.2, 0.1)
			redline_start = 0.85
		"sport":
			low_rpm_color = Color(0.0, 0.7, 1.0)
			mid_rpm_color = Color(0.0, 1.0, 0.5)
			high_rpm_color = Color(1.0, 0.5, 0.0)
			redline_start = 0.80
		"classic":
			low_rpm_color = Color(0.8, 0.8, 0.8)
			mid_rpm_color = Color(0.9, 0.9, 0.7)
			high_rpm_color = Color(1.0, 0.3, 0.2)
			bg_color = Color(0.05, 0.05, 0.05, 0.9)
		_:
			pass
