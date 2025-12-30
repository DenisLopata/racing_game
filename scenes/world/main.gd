extends Node2D

const CountdownOverlayScene = preload("res://scenes/UI/countdown_overlay.tscn")
const ResultsScreenScene = preload("res://scenes/UI/results_screen.tscn")
const CarScene = preload("res://scenes/entites/car.tscn")
const RainEffectScene = preload("res://scenes/effects/rain_effect.tscn")
const FogEffectScene = preload("res://scenes/effects/fog_effect.tscn")
const PauseMenuScene = preload("res://scenes/UI/pause_menu.tscn")

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
var pause_menu: CanvasLayer
var player_car: Car
var ai_cars: Array[Car] = []

## Smart pathfinding components
var track_analyzer: TrackAnalyzer
var line_generator: RacingLineGenerator
var debug_drawer: PathDebugDrawer
var difficulty_paths: Dictionary = {}  # "easy" -> WaypointPath, etc.

## Camera zoom settings (loaded from config)
var camera: Camera2D
var zoom_level: float = 1.0
var ZOOM_MIN: float = 0.2
var ZOOM_MAX: float = 2.0
var ZOOM_SPEED: float = 0.1

## AI car colors (loaded from config)
var ai_colors: Array[Color] = []

## Weather grip modifier
var weather_grip_modifier: float = 1.0

## Selected AI difficulty from settings
var selected_ai_difficulty: String = "medium"

func _ready() -> void:
	# Reset RaceManager state (important for scene reload)
	RaceManager.full_reset()

	# Load configuration
	_load_from_config()

	# Load settings from GameSettings (if available)
	_apply_game_settings()

func _load_from_config() -> void:
	# Load camera settings
	var cam_config = ConfigManager.get_camera_settings()
	ZOOM_MIN = cam_config.get("zoom_min", 0.2)
	ZOOM_MAX = cam_config.get("zoom_max", 2.0)
	ZOOM_SPEED = cam_config.get("zoom_speed", 0.1)

	# Load AI colors
	ai_colors.clear()
	for color_arr in ConfigManager.get_ai_colors():
		ai_colors.append(ConfigManager.array_to_color(color_arr))

	# Load grid settings from current track
	var track_id = GameSettings.selected_track if has_node("/root/GameSettings") else "sunset_circuit"
	var track_config = ConfigManager.get_track(track_id)
	if not track_config.is_empty():
		var grid_pos = track_config.get("grid_start_position", [295, 400])
		grid_start_position = Vector2(grid_pos[0], grid_pos[1])
		grid_row_spacing = track_config.get("grid_row_spacing", 40.0)
		grid_column_offset = track_config.get("grid_column_offset", 30.0)

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

	# Analyze track and generate racing lines for AI
	_analyze_track_and_generate_paths()

	# Spawn AI opponents
	_spawn_ai_cars()

	# Setup race UI (countdown, results screen, signals)
	_setup_race_ui()

## Apply settings from GameSettings autoload
func _apply_game_settings() -> void:
	# Check if GameSettings exists (might be running scene directly for testing)
	if not Engine.has_singleton("GameSettings") and not has_node("/root/GameSettings"):
		return

	# Apply race settings
	RaceManager.total_laps = GameSettings.lap_count
	num_ai_opponents = GameSettings.opponent_count
	selected_ai_difficulty = GameSettings.ai_difficulty

	# Apply weather
	_apply_weather(GameSettings.weather)

## Apply weather effects
func _apply_weather(weather: String) -> void:
	match weather:
		"clear":
			weather_grip_modifier = 1.0
		"rain":
			weather_grip_modifier = 0.7
			_spawn_rain_effect()
		"fog":
			weather_grip_modifier = 0.9
			_spawn_fog_effect()
		_:
			weather_grip_modifier = 1.0

	# Apply to surface manager if it supports weather
	if surface_manager and surface_manager.has_method("set_weather_modifier"):
		surface_manager.set_weather_modifier(weather_grip_modifier)

func _spawn_rain_effect() -> void:
	var rain = RainEffectScene.instantiate()
	add_child(rain)

func _spawn_fog_effect() -> void:
	var fog = FogEffectScene.instantiate()
	add_child(fog)

