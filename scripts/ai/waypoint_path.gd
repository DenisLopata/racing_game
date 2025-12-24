class_name WaypointPath
extends Path2D
## Racing line path for AI navigation
## Place this as a child of the track and draw the optimal racing line

## Speed hints at different points along the path (0.0 = slow, 1.0 = full speed)
## Index corresponds to approximate position along path
@export var speed_hints: Array[float] = []

## Whether this is a closed loop track
@export var is_closed_loop: bool = true

## Cache the path length
var path_length: float = 0.0

func _ready() -> void:
	if curve:
		path_length = curve.get_baked_length()

## Get total path length
func get_path_length() -> float:
	if curve:
		return curve.get_baked_length()
	return 0.0

## Get world position at a given offset along the path
func get_point_at_offset(offset: float) -> Vector2:
	if curve == null or curve.point_count < 2:
		return global_position

	# Handle wrapping for closed loops
	var path_len = curve.get_baked_length()
	if is_closed_loop and path_len > 0:
		offset = fmod(offset, path_len)
		if offset < 0:
			offset += path_len

	var local_pos = curve.sample_baked(offset)
	return to_global(local_pos)

## Get direction (forward vector) at a given offset
func get_direction_at_offset(offset: float) -> Vector2:
	if curve == null or curve.point_count < 2:
		return Vector2.UP

	var path_len = curve.get_baked_length()
	if path_len == 0:
		return Vector2.UP

	# Sample two close points to get direction
	var sample_distance = 5.0  # Small offset for direction calculation
	var pos1 = get_point_at_offset(offset)
	var pos2 = get_point_at_offset(offset + sample_distance)

	var direction = (pos2 - pos1).normalized()
	if direction.length() < 0.1:
		return Vector2.UP

	return direction

## Get the closest offset on the path to a world position
func get_closest_offset(world_position: Vector2) -> float:
	if curve == null or curve.point_count < 2:
		return 0.0

	var local_pos = to_local(world_position)
	return curve.get_closest_offset(local_pos)

## Get the closest point on the path to a world position
func get_closest_point(world_position: Vector2) -> Vector2:
	if curve == null or curve.point_count < 2:
		return world_position

	var local_pos = to_local(world_position)
	var closest_local = curve.get_closest_point(local_pos)
	return to_global(closest_local)

## Get speed hint at a given offset (0.0 to 1.0)
func get_speed_hint_at_offset(offset: float) -> float:
	if speed_hints.size() == 0:
		return 1.0  # Full speed by default

	var path_len = curve.get_baked_length()
	if path_len == 0:
		return 1.0

	# Map offset to speed_hints array index
	var normalized_offset = offset / path_len
	var index = int(normalized_offset * speed_hints.size())
	index = clamp(index, 0, speed_hints.size() - 1)

	return speed_hints[index]

## Get the distance to the next corner (where speed hint drops)
func get_distance_to_corner(offset: float, threshold: float = 0.8) -> float:
	if speed_hints.size() == 0:
		return 9999.0  # No corners defined

	var path_len = curve.get_baked_length()
	if path_len == 0:
		return 9999.0

	var sample_step = path_len / 50.0  # Check 50 points ahead
	var max_check_distance = path_len * 0.5  # Don't look more than half track ahead

	var check_offset = offset
	var distance_checked = 0.0

	while distance_checked < max_check_distance:
		check_offset += sample_step
		distance_checked += sample_step

		var speed_hint = get_speed_hint_at_offset(check_offset)
		if speed_hint < threshold:
			return distance_checked

	return max_check_distance

## Create a simple circular path for testing
func create_oval_path(center: Vector2, radius_x: float, radius_y: float, points: int = 16) -> void:
	curve = Curve2D.new()

	for i in points:
		var angle = (float(i) / points) * TAU
		var point = Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		) + center

		# Calculate control points for smooth curve
		var tangent_angle = angle + PI / 2
		var tangent_length = (radius_x + radius_y) / 2.0 * (TAU / points) * 0.5
		var control_in = Vector2(cos(tangent_angle), sin(tangent_angle)) * -tangent_length
		var control_out = Vector2(cos(tangent_angle), sin(tangent_angle)) * tangent_length

		curve.add_point(point, control_in, control_out)

	path_length = curve.get_baked_length()

## Create path from an array of world positions
func create_from_points(points: PackedVector2Array, smooth: bool = true) -> void:
	if points.size() < 2:
		push_warning("WaypointPath: Need at least 2 points to create path")
		return

	curve = Curve2D.new()

	for i in points.size():
		var point = points[i]

		if smooth and points.size() > 2:
			# Calculate control points for smooth curve
			var prev_idx = (i - 1 + points.size()) % points.size()
			var next_idx = (i + 1) % points.size()

			var prev_pt = points[prev_idx]
			var next_pt = points[next_idx]

			var tangent = (next_pt - prev_pt).normalized()
			var tangent_length = (point.distance_to(prev_pt) + point.distance_to(next_pt)) * 0.25

			var control_in = -tangent * tangent_length
			var control_out = tangent * tangent_length

			curve.add_point(point, control_in, control_out)
		else:
			curve.add_point(point)

	path_length = curve.get_baked_length()
