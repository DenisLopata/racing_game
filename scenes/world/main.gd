extends Node2D

const CountdownOverlayScene = preload("res://scenes/UI/countdown_overlay.tscn")
const ResultsScreenScene = preload("res://scenes/UI/results_screen.tscn")
const CarScene = preload("res://scenes/entites/car.tscn")

## Number of AI opponents
@export var num_ai_opponents: int = 7

## Starting grid configuration
@export var grid_start_position: Vector2 = Vector2(295, 400)
@export var grid_row_spacing: float = 40.0
@export var grid_column_offset: float = 30.0

@onready var tire_marks_line_2d: Line2D = $TireMarksLine2D
@onready var car: Car = $Car
@onready var surface_manager: SurfaceManager = $SurfaceManager
@onready var speedometer: Speedometer = %Speedometer
@onready var lap_tracker: LapTracker = $LapTracker
@onready var tile_map_layer: TileMapLayer = $TileMapLayer

var countdown_overlay: CountdownOverlay
var results_screen: ResultsScreen
var player_car: Car
var ai_cars: Array[Car] = []
var racing_line: WaypointPath

## Camera zoom settings (for debug)
var camera: Camera2D
var zoom_level: float = 1.0
const ZOOM_MIN: float = 0.2   # Zoomed out (see whole track)
const ZOOM_MAX: float = 2.0   # Zoomed in
const ZOOM_SPEED: float = 0.1

## AI car colors for visual distinction
var ai_colors: Array[Color] = [
	Color(1, 0.3, 0.3),    # Red
	Color(0.3, 0.3, 1),    # Blue
	Color(0.3, 1, 0.3),    # Green
	Color(1, 1, 0.3),      # Yellow
	Color(1, 0.3, 1),      # Magenta
	Color(0.3, 1, 1),      # Cyan
	Color(1, 0.6, 0.3),    # Orange
]

func _ready() -> void:
	car.tire_marks = tire_marks_line_2d
	car.surface_manager = surface_manager

	# Get camera reference for zoom
	camera = car.get_node_or_null("Camera2D")
	if camera:
		zoom_level = camera.zoom.x

	# Assign player controller to the car
	var player_controller = PlayerController.new()
	car.set_controller(player_controller)
	player_car = car

	# Register player car with RaceManager
	RaceManager.register_car(car)

	# Create racing line for AI
	_create_racing_line()

	# Spawn AI opponents
	_spawn_ai_cars()

	# Create and add countdown overlay
	countdown_overlay = CountdownOverlayScene.instantiate()
	add_child(countdown_overlay)

	# Create results screen
	results_screen = ResultsScreenScene.instantiate()
	results_screen.restart_requested.connect(_on_restart_requested)
	results_screen.quit_requested.connect(_on_quit_requested)
	add_child(results_screen)

	# Connect signals
	car.drift_marks_finished.connect(_on_car_drift_marks_finished)
	car.update_speed.connect(_on_car_update_speed)
	RaceManager.race_state_changed.connect(_on_race_state_changed)
	RaceManager.car_finished.connect(_on_car_finished)

	# Start countdown after a short delay
	await get_tree().create_timer(0.5).timeout
	RaceManager.start_countdown()

func _create_racing_line() -> void:
	# Create a simple oval racing line for testing
	# In production, this should be a manually created Path2D in the editor
	racing_line = WaypointPath.new()
	racing_line.name = "RacingLine"
	add_child(racing_line)

	# Create an oval path around the track
	# ADJUST THESE VALUES to match your track layout:
	var track_center = Vector2(400, 400)  # Center of your track
	var track_width = 250                  # Half-width of track
	var track_height = 300                 # Half-height of track

	racing_line.create_oval_path(
		track_center,
		track_width,
		track_height,
		24  # Number of points (more = smoother)
	)

	racing_line.is_closed_loop = true

	# DEBUG: Draw the racing line so we can see it
	_draw_debug_racing_line()

func _draw_debug_racing_line() -> void:
	# Create a visible line showing the AI racing path
	var debug_line = Line2D.new()
	debug_line.name = "DebugRacingLine"
	debug_line.width = 3
	debug_line.default_color = Color(1, 0, 0, 0.7)  # Red, semi-transparent
	add_child(debug_line)

	# Sample points along the path
	if racing_line.curve:
		var path_length = racing_line.curve.get_baked_length()
		var num_samples = 50
		for i in num_samples + 1:
			var offset = (float(i) / num_samples) * path_length
			var point = racing_line.get_point_at_offset(offset)
			debug_line.add_point(point)

		# Close the loop
		debug_line.add_point(debug_line.points[0])

	print("DEBUG: Racing line drawn - adjust track_center, track_width, track_height in _create_racing_line()")

