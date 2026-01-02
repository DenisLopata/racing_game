class_name GhostCar
extends Node2D
## Visual representation of a recorded lap for ghost racing

@export var ghost_color: Color = Color(0.5, 0.8, 1.0, 0.4)  # Translucent blue
@export var ghost_size: Vector2 = Vector2(30, 15)  # Match car size

var time_attack_manager = null  # TimeAttackManager reference
var is_active: bool = false
var sprite: Sprite2D = null
var trail_particles: GPUParticles2D = null

func _ready() -> void:
	_create_visual()

func _create_visual() -> void:
	# Create a simple rectangle sprite for ghost
	sprite = Sprite2D.new()
	sprite.name = "GhostSprite"

	# Create a simple colored texture
	var image = Image.create(int(ghost_size.x), int(ghost_size.y), false, Image.FORMAT_RGBA8)
	image.fill(ghost_color)
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

	add_child(sprite)

	# Add subtle trail effect
	_create_trail()

func _create_trail() -> void:
	trail_particles = GPUParticles2D.new()
	trail_particles.name = "TrailParticles"
	trail_particles.amount = 20
	trail_particles.lifetime = 0.5
	trail_particles.local_coords = false
	trail_particles.emitting = false

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0, 0, 0)
	material.spread = 0.0
	material.initial_velocity_min = 0.0
	material.initial_velocity_max = 0.0
	material.gravity = Vector3.ZERO
	material.scale_min = 0.5
	material.scale_max = 1.0
	material.color = Color(ghost_color.r, ghost_color.g, ghost_color.b, 0.2)

	trail_particles.process_material = material
	add_child(trail_particles)

## Initialize with a TimeAttackManager reference
func initialize(manager) -> void:
	time_attack_manager = manager

## Start ghost playback
func start_playback() -> void:
	if not time_attack_manager or not time_attack_manager.has_ghost():
		visible = false
		is_active = false
		return

	visible = true
	is_active = true
	time_attack_manager.start_ghost_playback()

	if trail_particles:
		trail_particles.emitting = true

	print("[GhostCar] Started playback")

## Stop ghost playback
func stop_playback() -> void:
	is_active = false
	visible = false

	if trail_particles:
		trail_particles.emitting = false

func _physics_process(delta: float) -> void:
	if not is_active or not time_attack_manager:
		return

	var ghost_state = time_attack_manager.update_ghost_playback(delta)
	if ghost_state.is_empty():
		return

	global_position = ghost_state.get("position", Vector2.ZERO)
	rotation = ghost_state.get("rotation", 0.0)

	# Loop playback when ghost finishes
	if ghost_state.get("finished", false):
		time_attack_manager.start_ghost_playback()

## Set ghost opacity
func set_opacity(alpha: float) -> void:
	ghost_color.a = alpha
	if sprite and sprite.texture:
		var image = Image.create(int(ghost_size.x), int(ghost_size.y), false, Image.FORMAT_RGBA8)
		image.fill(ghost_color)
		sprite.texture = ImageTexture.create_from_image(image)
