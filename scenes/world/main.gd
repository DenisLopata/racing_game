extends Node2D

const CountdownOverlayScene = preload("res://scenes/UI/countdown_overlay.tscn")
const ResultsScreenScene = preload("res://scenes/UI/results_screen.tscn")
const CarScene = preload("res://scenes/entites/car.tscn")
const RainEffectScene = preload("res://scenes/effects/rain_effect.tscn")
const FogEffectScene = preload("res://scenes/effects/fog_effect.tscn")
const PauseMenuScene = preload("res://scenes/UI/pause_menu.tscn")
const CheckpointScene = preload("res://scenes/world/checkpoint.tscn")
const CameraShakeScript = preload("res://scripts/camera/camera_shake.gd")
const AchievementPopupScript = preload("res://scenes/UI/achievement_popup.gd")
const GhostCarScene = preload("res://scenes/entities/ghost_car.tscn")
const MinimapScene = preload("res://scenes/UI/minimap.tscn")

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
@onready var pit_stop_zone: PitStopZone = $PitStopZone

var countdown_overlay: CountdownOverlay
var results_screen: ResultsScreen
var pause_menu: CanvasLayer
var achievement_popup: AchievementPopup
var player_car: Car
var ai_cars: Array[Car] = []
var _last_player_position: int = -1

## Time Attack Mode
var is_time_attack: bool = false
var ghost_car: GhostCar = null
var time_attack_track_id: String = ""

## Minimap
var minimap: Minimap = null

## Enhanced HUD elements
var driving_hud: DrivingHUD = null
var circular_tachometer: CircularTachometer = null

## Smart pathfinding components
var track_analyzer: TrackAnalyzer
var line_generator: RacingLineGenerator
var debug_drawer: PathDebugDrawer
var difficulty_paths: Dictionary = {}  # "easy" -> WaypointPath, etc.

## Checkpoint system for lap validation
var checkpoint_system: CheckpointSystem

## Camera zoom settings (loaded from config)
var camera: Camera2D
var camera_shake: CameraShake
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
		# Add camera shake effect
		camera_shake = CameraShake.new()
		camera_shake.name = "CameraShake"
		camera.add_child(camera_shake)

	# Assign player controller to the car
	var player_controller = PlayerController.new()
	car.set_controller(player_controller)
	player_car = car

	# Enable player upgrades on player car
	car.use_player_upgrades = true
	car.refresh_upgrades()

	# Show car stats on speedometer
	if speedometer and car.part_modifiers:
		speedometer.set_car_stats(car.part_modifiers)

	# Initialize gear and RPM display
	if speedometer:
		speedometer.set_gear(1)  # Start in first gear
		speedometer.set_rpm(0.0)

	# Apply player's selected car color
	if PlayerProgress:
		car.get_node("Sprite2D").modulate = PlayerProgress.get_car_color()

	# Register player car with RaceManager
	RaceManager.register_car(car)

	# Analyze track and generate racing lines for AI
	_analyze_track_and_generate_paths()

	# Create checkpoint system for lap validation
	_setup_checkpoint_system()

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

	# Check for Time Attack mode
	is_time_attack = GameSettings.is_time_attack
	if is_time_attack:
		num_ai_opponents = 0  # Solo mode
		_setup_time_attack()

	# Apply weather
	_apply_weather(GameSettings.weather)

## Apply weather effects
func _apply_weather(weather: String) -> void:
	# Use the new weather system
	if surface_manager and surface_manager.has_method("set_weather"):
		surface_manager.set_weather(weather)
		weather_grip_modifier = surface_manager.weather_grip_mult
	else:
		# Fallback to legacy system
		match weather:
			"clear":
				weather_grip_modifier = 1.0
			"rain":
				weather_grip_modifier = 0.7
			"heavy_rain":
				weather_grip_modifier = 0.5
			"fog":
				weather_grip_modifier = 0.95
			"snow":
				weather_grip_modifier = 0.4
			"dry_hot":
				weather_grip_modifier = 1.1
			_:
				weather_grip_modifier = 1.0

		if surface_manager and surface_manager.has_method("set_weather_modifier"):
			surface_manager.set_weather_modifier(weather_grip_modifier)

	# Spawn visual effects based on weather
	match weather:
		"rain", "heavy_rain":
			_spawn_rain_effect()
		"fog":
			_spawn_fog_effect()

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

	# Create achievement popup
	achievement_popup = AchievementPopup.new()
	add_child(achievement_popup)

	# Create minimap
	_setup_minimap()

	# Create enhanced driving HUD elements
	_setup_driving_hud()

	# Connect signals
	car.drift_marks_finished.connect(_on_car_drift_marks_finished)
	car.update_speed.connect(_on_car_update_speed)
	car.gear_changed.connect(_on_car_gear_changed)
	RaceManager.race_state_changed.connect(_on_race_state_changed)
	RaceManager.car_finished.connect(_on_car_finished)

	# Connect camera shake to damage system (player car only)
	if DamageSystem and camera_shake:
		DamageSystem.damage_taken.connect(_on_damage_for_shake)

	# Connect pit stop zone to speedometer for UI updates
	if pit_stop_zone and speedometer:
		speedometer.set_player_car(car)
		speedometer.connect_pit_stop_zone(pit_stop_zone)

	# Start countdown after a short delay
	await get_tree().create_timer(0.5).timeout
	RaceManager.start_countdown()

