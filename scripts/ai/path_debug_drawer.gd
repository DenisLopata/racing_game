class_name PathDebugDrawer
extends Node2D
## Draws debug visualization of all racing lines

# Debug line colors
const COLOR_OPTIMAL = Color.GOLD
const COLOR_RACING = Color.RED
const COLOR_CENTER = Color.DODGER_BLUE
const COLOR_WIDE = Color.LIME_GREEN
const COLOR_OUTER_BOUNDARY = Color.CYAN
const COLOR_INNER_BOUNDARY = Color.MAGENTA

# Line widths
const WIDTH_OPTIMAL = 4.0
const WIDTH_RACING = 3.0
const WIDTH_CENTER = 3.0
const WIDTH_WIDE = 3.0
const WIDTH_BOUNDARY = 2.0

# References
var line_generator: RacingLineGenerator

# Debug state
var show_all: bool = true
var show_optimal: bool = true
var show_racing: bool = true
var show_center: bool = true
var show_wide: bool = true
var show_boundaries: bool = false

# Line2D nodes for each line
var line_nodes: Dictionary = {}

## Initialize with a line generator
func setup(generator: RacingLineGenerator) -> void:
	line_generator = generator
	draw_all_lines()

## Draw all racing lines
func draw_all_lines() -> void:
	_clear_all_lines()

	if line_generator == null:
		return

	var lines = line_generator.get_all_lines()

	# Draw boundaries first (behind racing lines)
	if show_boundaries:
		_draw_line("outer_boundary", lines["outer_boundary"], COLOR_OUTER_BOUNDARY, WIDTH_BOUNDARY)
		_draw_line("inner_boundary", lines["inner_boundary"], COLOR_INNER_BOUNDARY, WIDTH_BOUNDARY)

	# Draw racing lines
	if show_all or show_wide:
		_draw_line("wide", lines["wide"], COLOR_WIDE, WIDTH_WIDE)

	if show_all or show_center:
		_draw_line("center", lines["center"], COLOR_CENTER, WIDTH_CENTER)

	if show_all or show_racing:
		_draw_line("racing", lines["racing"], COLOR_RACING, WIDTH_RACING)

	if show_all or show_optimal:
		_draw_line("optimal", lines["optimal"], COLOR_OPTIMAL, WIDTH_OPTIMAL)

## Draw a single line
func _draw_line(name: String, points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return

	var line = Line2D.new()
	line.name = "Debug_" + name
	line.width = width
	line.default_color = color
	line.points = points

	# Close the loop
	if points.size() > 2:
		line.add_point(points[0])

	add_child(line)
	line_nodes[name] = line

## Clear all debug lines
func _clear_all_lines() -> void:
	for child in get_children():
		if child is Line2D:
			child.queue_free()
	line_nodes.clear()

## Toggle all lines on/off
func toggle_all() -> void:
	show_all = !show_all
	draw_all_lines()
	print("Debug lines: %s" % ("ON" if show_all else "OFF"))

## Toggle individual line types
func toggle_optimal() -> void:
	show_optimal = !show_optimal
	_update_line_visibility("optimal", show_optimal)

func toggle_racing() -> void:
	show_racing = !show_racing
	_update_line_visibility("racing", show_racing)

func toggle_center() -> void:
	show_center = !show_center
	_update_line_visibility("center", show_center)

func toggle_wide() -> void:
	show_wide = !show_wide
	_update_line_visibility("wide", show_wide)

func toggle_boundaries() -> void:
	show_boundaries = !show_boundaries
	draw_all_lines()
	print("Boundaries: %s" % ("ON" if show_boundaries else "OFF"))

## Update visibility of a specific line
func _update_line_visibility(name: String, visible: bool) -> void:
	if name in line_nodes:
		line_nodes[name].visible = visible

## Cycle through showing individual lines
var cycle_index: int = 0
func cycle_lines() -> void:
	var modes = ["all", "optimal", "racing", "center", "wide", "none"]
	cycle_index = (cycle_index + 1) % modes.size()

	match modes[cycle_index]:
		"all":
			show_all = true
			show_optimal = true
			show_racing = true
			show_center = true
			show_wide = true
		"optimal":
			show_all = false
			show_optimal = true
			show_racing = false
			show_center = false
			show_wide = false
		"racing":
			show_all = false
			show_optimal = false
			show_racing = true
			show_center = false
			show_wide = false
		"center":
			show_all = false
			show_optimal = false
			show_racing = false
			show_center = true
			show_wide = false
		"wide":
			show_all = false
			show_optimal = false
			show_racing = false
			show_center = false
			show_wide = true
		"none":
			show_all = false
			show_optimal = false
			show_racing = false
			show_center = false
			show_wide = false

	draw_all_lines()
	print("Showing: %s" % modes[cycle_index])

## Get color legend text
func get_legend() -> String:
	return """Debug Lines:
  GOLD = Expert (Optimal/Apex)
  RED = Hard (Racing)
  BLUE = Medium (Center)
  GREEN = Easy (Wide)
  CYAN = Outer boundary
  MAGENTA = Inner boundary"""
