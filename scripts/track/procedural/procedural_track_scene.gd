extends Node2D
## Procedural Track Scene - Generates track at runtime and runs race

const CountdownOverlayScene = preload("res://scenes/UI/countdown_overlay.tscn")
const ResultsScreenScene = preload("res://scenes/UI/results_screen.tscn")
const CarScene = preload("res://scenes/entites/car.tscn")
const RainEffectScene = preload("res://scenes/effects/rain_effect.tscn")
const FogEffectScene = preload("res://scenes/effects/fog_effect.tscn")
const PauseMenuScene = preload("res://scenes/UI/pause_menu.tscn")
const CheckpointScene = preload("res://scenes/world/checkpoint.tscn")
const StartLineScene = preload("res://scenes/world/start_line.tscn")

## Number of AI opponents
@export var num_ai_opponents: int = 7

## Starting grid configuration (calculated after generation)
var grid_start_position: Vector2 = Vector2(400, 400)
var grid_start_direction: Vector2 = Vector2.UP
var grid_row_spacing: float = 40.0
var grid_column_offset: float = 30.0

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var surface_manager: SurfaceManager = $SurfaceManager
@onready var lap_tracker: LapTracker = $LapTracker
@onready var tire_marks_line_2d: Line2D = $TireMarksLine2D
@onready var car: Car = $Car
@onready var speedometer: Speedometer = %Speedometer

var countdown_overlay: CountdownOverlay
var results_screen: ResultsScreen
var pause_menu: CanvasLayer
var player_car: Car
var ai_cars: Array[Car] = []
var start_line: Area2D

## Procedural generation components
var track_generator: TrackGenerator
var terrain_generator: TerrainGenerator

## Smart pathfinding components (existing systems)
var track_analyzer: TrackAnalyzer
var line_generator: RacingLineGenerator
var debug_drawer: PathDebugDrawer
var difficulty_paths: Dictionary = {}

## Checkpoint system
var checkpoint_system: CheckpointSystem

## Camera
var camera: Camera2D
var zoom_level: float = 1.0
var ZOOM_MIN: float = 0.2
var ZOOM_MAX: float = 2.0
var ZOOM_SPEED: float = 0.1

## AI colors
var ai_colors: Array[Color] = []

## Weather
var weather_grip_modifier: float = 1.0

## AI difficulty
var selected_ai_difficulty: String = "medium"

## Generation settings
var generation_seed: int = 0
var track_size: TrackGenerator.TrackSize = TrackGenerator.TrackSize.MEDIUM
var track_difficulty: TrackGenerator.Difficulty = TrackGenerator.Difficulty.MODERATE

func _ready() -> void:
	# Reset RaceManager state
	RaceManager.full_reset()

	# Load configuration
	_load_from_config()

	# Load procedural settings from GameSettings
	_load_generation_settings()

	# Generate the track
	_generate_track()

	# Apply game settings (laps, opponents, weather, difficulty)
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

	# Grid settings will be calculated after track generation
	grid_row_spacing = 40.0
	grid_column_offset = 30.0

func _load_generation_settings() -> void:
	# Load from GameSettings if available
	if has_node("/root/GameSettings"):
		generation_seed = GameSettings.procedural_seed
		track_size = GameSettings.procedural_size as TrackGenerator.TrackSize
		track_difficulty = GameSettings.procedural_difficulty as TrackGenerator.Difficulty

	# Use random seed if not specified
	if generation_seed == 0:
		generation_seed = randi()
		if has_node("/root/GameSettings"):
			GameSettings.procedural_seed = generation_seed

	print("[ProceduralTrack] Generating with seed: %d, size: %d, difficulty: %d" % [
		generation_seed, track_size, track_difficulty
	])