func _setup_item_spawns() -> void:
	if not ItemManager or not line_generator:
		return

	# Don't spawn items in Time Attack mode
	if is_time_attack:
		return

	var racing_line = line_generator.center_line
	if racing_line.size() < 10:
		return

	# Place 4-6 item spawn points evenly around the track
	var num_spawns = 5
	var spawn_points: Array[Vector2] = []

	for i in num_spawns:
		var progress = float(i) / float(num_spawns)
		var point_index = int(progress * racing_line.size())
		var spawn_pos = racing_line[point_index]

		# Offset slightly from racing line (alternate sides)
		var next_index = (point_index + 1) % racing_line.size()
		var direction = (racing_line[next_index] - spawn_pos).normalized()
		var perpendicular = direction.rotated(PI / 2)
		var offset = perpendicular * (30.0 if i % 2 == 0 else -30.0)

		spawn_points.append(spawn_pos + offset)

	ItemManager.setup_spawn_points(spawn_points)
	print("[Main] Set up %d item spawn points" % spawn_points.size())

func _setup_minimap() -> void:
	minimap = MinimapScene.instantiate() as Minimap
	minimap.name = "Minimap"

	# Position in top-right corner
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.anchor_top = 0.0
	minimap.anchor_bottom = 0.0
	minimap.offset_left = -160
	minimap.offset_right = -10
	minimap.offset_top = 10
	minimap.offset_bottom = 160

	# Add to a CanvasLayer so it stays on screen
	var minimap_layer = CanvasLayer.new()
	minimap_layer.name = "MinimapLayer"
	minimap_layer.layer = 10
	add_child(minimap_layer)
	minimap_layer.add_child(minimap)

	# Set player car reference
	minimap.set_player_car(player_car)

	# Track data will be set after track analysis in _analyze_track_and_generate_paths

func _setup_driving_hud() -> void:
	# Create a canvas layer for the driving HUD
	var hud_layer = CanvasLayer.new()
	hud_layer.name = "DrivingHUDLayer"
	hud_layer.layer = 5
	add_child(hud_layer)

	# Create driving HUD (drift info, weight transfer, etc.)
	driving_hud = DrivingHUD.new()
	driving_hud.name = "DrivingHUD"
	driving_hud.anchor_right = 1.0
	driving_hud.anchor_bottom = 1.0
	hud_layer.add_child(driving_hud)

	# Create circular tachometer (bottom-right, above speedometer)
	circular_tachometer = CircularTachometer.new()
	circular_tachometer.name = "CircularTachometer"
	circular_tachometer.anchor_left = 1.0
	circular_tachometer.anchor_right = 1.0
	circular_tachometer.anchor_top = 1.0
	circular_tachometer.anchor_bottom = 1.0
	circular_tachometer.offset_left = -130
	circular_tachometer.offset_right = -10
	circular_tachometer.offset_top = -130
	circular_tachometer.offset_bottom = -50
	circular_tachometer.radius = 45.0
	hud_layer.add_child(circular_tachometer)

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

	# 5. Setup minimap with track outline
	if minimap and line_generator:
		minimap.setup_track(line_generator.center_line)

	# 6. Setup item spawn points on track
	_setup_item_spawns()

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