func _setup_race_ui() -> void:
	# Create and add countdown overlay
	countdown_overlay = CountdownOverlayScene.instantiate()
	add_child(countdown_overlay)

	# Create results screen
	results_screen = ResultsScreenScene.instantiate()
	results_screen.restart_requested.connect(_on_restart_requested)
	results_screen.quit_requested.connect(_on_quit_requested)
	add_child(results_screen)

	# Create pause menu
	pause_menu = PauseMenuScene.instantiate()
	pause_menu.resume_requested.connect(_on_pause_resume)
	pause_menu.restart_requested.connect(_on_restart_requested)
	pause_menu.quit_requested.connect(_on_quit_requested)
	add_child(pause_menu)

	# Connect signals
	car.drift_marks_finished.connect(_on_car_drift_marks_finished)
	car.update_speed.connect(_on_car_update_speed)
	RaceManager.race_state_changed.connect(_on_race_state_changed)
	RaceManager.car_finished.connect(_on_car_finished)

	# Start countdown after a short delay
	await get_tree().create_timer(0.5).timeout
	RaceManager.start_countdown()

func _analyze_track_and_generate_paths() -> void:

	# 1. Analyze track structure from tilemap
	track_analyzer = TrackAnalyzer.new()
	track_analyzer.analyze(tile_map_layer, grid_start_position)

	# 2. Generate racing lines for different difficulties
	line_generator = RacingLineGenerator.new()
	line_generator.generate(track_analyzer, tile_map_layer)

	# 3. Convert generated lines to WaypointPaths (with speed hints for corner braking)
	difficulty_paths = {
		"expert": _create_waypoint_path_from_points(line_generator.optimal_line, "ExpertPath", line_generator.optimal_speed_hints),
		"hard": _create_waypoint_path_from_points(line_generator.racing_line, "HardPath", line_generator.racing_speed_hints),
		"medium": _create_waypoint_path_from_points(line_generator.center_line, "MediumPath", line_generator.center_speed_hints),
		"easy": _create_waypoint_path_from_points(line_generator.wide_line, "EasyPath", line_generator.wide_speed_hints)
	}

	# 4. Create debug drawer to visualize all lines
	debug_drawer = PathDebugDrawer.new()
	debug_drawer.name = "PathDebugDrawer"
	add_child(debug_drawer)
	debug_drawer.setup(line_generator)

func _create_waypoint_path_from_points(points: PackedVector2Array, path_name: String, speed_hints: Array[float] = []) -> WaypointPath:
	var path = WaypointPath.new()
	path.name = path_name
	add_child(path)
	path.create_from_points(points, true)
	path.is_closed_loop = true
	# Apply speed hints for corner braking
	if speed_hints.size() > 0:
		path.speed_hints = speed_hints
	return path

func _spawn_ai_cars() -> void:
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
		ai_car.rotation = car.rotation  # Face the same direction as player

		# Set a random drivetrain
		var drivetrains = ["FWD", "RWD", "AWD"]
		ai_car.drive_type = drivetrains[randi() % drivetrains.size()]

		# Add to scene before setting up (needed for onready vars)
		add_child(ai_car)

		# Setup AI car
		ai_car.surface_manager = surface_manager
		ai_car.tire_marks = _create_tire_marks_for_ai()

		# Create and assign AI controller with difficulty-based paths
		var ai_controller = AIController.new()
		ai_controller.set_difficulty_paths(difficulty_paths)

		# Set difficulty from settings (all AI use same difficulty)
		ai_controller.set_difficulty(selected_ai_difficulty)

		ai_car.set_controller(ai_controller)

		# Set car color for visual distinction
		if ai_car.has_node("Sprite2D"):
			ai_car.get_node("Sprite2D").modulate = ai_colors[i % ai_colors.size()]

		# Register with RaceManager
		RaceManager.register_car(ai_car)

		ai_cars.append(ai_car)

func _create_tire_marks_for_ai() -> Line2D:
	var tire_marks = Line2D.new()
	tire_marks.width = 2
	tire_marks.default_color = Color(0, 0, 0, 0.3)
	add_child(tire_marks)
	return tire_marks

func _input(event: InputEvent) -> void:
	# Pause menu toggle (ESC key)
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return

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

	# Debug keyboard shortcuts for racing line visualization
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				# Toggle all debug lines on/off
				if debug_drawer:
					debug_drawer.toggle_all()
			KEY_F2:
				# Cycle through individual lines
				if debug_drawer:
					debug_drawer.cycle_lines()
			KEY_F3:
				# Toggle boundary lines
				if debug_drawer:
					debug_drawer.toggle_boundaries()
			KEY_F4:
				# Print debug legend
				if debug_drawer:
					print(debug_drawer.get_legend())
			KEY_F5:
				# Hot-reload all configs
				ConfigManager.reload_all()
				_load_from_config()
				if surface_manager:
					surface_manager.reload_from_config()

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
	get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")

func _toggle_pause() -> void:
	# Don't pause during countdown or after race finished
	if not RaceManager.is_racing():
		return

	if get_tree().paused:
		pause_menu.hide_pause()
	else:
		pause_menu.show_pause()

func _on_pause_resume() -> void:
	# Called when resume button is pressed (pause already hidden by pause_menu)
	pass

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
