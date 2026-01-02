class_name Minimap
extends Control
## Minimap showing track outline and car positions

@export var minimap_size: Vector2 = Vector2(150, 150)
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.7)
@export var track_color: Color = Color(0.4, 0.4, 0.4, 1.0)
@export var player_color: Color = Color(0.2, 1.0, 0.2, 1.0)
@export var ai_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var track_line_width: float = 3.0
@export var car_dot_radius: float = 4.0
@export var player_dot_radius: float = 5.0

# Track data
var track_points: PackedVector2Array = PackedVector2Array()
var track_bounds: Rect2 = Rect2()
var scale_factor: float = 1.0
var offset: Vector2 = Vector2.ZERO

# Car references
var player_car: Node2D = null
var ai_cars: Array = []

# Internal drawing
var _background_rect: ColorRect
var _track_line: Line2D
var _car_dots: Array[ColorRect] = []
var _player_dot: ColorRect

func _ready() -> void:
	custom_minimum_size = minimap_size
	_create_background()
	_create_track_line()
	_create_player_dot()

func _create_background() -> void:
	_background_rect = ColorRect.new()
	_background_rect.color = background_color
	_background_rect.size = minimap_size
	_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background_rect)

	# Add border
	var border = ReferenceRect.new()
	border.size = minimap_size
	border.border_color = Color(0.5, 0.5, 0.5, 0.8)
	border.border_width = 2.0
	border.editor_only = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

func _create_track_line() -> void:
	_track_line = Line2D.new()
	_track_line.width = track_line_width
	_track_line.default_color = track_color
	_track_line.antialiased = true
	# Note: Line2D doesn't have mouse_filter (it's a Node2D, not Control)
	add_child(_track_line)

func _create_player_dot() -> void:
	_player_dot = _create_dot(player_color, player_dot_radius)
	_player_dot.visible = false
	add_child(_player_dot)

func _create_dot(color: Color, radius: float) -> ColorRect:
	var dot = ColorRect.new()
	dot.size = Vector2(radius * 2, radius * 2)
	dot.color = color
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot

## Initialize minimap with track data
func setup_track(points: PackedVector2Array) -> void:
	if points.size() < 3:
		return

	track_points = points

	# Calculate bounds
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)

	for point in track_points:
		min_pos.x = min(min_pos.x, point.x)
		min_pos.y = min(min_pos.y, point.y)
		max_pos.x = max(max_pos.x, point.x)
		max_pos.y = max(max_pos.y, point.y)

	track_bounds = Rect2(min_pos, max_pos - min_pos)

	# Calculate scale to fit track in minimap with padding
	var padding = 10.0
	var available_size = minimap_size - Vector2(padding * 2, padding * 2)

	var scale_x = available_size.x / track_bounds.size.x if track_bounds.size.x > 0 else 1.0
	var scale_y = available_size.y / track_bounds.size.y if track_bounds.size.y > 0 else 1.0
	scale_factor = min(scale_x, scale_y)

	# Calculate offset to center track
	var scaled_size = track_bounds.size * scale_factor
	offset = (minimap_size - scaled_size) / 2.0

	# Update track line
	_update_track_line()

func _update_track_line() -> void:
	var minimap_points = PackedVector2Array()

	for point in track_points:
		minimap_points.append(_world_to_minimap(point))

	# Close the loop
	if minimap_points.size() > 0:
		minimap_points.append(minimap_points[0])

	_track_line.points = minimap_points

## Convert world position to minimap position
func _world_to_minimap(world_pos: Vector2) -> Vector2:
	var relative_pos = world_pos - track_bounds.position
	return relative_pos * scale_factor + offset

## Set the player car reference
func set_player_car(car: Node2D) -> void:
	player_car = car
	_player_dot.visible = true

## Set AI car references
func set_ai_cars(cars: Array) -> void:
	# Clear existing AI dots
	for dot in _car_dots:
		dot.queue_free()
	_car_dots.clear()

	ai_cars = cars

	# Create dots for each AI car
	for i in ai_cars.size():
		var dot = _create_dot(ai_color, car_dot_radius)
		add_child(dot)
		_car_dots.append(dot)

func _process(_delta: float) -> void:
	_update_car_positions()

func _update_car_positions() -> void:
	# Update player dot
	if player_car and is_instance_valid(player_car):
		var minimap_pos = _world_to_minimap(player_car.global_position)
		_player_dot.position = minimap_pos - Vector2(player_dot_radius, player_dot_radius)
		_player_dot.visible = _is_in_bounds(minimap_pos)

	# Update AI dots
	for i in ai_cars.size():
		if i >= _car_dots.size():
			break

		var ai_car = ai_cars[i]
		var dot = _car_dots[i]

		if ai_car and is_instance_valid(ai_car):
			var minimap_pos = _world_to_minimap(ai_car.global_position)
			dot.position = minimap_pos - Vector2(car_dot_radius, car_dot_radius)
			dot.visible = _is_in_bounds(minimap_pos)
		else:
			dot.visible = false

func _is_in_bounds(pos: Vector2) -> bool:
	return pos.x >= 0 and pos.x <= minimap_size.x and pos.y >= 0 and pos.y <= minimap_size.y

## Set custom colors for player/AI dots
func set_player_dot_color(color: Color) -> void:
	player_color = color
	if _player_dot:
		_player_dot.color = color

func set_ai_dot_color(color: Color) -> void:
	ai_color = color
	for dot in _car_dots:
		dot.color = color

## Toggle minimap visibility
func toggle_visibility() -> void:
	visible = not visible

## Set minimap size
func set_minimap_size(new_size: Vector2) -> void:
	minimap_size = new_size
	custom_minimum_size = new_size

	if _background_rect:
		_background_rect.size = new_size

	# Recalculate if track is set
	if track_points.size() > 0:
		setup_track(track_points)
