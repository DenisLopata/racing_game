class_name TrackGenerator
extends RefCounted
## Generates closed-loop track shapes using control points and Catmull-Rom splines

## Track size presets
enum TrackSize { SMALL, MEDIUM, LARGE }

## Track difficulty (affects turn count/sharpness)
enum Difficulty { FEW_TURNS, MODERATE, MANY_TURNS }

## Random number generator (seeded for reproducibility)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Tile size from tileset
var tile_size: int = 16

## Generated data
var control_points: PackedVector2Array = []
var spline_points: PackedVector2Array = []
var track_width_samples: Array[float] = []

## Map dimensions (in tiles)
var map_width: int = 80
var map_height: int = 80

## Current generation settings
var current_seed: int = 0
var current_size: TrackSize = TrackSize.MEDIUM
var current_difficulty: Difficulty = Difficulty.MODERATE

## Size presets
const SIZE_PRESETS = {
	TrackSize.SMALL: {
		"map_size": Vector2i(60, 60),
		"min_radius": 8,
		"max_radius": 15,
		"control_points": 6,
		"base_width": 4
	},
	TrackSize.MEDIUM: {
		"map_size": Vector2i(80, 80),
		"min_radius": 12,
		"max_radius": 22,
		"control_points": 10,
		"base_width": 5
	},
	TrackSize.LARGE: {
		"map_size": Vector2i(100, 100),
		"min_radius": 18,
		"max_radius": 30,
		"control_points": 14,
		"base_width": 6
	}
}

## Difficulty modifiers
const DIFFICULTY_MODIFIERS = {
	Difficulty.FEW_TURNS: {
		"radius_variance": 0.15,
		"angle_variance": 0.1,
		"width_variance": 0.1
	},
	Difficulty.MODERATE: {
		"radius_variance": 0.35,
		"angle_variance": 0.25,
		"width_variance": 0.2
	},
	Difficulty.MANY_TURNS: {
		"radius_variance": 0.55,
		"angle_variance": 0.4,
		"width_variance": 0.3
	}
}

## Generate a complete track
func generate(seed_value: int, size: TrackSize, difficulty: Difficulty) -> void:
	current_seed = seed_value
	current_size = size
	current_difficulty = difficulty

	# Initialize RNG with seed
	rng.seed = seed_value

	# Get presets
	var preset = SIZE_PRESETS[size]
	map_width = preset["map_size"].x
	map_height = preset["map_size"].y

	# Generate track in steps
	_generate_control_points()
	_generate_spline()
	_generate_track_widths()

	# Validate and fix any issues
	_validate_track()

## Generate control points around the center
func _generate_control_points() -> void:
	control_points.clear()

	var preset = SIZE_PRESETS[current_size]
	var diff_mod = DIFFICULTY_MODIFIERS[current_difficulty]
	var num_points = preset["control_points"]

	# Track center in world coordinates
	var center = Vector2(map_width / 2.0, map_height / 2.0) * tile_size

	# Base radius range
	var min_radius = preset["min_radius"] * tile_size
	var max_radius = preset["max_radius"] * tile_size
	var base_radius = (min_radius + max_radius) / 2.0
	var radius_range = max_radius - min_radius

	for i in num_points:
		# Base angle evenly distributed around circle
		var base_angle = (float(i) / num_points) * TAU

		# Add angle variance for organic feel
		var angle_variance = (PI / num_points) * diff_mod["angle_variance"]
		var angle_offset = rng.randf_range(-angle_variance, angle_variance)
		var angle = base_angle + angle_offset

		# Radius with variance based on difficulty
		var radius_offset = rng.randf_range(-radius_range / 2, radius_range / 2) * diff_mod["radius_variance"]
		var radius = base_radius + radius_offset

		# Clamp radius to valid range
		radius = clampf(radius, min_radius, max_radius)

		var point = center + Vector2(cos(angle), sin(angle)) * radius
		control_points.append(point)

## Generate smooth spline from control points using Catmull-Rom
func _generate_spline() -> void:
	spline_points.clear()

	if control_points.size() < 3:
		return

	var num_control = control_points.size()
	var samples_per_segment = 20  # Points between each control point

	for i in num_control:
		# Get 4 control points for Catmull-Rom (wrap around for closed loop)
		var p0 = control_points[(i - 1 + num_control) % num_control]
		var p1 = control_points[i]
		var p2 = control_points[(i + 1) % num_control]
		var p3 = control_points[(i + 2) % num_control]

		# Sample the spline segment
		for j in samples_per_segment:
			var t = float(j) / samples_per_segment
			var point = _catmull_rom(p0, p1, p2, p3, t)
			spline_points.append(point)

