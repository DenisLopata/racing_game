class_name RacingLineGenerator
extends RefCounted
## Generates multiple racing lines from track analysis for different AI difficulties

var track_analyzer: TrackAnalyzer
var tile_map: TileMapLayer

# Generated paths (world coordinates)
var optimal_line: PackedVector2Array    # Expert - near inner edge
var racing_line: PackedVector2Array     # Hard - between center and inner
var center_line: PackedVector2Array     # Medium - middle of road
var wide_line: PackedVector2Array       # Easy - near outer edge

# Speed hints for each line (0.0 = slow corner, 1.0 = full speed straight)
var optimal_speed_hints: Array[float] = []
var racing_speed_hints: Array[float] = []
var center_speed_hints: Array[float] = []
var wide_speed_hints: Array[float] = []

# Boundary lines for reference
var outer_boundary_line: PackedVector2Array
var inner_boundary_line: PackedVector2Array

var track_center: Vector2

## Generate all racing lines from track analysis
func generate(analyzer: TrackAnalyzer, tilemap: TileMapLayer) -> void:
	track_analyzer = analyzer
	tile_map = tilemap

	outer_boundary_line = analyzer.tiles_to_world(analyzer.get_outer_boundary())
	inner_boundary_line = analyzer.tiles_to_world(analyzer.get_inner_boundary())
	track_center = analyzer.get_track_center()

	if outer_boundary_line.is_empty() or inner_boundary_line.is_empty():
		push_warning("RacingLineGenerator: Missing boundary data!")
		return

	if outer_boundary_line.size() != inner_boundary_line.size():
		push_warning("RacingLineGenerator: Boundary size mismatch - outer: %d, inner: %d" % [
			outer_boundary_line.size(), inner_boundary_line.size()
		])

	# Generate racing lines by interpolating between inner and outer boundaries
	# Easy (wide) = 15% from outer toward inner
	# Medium (center) = 50% (middle)
	# Hard (racing) = 70% from outer toward inner
	# Expert (optimal) = 85% from outer toward inner (close to inner edge)

	wide_line = _interpolate_boundaries(0.15)
	center_line = _interpolate_boundaries(0.5)
	racing_line = _interpolate_boundaries(0.70)
	optimal_line = _interpolate_boundaries(0.85)

	# Smooth all lines
	wide_line = _smooth_path(wide_line, 2)
	center_line = _smooth_path(center_line, 2)
	racing_line = _smooth_path(racing_line, 2)
	optimal_line = _smooth_path(optimal_line, 2)

	# Generate speed hints based on curvature for each line
	wide_speed_hints = _generate_speed_hints(wide_line)
	center_speed_hints = _generate_speed_hints(center_line)
	racing_speed_hints = _generate_speed_hints(racing_line)
	optimal_speed_hints = _generate_speed_hints(optimal_line)

## Interpolate between outer and inner boundaries
## factor = 0.0 means outer boundary, factor = 1.0 means inner boundary
func _interpolate_boundaries(factor: float) -> PackedVector2Array:
	var result = PackedVector2Array()
	var count = mini(outer_boundary_line.size(), inner_boundary_line.size())

	for i in count:
		var outer_pt = outer_boundary_line[i]
		var inner_pt = inner_boundary_line[i]
		var interpolated = outer_pt.lerp(inner_pt, factor)
		result.append(interpolated)

	return result

## Smooth a path using moving average
func _smooth_path(path: PackedVector2Array, iterations: int) -> PackedVector2Array:
	if path.size() < 3:
		return path

	var smoothed = path.duplicate()

	for _iter in iterations:
		var new_smoothed = PackedVector2Array()
		for i in smoothed.size():
			var prev_idx = (i - 1 + smoothed.size()) % smoothed.size()
			var next_idx = (i + 1) % smoothed.size()
			var avg = (smoothed[prev_idx] + smoothed[i] + smoothed[next_idx]) / 3.0
			new_smoothed.append(avg)
		smoothed = new_smoothed

	return smoothed

## Get line for a specific difficulty
func get_line_for_difficulty(difficulty: String) -> PackedVector2Array:
	match difficulty:
		"expert":
			return optimal_line
		"hard":
			return racing_line
		"medium":
			return center_line
		"easy":
			return wide_line
	return center_line

## Get all lines as a dictionary
func get_all_lines() -> Dictionary:
	return {
		"optimal": optimal_line,
		"racing": racing_line,
		"center": center_line,
		"wide": wide_line,
		"outer_boundary": outer_boundary_line,
		"inner_boundary": inner_boundary_line
	}

## Get speed hints for a specific difficulty
func get_speed_hints_for_difficulty(difficulty: String) -> Array[float]:
	match difficulty:
		"expert":
			return optimal_speed_hints
		"hard":
			return racing_speed_hints
		"medium":
			return center_speed_hints
		"easy":
			return wide_speed_hints
	return center_speed_hints

## Generate speed hints based on path curvature
## Returns array of floats (0.0 = sharp corner, 1.0 = straight)
func _generate_speed_hints(path: PackedVector2Array) -> Array[float]:
	var hints: Array[float] = []
	if path.size() < 3:
		for i in path.size():
			hints.append(1.0)
		return hints

	# Calculate curvature at each point
	var curvatures: Array[float] = []
	for i in path.size():
		var prev_idx = (i - 1 + path.size()) % path.size()
		var next_idx = (i + 1) % path.size()

		var prev_pt = path[prev_idx]
		var curr_pt = path[i]
		var next_pt = path[next_idx]

		# Direction vectors
		var dir1 = (curr_pt - prev_pt).normalized()
		var dir2 = (next_pt - curr_pt).normalized()

		# Curvature is how much direction changes (0 = straight, PI = U-turn)
		var angle_change = abs(dir1.angle_to(dir2))
		curvatures.append(angle_change)

	# Smooth curvatures (look at surrounding points too)
	var smoothed_curvatures: Array[float] = []
	var smooth_window = 3
	for i in curvatures.size():
		var sum = 0.0
		var count = 0
		for offset in range(-smooth_window, smooth_window + 1):
			var idx = (i + offset + curvatures.size()) % curvatures.size()
			sum += curvatures[idx]
			count += 1
		smoothed_curvatures.append(sum / count)

	# Convert curvature to speed hints
	# Higher curvature = lower speed hint
	var max_curvature = 0.3  # Above this angle is considered a sharp turn
	for curvature in smoothed_curvatures:
		# Map curvature to speed hint (inverted)
		var speed_hint = 1.0 - clamp(curvature / max_curvature, 0.0, 0.7)
		hints.append(speed_hint)

	return hints