## Setup checkpoint system with checkpoints placed around the track
func _setup_checkpoint_system() -> void:
	# Create checkpoint system
	checkpoint_system = CheckpointSystem.new()
	checkpoint_system.name = "CheckpointSystem"
	add_child(checkpoint_system)

	# Get racing line points to determine checkpoint positions
	var racing_line = line_generator.center_line if line_generator else PackedVector2Array()
	if racing_line.size() < 4:
		return

	# Get boundaries to calculate track width at each point
	var outer_boundary = track_analyzer.tiles_to_world(track_analyzer.get_outer_boundary())
	var inner_boundary = track_analyzer.tiles_to_world(track_analyzer.get_inner_boundary())

	# Place 3 checkpoints at 25%, 50%, 75% of the track
	var num_checkpoints = 3
	for i in num_checkpoints:
		var progress = float(i + 1) / float(num_checkpoints + 1)
		var point_index = int(progress * racing_line.size())
		var checkpoint_pos = racing_line[point_index]

		# Calculate track width at this position using boundaries
		var track_width = _get_track_width_at_index(point_index, outer_boundary, inner_boundary)

		# Get direction for rotation (perpendicular to track)
		var next_index = (point_index + 1) % racing_line.size()
		var direction = (racing_line[next_index] - checkpoint_pos).normalized()
		var rotation = direction.angle()

		_create_checkpoint(i, checkpoint_pos, track_width, rotation)

	# Connect checkpoint system to start line
	var start_line = $StartLine
	if start_line and "checkpoint_system" in start_line:
		start_line.checkpoint_system = checkpoint_system

## Get the track width at a specific index along the racing line
func _get_track_width_at_index(index: int, outer: PackedVector2Array, inner: PackedVector2Array) -> float:
	if outer.size() == 0 or inner.size() == 0:
		return 300.0  # Default fallback

	# Map racing line index to boundary index (they have same sample count)
	var boundary_index = index % outer.size()
	var outer_point = outer[boundary_index]
	var inner_point = inner[boundary_index]

	# Calculate width with some padding
	return outer_point.distance_to(inner_point) + 50.0

## Create a single checkpoint at the given position
func _create_checkpoint(index: int, position: Vector2, width: float = 200.0, rotation_angle: float = 0.0) -> void:
	var checkpoint = Checkpoint.new()
	checkpoint.name = "Checkpoint_%d" % index
	checkpoint.checkpoint_index = index
	checkpoint.position = position
	checkpoint.rotation = rotation_angle + PI / 2  # Perpendicular to track direction

	# Create collision shape spanning the track width
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, 40)
	collision.shape = shape
	checkpoint.add_child(collision)

	# Add debug visualization
	var debug_rect = ColorRect.new()
	debug_rect.size = Vector2(width, 40)
	debug_rect.position = Vector2(-width / 2, -20)  # Center the rect
	debug_rect.color = Color(1.0, 0.5, 0.0, 0.5)  # Orange semi-transparent
	checkpoint.add_child(debug_rect)

	# Add label showing checkpoint number
	var label = Label.new()
	label.text = "CP %d" % index
	label.position = Vector2(-20, -50)
	label.rotation = -checkpoint.rotation  # Counter-rotate so text stays upright
	label.add_theme_color_override("font_color", Color.WHITE)
	checkpoint.add_child(label)

	# Add to checkpoint system
	checkpoint_system.add_child(checkpoint)
	checkpoint_system.add_checkpoint(checkpoint)

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

	# Update minimap with AI cars
	if minimap:
		minimap.set_ai_cars(ai_cars)

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
		_update_driving_hud()

func _update_position_display() -> void:
	var total_cars = RaceManager.registered_cars.size()
	var player_position = RaceManager.get_car_position(player_car)

	if player_position > 0:
		speedometer.set_race_position(player_position, total_cars)

		# Notify achievement manager of position changes
		if player_position != _last_player_position and AchievementManager:
			AchievementManager.on_position_changed(player_position, total_cars)
		_last_player_position = player_position

	# Update lap display
	var player_data = RaceManager.get_car_lap_data(player_car.car_id)
	if player_data.size() > 0:
		var current_lap = player_data.get("laps", 0) + 1
		speedometer.set_total_laps(current_lap, RaceManager.total_laps)

func _update_driving_hud() -> void:
	if not player_car:
		return

	# Update circular tachometer
	if circular_tachometer:
		var rpm = player_car.get_rpm_percent()
		var gear = player_car.get_current_gear()
		circular_tachometer.set_rpm_gear(rpm, gear)

	# Update driving HUD
	if driving_hud:
		# Update drift display
		driving_hud.update_drift(
			player_car.current_slip_angle,
			player_car.is_drifting,
			player_car.velocity.length()
		)

		# Update handbrake indicator
		driving_hud.update_handbrake(player_car.is_handbrake_active)

		# Update weight transfer display
		var weight_data = player_car.get_weight_transfer_data()
		driving_hud.update_weight_transfer(
			weight_data.front,
			weight_data.rear,
			weight_data.left,
			weight_data.right
		)

		# Update slip angle debug (if visible)
		driving_hud.update_slip_angle(player_car.current_slip_angle)