## Catmull-Rom spline interpolation
func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 = t * t
	var t3 = t2 * t

	# Catmull-Rom basis functions
	var b0 = -0.5 * t3 + t2 - 0.5 * t
	var b1 = 1.5 * t3 - 2.5 * t2 + 1.0
	var b2 = -1.5 * t3 + 2.0 * t2 + 0.5 * t
	var b3 = 0.5 * t3 - 0.5 * t2

	return p0 * b0 + p1 * b1 + p2 * b2 + p3 * b3

## Generate track width at each spline point
func _generate_track_widths() -> void:
	track_width_samples.clear()

	var preset = SIZE_PRESETS[current_size]
	var diff_mod = DIFFICULTY_MODIFIERS[current_difficulty]
	var base_width = preset["base_width"]

	# Calculate curvature at each point to vary width
	var num_points = spline_points.size()

	for i in num_points:
		# Get direction change (curvature estimate)
		var prev_idx = (i - 2 + num_points) % num_points
		var next_idx = (i + 2) % num_points

		var dir_in = (spline_points[i] - spline_points[prev_idx]).normalized()
		var dir_out = (spline_points[next_idx] - spline_points[i]).normalized()
		var curvature = abs(dir_in.angle_to(dir_out))

		# Wider on straights (low curvature), narrower on turns (high curvature)
		var width_factor = 1.0 - curvature * 0.5  # Reduce up to 50% on sharp turns
		width_factor = clampf(width_factor, 0.6, 1.2)

		# Add some random variance
		var variance = rng.randf_range(-diff_mod["width_variance"], diff_mod["width_variance"])
		width_factor += variance * 0.2

		var width = base_width * width_factor
		track_width_samples.append(width)

	# Smooth the width samples
	_smooth_widths()

## Smooth track widths with moving average
func _smooth_widths() -> void:
	if track_width_samples.size() < 5:
		return

	var smoothed: Array[float] = []
	var num = track_width_samples.size()

	for i in num:
		var sum = 0.0
		var count = 0
		for offset in range(-2, 3):
			var idx = (i + offset + num) % num
			sum += track_width_samples[idx]
			count += 1
		smoothed.append(sum / count)

	track_width_samples = smoothed

## Validate track and fix issues
func _validate_track() -> void:
	if spline_points.size() < 10:
		push_warning("[TrackGenerator] Track has too few points, regenerating")
		# Could regenerate with different seed, for now just warn
		return

	# Check for self-intersection (simplified check)
	if _has_self_intersection():
		push_warning("[TrackGenerator] Track may have self-intersection")
		# Could attempt to fix or regenerate

## Check for self-intersection (simplified)
func _has_self_intersection() -> bool:
	var num = spline_points.size()
	if num < 10:
		return false

	# Check if any non-adjacent segments intersect
	var check_distance = tile_size * 2  # Minimum distance between non-adjacent points

	for i in range(0, num, 5):  # Sample every 5th point for speed
		for j in range(i + 10, num - 5, 5):
			var dist = spline_points[i].distance_to(spline_points[j])
			if dist < check_distance:
				return true

	return false

## Get the spline points
func get_spline_points() -> PackedVector2Array:
	return spline_points

## Get track widths
func get_track_widths() -> Array[float]:
	return track_width_samples

## Get map size in tiles
func get_map_size() -> Vector2i:
	return Vector2i(map_width, map_height)

## Find the straightest section for start line placement
func find_start_line_position() -> Dictionary:
	if spline_points.size() < 10:
		return {"position": Vector2.ZERO, "direction": Vector2.RIGHT, "index": 0}

	var best_idx = 0
	var min_curvature = INF
	var num = spline_points.size()

	# Look for the straightest section
	for i in num:
		var prev_idx = (i - 5 + num) % num
		var next_idx = (i + 5) % num

		var dir1 = (spline_points[i] - spline_points[prev_idx]).normalized()
		var dir2 = (spline_points[next_idx] - spline_points[i]).normalized()
		var curvature = abs(dir1.angle_to(dir2))

		if curvature < min_curvature:
			min_curvature = curvature
			best_idx = i

	var position = spline_points[best_idx]
	var next_idx = (best_idx + 1) % num
	var direction = (spline_points[next_idx] - position).normalized()

	return {
		"position": position,
		"direction": direction,
		"index": best_idx,
		"width": track_width_samples[best_idx] if best_idx < track_width_samples.size() else 5.0
	}

## Get current seed (useful for saving/sharing tracks)
func get_seed() -> int:
	return current_seed