func _generate_track() -> void:
	# 1. Generate track shape
	track_generator = TrackGenerator.new()
	track_generator.generate(generation_seed, track_size, track_difficulty)

	# 2. Generate terrain zones
	var map_size = track_generator.get_map_size()
	terrain_generator = TerrainGenerator.new()
	terrain_generator.setup(track_generator.rng, map_size.x, map_size.y)
	terrain_generator.generate_zones(5)

	# 3. Paint the tilemap
	terrain_generator.paint_tilemap(
		tile_map_layer,
		track_generator.get_spline_points(),
		track_generator.get_track_widths()
	)

	# 4. Find and create start line
	var start_info = track_generator.find_start_line_position()
	grid_start_position = start_info["position"]
	grid_start_direction = start_info["direction"]
	_create_start_line(start_info)

	# 5. Analyze track using existing TrackAnalyzer
	track_analyzer = TrackAnalyzer.new()
	track_analyzer.analyze(tile_map_layer, grid_start_position)

	# 6. Generate racing lines using existing RacingLineGenerator
	line_generator = RacingLineGenerator.new()
	line_generator.generate(track_analyzer, tile_map_layer)

	# 7. Create waypoint paths for AI
	difficulty_paths = {
		"expert": _create_waypoint_path_from_points(line_generator.optimal_line, "ExpertPath", line_generator.optimal_speed_hints),
		"hard": _create_waypoint_path_from_points(line_generator.racing_line, "HardPath", line_generator.racing_speed_hints),
		"medium": _create_waypoint_path_from_points(line_generator.center_line, "MediumPath", line_generator.center_speed_hints),
		"easy": _create_waypoint_path_from_points(line_generator.wide_line, "EasyPath", line_generator.wide_speed_hints)
	}

	# 8. Create debug drawer
	debug_drawer = PathDebugDrawer.new()
	debug_drawer.name = "PathDebugDrawer"
	add_child(debug_drawer)
	debug_drawer.setup(line_generator)

	# 9. Setup checkpoint system
	_setup_checkpoint_system()

	# 10. Setup player car
	_setup_player_car()

	# 11. Spawn AI cars
	_spawn_ai_cars()

	# 12. Setup race UI
	_setup_race_ui()

func _create_start_line(start_info: Dictionary) -> void:
	start_line = StartLineScene.instantiate()
	start_line.name = "StartLine"
	start_line.position = start_info["position"]

	# Rotate perpendicular to track direction
	var direction = start_info["direction"]
	start_line.rotation = direction.angle() + PI / 2

	# Scale collision shape based on track width
	var track_width = start_info.get("width", 5.0) * terrain_generator.tile_size
	var collision = start_line.get_node_or_null("CollisionShape2D")
	if collision and collision.shape is RectangleShape2D:
		collision.shape.size.x = track_width + 50

	add_child(start_line)

func _create_waypoint_path_from_points(points: PackedVector2Array, path_name: String, speed_hints: Array[float] = []) -> WaypointPath:
	var path = WaypointPath.new()
	path.name = path_name
	add_child(path)
	path.create_from_points(points, true)
	path.is_closed_loop = true
	if speed_hints.size() > 0:
		path.speed_hints = speed_hints
	return path

func _setup_checkpoint_system() -> void:
	checkpoint_system = CheckpointSystem.new()
	checkpoint_system.name = "CheckpointSystem"
	add_child(checkpoint_system)

	var racing_line = line_generator.center_line if line_generator else PackedVector2Array()
	if racing_line.size() < 4:
		return

	var outer_boundary = track_analyzer.tiles_to_world(track_analyzer.get_outer_boundary())
	var inner_boundary = track_analyzer.tiles_to_world(track_analyzer.get_inner_boundary())

	# Place 3 checkpoints at 25%, 50%, 75%
	var num_checkpoints = 3
	for i in num_checkpoints:
		var progress = float(i + 1) / float(num_checkpoints + 1)
		var point_index = int(progress * racing_line.size())
		var checkpoint_pos = racing_line[point_index]

		var track_width = _get_track_width_at_index(point_index, outer_boundary, inner_boundary)

		var next_index = (point_index + 1) % racing_line.size()
		var direction = (racing_line[next_index] - checkpoint_pos).normalized()
		var rotation_angle = direction.angle()

		_create_checkpoint(i, checkpoint_pos, track_width, rotation_angle)

	# Connect checkpoint system to start line
	if start_line and "checkpoint_system" in start_line:
		start_line.checkpoint_system = checkpoint_system

func _get_track_width_at_index(index: int, outer: PackedVector2Array, inner: PackedVector2Array) -> float:
	if outer.size() == 0 or inner.size() == 0:
		return 300.0

	var boundary_index = index % outer.size()
	var outer_point = outer[boundary_index]
	var inner_point = inner[boundary_index]

	return outer_point.distance_to(inner_point) + 50.0