func _on_race_state_changed(new_state: RaceManager.RaceState) -> void:
	match new_state:
		RaceManager.RaceState.RACING:
			# Race started - initialize UI
			speedometer.set_total_laps(1, RaceManager.total_laps)
			speedometer.set_race_position(1, RaceManager.registered_cars.size())
			# Start time attack recording
			_on_time_attack_lap_start()
		RaceManager.RaceState.FINISHED:
			# Race finished - show results
			if is_time_attack:
				TimeAttackManager.end_time_attack()
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

		# Award race rewards
		var reward = PlayerProgress.complete_race(position)
		print("Earned %d credits! (Total: %d, Wins: %d)" % [reward, PlayerProgress.currency, PlayerProgress.wins])

		# Force finish race when player finishes (or wait for all)
		RaceManager.force_finish_race()

func _on_lap_tracker_lap_completed(lap_number: int, lap_time: float) -> void:
	speedometer.set_lap(str(lap_number))
	speedometer.set_lap_time("%.2f" % lap_time)

	# Process time attack lap completion
	if is_time_attack:
		_on_time_attack_lap_complete(lap_time)
	
func _on_lap_tracker_race_finished(lap_times: Array) -> void:
	#speedometer.set_speed(speed)
	pass
	
func _on_car_update_speed(speed: String) -> void:
	speedometer.set_speed(speed)

	# Update RPM display if player car has transmission
	if player_car and player_car.transmission:
		var rpm_percent = player_car.transmission.get_rpm_percent()
		speedometer.set_rpm(rpm_percent)

func _on_car_gear_changed(gear: int) -> void:
	if speedometer:
		speedometer.set_gear(gear)
	
func _on_car_drift_marks_finished(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return

	var skid = Line2D.new()
	skid.width = 2
	skid.default_color = Color(0,0,0,0.6) # dark grey
	skid.points = points.duplicate()      # copy so it doesn't get cleared
	skid.modulate.a = 0.2;
	skid.width = 10;
	add_child(skid)

	# Optional: move to a dedicated "Skidmarks" Node2D layer
	#$Skidmarks.add_child(skid)

func _on_damage_for_shake(damaged_car: Node, _part: String, _amount: float, _new_health: float) -> void:
	# Only shake camera for player car damage
	if damaged_car != player_car or not camera_shake:
		return

	# Get impact speed from car velocity
	var impact_speed = player_car.velocity.length()
	var intensity = CameraShake.intensity_from_speed(impact_speed)

	if intensity > 0:
		camera_shake.shake(intensity)

# =============================================================================
# Time Attack Mode
# =============================================================================

func _setup_time_attack() -> void:
	if not TimeAttackManager:
		return

	# Determine track ID
	if GameSettings.is_procedural_track:
		time_attack_track_id = "procedural_%d" % GameSettings.procedural_seed
	else:
		time_attack_track_id = GameSettings.selected_track

	# Initialize time attack mode
	TimeAttackManager.start_time_attack(time_attack_track_id)

	# Spawn ghost car if we have a best time
	if TimeAttackManager.has_ghost():
		_spawn_ghost_car()

	# Update UI to show best time
	if speedometer:
		var best_time = TimeAttackManager.get_best_time()
		if best_time > 0:
			speedometer.set_best_lap_time(best_time)

func _spawn_ghost_car() -> void:
	ghost_car = GhostCarScene.instantiate() as GhostCar
	ghost_car.name = "GhostCar"
	ghost_car.initialize(TimeAttackManager)
	add_child(ghost_car)
	print("[Main] Spawned ghost car for Time Attack")

func _physics_process(delta: float) -> void:
	# Record player position for time attack ghost
	if is_time_attack and TimeAttackManager and player_car:
		TimeAttackManager.process_recording(player_car, delta)

func _on_time_attack_lap_start() -> void:
	if not is_time_attack or not TimeAttackManager:
		return

	# Start recording new lap
	TimeAttackManager.start_lap_recording(player_car)

	# Start ghost playback
	if ghost_car:
		ghost_car.start_playback()

func _on_time_attack_lap_complete(lap_time: float) -> void:
	if not is_time_attack or not TimeAttackManager:
		return

	# Finish recording and check for new best
	var is_new_best = TimeAttackManager.finish_lap_recording(lap_time)

	if is_new_best:
		print("[Main] NEW BEST LAP: %.3f" % lap_time)
		# Show notification
		if speedometer:
			speedometer.show_new_best_notification()
			speedometer.set_best_lap_time(lap_time)

		# Spawn/update ghost car
		if not ghost_car:
			_spawn_ghost_car()

	# Start recording next lap
	TimeAttackManager.start_lap_recording(player_car)
	if ghost_car:
		ghost_car.start_playback()