func _spawn_ai_cars() -> void:
	var difficulties = ["easy", "easy", "medium", "medium", "hard", "hard", "expert"]

	for i in num_ai_opponents:
		var ai_car = CarScene.instantiate() as Car
		ai_car.name = "AICar_%d" % i

		# Calculate grid position (staggered 2-wide grid)
		var row = (i + 1)  # Player is row 0
		var col = (i + 1) % 2  # Alternate left/right
		var grid_pos = grid_start_position + Vector2(
			col * grid_column_offset - grid_column_offset * 0.5,
			row * grid_row_spacing
		)
		ai_car.global_position = grid_pos
		ai_car.rotation = -PI / 2  # Face the same direction as start

		# Set a random drivetrain
		var drivetrains = ["FWD", "RWD", "AWD"]
		ai_car.drive_type = drivetrains[randi() % drivetrains.size()]

		# Add to scene before setting up (needed for onready vars)
		add_child(ai_car)

		# Setup AI car
		ai_car.surface_manager = surface_manager
		ai_car.tire_marks = _create_tire_marks_for_ai()

		# Create and assign AI controller
		var ai_controller = AIController.new()
		ai_controller.set_waypoint_path(racing_line)

		# Set difficulty
		var difficulty = difficulties[i % difficulties.size()]
		ai_controller.set_difficulty(difficulty)

		ai_car.set_controller(ai_controller)

		# Set car color for visual distinction
		if ai_car.has_node("Sprite2D"):
			ai_car.get_node("Sprite2D").modulate = ai_colors[i % ai_colors.size()]

		# Register with RaceManager
		RaceManager.register_car(ai_car)

		ai_cars.append(ai_car)

	print("Spawned %d AI opponents" % ai_cars.size())

func _create_tire_marks_for_ai() -> Line2D:
	var tire_marks = Line2D.new()
	tire_marks.width = 2
	tire_marks.default_color = Color(0, 0, 0, 0.3)
	add_child(tire_marks)
	return tire_marks

func _input(event: InputEvent) -> void:
	# Mouse scroll zoom (for debug)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_level = clamp(zoom_level + ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
			if camera:
				camera.zoom = Vector2(zoom_level, zoom_level)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_level = clamp(zoom_level - ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
			if camera:
				camera.zoom = Vector2(zoom_level, zoom_level)

func _process(_delta: float) -> void:
	# Update position display during race
	if RaceManager.is_racing():
		_update_position_display()

func _update_position_display() -> void:
	var total_cars = RaceManager.registered_cars.size()
	var player_position = RaceManager.get_car_position(player_car)

	if player_position > 0:
		speedometer.set_race_position(player_position, total_cars)

	# Update lap display
	var player_data = RaceManager.get_car_lap_data(player_car.car_id)
	if player_data.size() > 0:
		var current_lap = player_data.get("laps", 0) + 1
		speedometer.set_total_laps(current_lap, RaceManager.total_laps)

func _on_race_state_changed(new_state: RaceManager.RaceState) -> void:
	match new_state:
		RaceManager.RaceState.RACING:
			# Race started - initialize UI
			speedometer.set_total_laps(1, RaceManager.total_laps)
			speedometer.set_race_position(1, RaceManager.registered_cars.size())
		RaceManager.RaceState.FINISHED:
			# Race finished - show results
			_show_results()

func _show_results() -> void:
	var results = RaceManager.get_race_results()
	print("=== RACE RESULTS ===")
	for result in results:
		var car_name = "Player" if result["car"] == player_car else result["car"].name
		print("P%d: %s - Time: %.2f - Best Lap: %.2f" % [
			result["position"],
			car_name,
			result["total_time"],
			result["best_lap"]
		])

	# Show results screen
	results_screen.show_results(results, player_car)

func _on_restart_requested() -> void:
	# Reload the scene to restart
	get_tree().reload_current_scene()

func _on_quit_requested() -> void:
	get_tree().quit()

func _on_car_finished(finished_car: Car, position: int, total_time: float) -> void:
	if finished_car == player_car:
		print("Player finished in position %d with time %.2f" % [position, total_time])
		# Force finish race when player finishes (or wait for all)
		RaceManager.force_finish_race()

func _on_lap_tracker_lap_completed(lap_number: int, lap_time: float) -> void:
	speedometer.set_lap(str(lap_number))
	speedometer.set_lap_time("%.2f" % lap_time)
	
func _on_lap_tracker_race_finished(lap_times: Array) -> void:
	#speedometer.set_speed(speed)
	pass
	
func _on_car_update_speed(speed: String) -> void:
	speedometer.set_speed(speed)
	
func _on_car_drift_marks_finished(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	
	var skid = Line2D.new()
	skid.width = 2
	skid.default_color = Color(0,0,0,0.6) # dark grey
	skid.points = points.duplicate()      # copy so it doesn’t get cleared
	skid.modulate.a = 0.2;
	skid.width = 10;
	add_child(skid)

	# Optional: move to a dedicated "Skidmarks" Node2D layer
	#$Skidmarks.add_child(skid)