func _create_checkpoint(index: int, checkpoint_pos: Vector2, width: float, rotation_angle: float) -> void:
	var checkpoint = Checkpoint.new()
	checkpoint.name = "Checkpoint_%d" % index
	checkpoint.checkpoint_index = index
	checkpoint.position = checkpoint_pos
	checkpoint.rotation = rotation_angle + PI / 2

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, 40)
	collision.shape = shape
	checkpoint.add_child(collision)

	var debug_rect = ColorRect.new()
	debug_rect.size = Vector2(width, 40)
	debug_rect.position = Vector2(-width / 2, -20)
	debug_rect.color = Color(1.0, 0.5, 0.0, 0.5)
	checkpoint.add_child(debug_rect)

	var label = Label.new()
	label.text = "CP %d" % index
	label.position = Vector2(-20, -50)
	label.rotation = -checkpoint.rotation
	label.add_theme_color_override("font_color", Color.WHITE)
	checkpoint.add_child(label)

	checkpoint_system.add_child(checkpoint)
	checkpoint_system.add_checkpoint(checkpoint)

func _setup_player_car() -> void:
	car.tire_marks = tire_marks_line_2d
	car.surface_manager = surface_manager

	# Position car at start line
	car.global_position = grid_start_position
	car.rotation = grid_start_direction.angle() - PI / 2

	# Get camera for zoom
	camera = car.get_node_or_null("Camera2D")
	if camera:
		zoom_level = camera.zoom.x

	# Assign player controller
	var player_controller = PlayerController.new()
	car.set_controller(player_controller)
	player_car = car

	# Enable player upgrades
	car.use_player_upgrades = true
	car.refresh_upgrades()

	# Show car stats on speedometer
	if speedometer and car.part_modifiers:
		speedometer.set_car_stats(car.part_modifiers)

	# Apply player's selected car color
	if PlayerProgress:
		car.get_node("Sprite2D").modulate = PlayerProgress.get_car_color()

	# Register with RaceManager
	RaceManager.register_car(car)

func _apply_game_settings() -> void:
	if not has_node("/root/GameSettings"):
		return

	RaceManager.total_laps = GameSettings.lap_count
	num_ai_opponents = GameSettings.opponent_count
	selected_ai_difficulty = GameSettings.ai_difficulty

	_apply_weather(GameSettings.weather)

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

	if surface_manager and surface_manager.has_method("set_weather_modifier"):
		surface_manager.set_weather_modifier(weather_grip_modifier)

func _spawn_rain_effect() -> void:
	var rain = RainEffectScene.instantiate()
	add_child(rain)

func _spawn_fog_effect() -> void:
	var fog = FogEffectScene.instantiate()
	add_child(fog)

func _setup_race_ui() -> void:
	countdown_overlay = CountdownOverlayScene.instantiate()
	add_child(countdown_overlay)

	results_screen = ResultsScreenScene.instantiate()
	results_screen.restart_requested.connect(_on_restart_requested)
	results_screen.quit_requested.connect(_on_quit_requested)
	add_child(results_screen)

	pause_menu = PauseMenuScene.instantiate()
	pause_menu.resume_requested.connect(_on_pause_resume)
	pause_menu.restart_requested.connect(_on_restart_requested)
	pause_menu.quit_requested.connect(_on_quit_requested)
	add_child(pause_menu)

	car.drift_marks_finished.connect(_on_car_drift_marks_finished)
	car.update_speed.connect(_on_car_update_speed)
	RaceManager.race_state_changed.connect(_on_race_state_changed)
	RaceManager.car_finished.connect(_on_car_finished)

	await get_tree().create_timer(0.5).timeout
	RaceManager.start_countdown()

func _spawn_ai_cars() -> void:
	for i in num_ai_opponents:
		var ai_car = CarScene.instantiate() as Car
		ai_car.name = "AICar_%d" % i

		# Calculate grid position (staggered 2-wide grid)
		var row = (i + 1)
		var col = (i + 1) % 2
		var perpendicular = Vector2(-grid_start_direction.y, grid_start_direction.x)
		var grid_pos = grid_start_position + \
			grid_start_direction * row * grid_row_spacing + \
			perpendicular * (col * grid_column_offset - grid_column_offset * 0.5)

		ai_car.global_position = grid_pos
		ai_car.rotation = grid_start_direction.angle() - PI / 2

		var drivetrains = ["FWD", "RWD", "AWD"]
		ai_car.drive_type = drivetrains[randi() % drivetrains.size()]

		add_child(ai_car)

		ai_car.surface_manager = surface_manager
		ai_car.tire_marks = _create_tire_marks_for_ai()

		var ai_controller = AIController.new()
		ai_controller.set_difficulty_paths(difficulty_paths)
		ai_controller.set_difficulty(selected_ai_difficulty)
		ai_car.set_controller(ai_controller)

		if ai_car.has_node("Sprite2D"):
			ai_car.get_node("Sprite2D").modulate = ai_colors[i % ai_colors.size()]

		RaceManager.register_car(ai_car)
		ai_cars.append(ai_car)

func _create_tire_marks_for_ai() -> Line2D:
	var tire_marks = Line2D.new()
	tire_marks.width = 2
	tire_marks.default_color = Color(0, 0, 0, 0.3)
	add_child(tire_marks)
	return tire_marks

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_level = clamp(zoom_level + ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
			if camera:
				camera.zoom = Vector2(zoom_level, zoom_level)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_level = clamp(zoom_level - ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
			if camera:
				camera.zoom = Vector2(zoom_level, zoom_level)

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				if debug_drawer:
					debug_drawer.toggle_all()
			KEY_F2:
				if debug_drawer:
					debug_drawer.cycle_lines()
			KEY_F3:
				if debug_drawer:
					debug_drawer.toggle_boundaries()
			KEY_F4:
				if debug_drawer:
					print(debug_drawer.get_legend())
				print("Seed: %d" % generation_seed)
			KEY_F5:
				ConfigManager.reload_all()
				_load_from_config()
				if surface_manager:
					surface_manager.reload_from_config()

func _process(_delta: float) -> void:
	if RaceManager.is_racing():
		_update_position_display()

func _update_position_display() -> void:
	var total_cars = RaceManager.registered_cars.size()
	var player_position = RaceManager.get_car_position(player_car)

	if player_position > 0:
		speedometer.set_race_position(player_position, total_cars)

	var player_data = RaceManager.get_car_lap_data(player_car.car_id)
	if player_data.size() > 0:
		var current_lap = player_data.get("laps", 0) + 1
		speedometer.set_total_laps(current_lap, RaceManager.total_laps)

func _on_race_state_changed(new_state: RaceManager.RaceState) -> void:
	match new_state:
		RaceManager.RaceState.RACING:
			speedometer.set_total_laps(1, RaceManager.total_laps)
			speedometer.set_race_position(1, RaceManager.registered_cars.size())
		RaceManager.RaceState.FINISHED:
			_show_results()

func _show_results() -> void:
	var results = RaceManager.get_race_results()
	print("=== RACE RESULTS (Seed: %d) ===" % generation_seed)
	for result in results:
		var car_name = "Player" if result["car"] == player_car else result["car"].name
		print("P%d: %s - Time: %.2f - Best Lap: %.2f" % [
			result["position"],
			car_name,
			result["total_time"],
			result["best_lap"]
		])

	results_screen.show_results(results, player_car)

func _on_restart_requested() -> void:
	get_tree().reload_current_scene()

func _on_quit_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")

func _toggle_pause() -> void:
	if not RaceManager.is_racing():
		return

	if get_tree().paused:
		pause_menu.hide_pause()
	else:
		pause_menu.show_pause()

func _on_pause_resume() -> void:
	pass

func _on_car_finished(finished_car: Car, race_position: int, total_time: float) -> void:
	if finished_car == player_car:
		print("Player finished in position %d with time %.2f" % [race_position, total_time])

		var reward = PlayerProgress.complete_race(race_position)
		print("Earned %d credits! (Total: %d, Wins: %d)" % [reward, PlayerProgress.currency, PlayerProgress.wins])

		RaceManager.force_finish_race()

func _on_car_update_speed(speed: String) -> void:
	speedometer.set_speed(speed)

func _on_car_drift_marks_finished(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return

	var skid = Line2D.new()
	skid.width = 2
	skid.default_color = Color(0, 0, 0, 0.6)
	skid.points = points.duplicate()
	skid.modulate.a = 0.2
	skid.width = 10
	add_child(skid)

## Get the current track seed (for saving/sharing)
func get_track_seed() -> int:
	return generation_seed
