## ItemManager autoload - do not add class_name (causes conflicts with autoload)
extends Node
## Manages power-up items on the track - spawning, collection, and effects

signal item_collected(car: Node, item_type: String)
signal item_effect_started(car: Node, item_type: String, duration: float)
signal item_effect_ended(car: Node, item_type: String)

# Item types and their properties
const ITEM_TYPES: Dictionary = {
	"boost": {
		"name": "Speed Boost",
		"description": "30% speed increase for 2 seconds",
		"color": Color.ORANGE,
		"duration": 2.0,
		"respawn_time": 10.0
	},
	"shield": {
		"name": "Shield",
		"description": "Blocks one collision's damage",
		"color": Color.CYAN,
		"duration": 8.0,  # Or until hit
		"respawn_time": 15.0
	},
	"repair": {
		"name": "Repair Kit",
		"description": "Restore 25% to most damaged part",
		"color": Color.GREEN,
		"duration": 0.0,  # Instant effect
		"respawn_time": 20.0
	}
}

# Active items on track
var spawn_points: Array[Vector2] = []
var active_pickups: Array[Node] = []
var respawn_timers: Dictionary = {}  # spawn_index -> timer

# Active effects on cars
var car_effects: Dictionary = {}  # car -> {item_type -> {timer, data}}

# Preloaded scenes
var pickup_scene: PackedScene = null

func _ready() -> void:
	# Create pickup scene dynamically since we're building it in code
	pass

func _process(delta: float) -> void:
	_update_respawn_timers(delta)
	_update_active_effects(delta)

## Initialize item spawns on track
func setup_spawn_points(points: Array[Vector2]) -> void:
	spawn_points = points
	respawn_timers.clear()

	# Spawn initial items
	for i in spawn_points.size():
		_spawn_item_at_index(i)

## Spawn an item at a specific spawn point
func _spawn_item_at_index(index: int) -> void:
	if index >= spawn_points.size():
		return

	var position = spawn_points[index]

	# Choose random item type
	var types = ITEM_TYPES.keys()
	var item_type = types[randi() % types.size()]

	var pickup = _create_pickup(item_type, position, index)
	active_pickups.append(pickup)
	add_child(pickup)

## Create a pickup node
func _create_pickup(item_type: String, position: Vector2, spawn_index: int) -> Area2D:
	var pickup = Area2D.new()
	pickup.name = "Pickup_%s_%d" % [item_type, spawn_index]
	pickup.position = position
	pickup.collision_layer = 0
	pickup.collision_mask = 1  # Detect cars
	pickup.set_meta("item_type", item_type)
	pickup.set_meta("spawn_index", spawn_index)

	# Collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	collision.shape = shape
	pickup.add_child(collision)

	# Visual representation
	var visual = _create_item_visual(item_type)
	pickup.add_child(visual)

	# Connect signal
	pickup.body_entered.connect(_on_pickup_collected.bind(pickup))

	return pickup

## Create visual for item pickup
func _create_item_visual(item_type: String) -> Node2D:
	var visual = Node2D.new()
	visual.name = "Visual"

	var item_data = ITEM_TYPES.get(item_type, {})
	var color = item_data.get("color", Color.WHITE)

	# Outer glow circle
	var glow = _create_circle_sprite(25.0, Color(color.r, color.g, color.b, 0.3))
	glow.name = "Glow"
	visual.add_child(glow)

	# Inner solid circle
	var inner = _create_circle_sprite(15.0, color)
	inner.name = "Inner"
	visual.add_child(inner)

	# Icon indicator (simple shape based on type)
	var icon = _create_item_icon(item_type)
	visual.add_child(icon)

	# Add floating animation
	var tween = visual.create_tween()
	tween.set_loops()
	tween.tween_property(visual, "position:y", -5.0, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(visual, "position:y", 5.0, 0.5).set_ease(Tween.EASE_IN_OUT)

	return visual

func _create_circle_sprite(radius: float, color: Color) -> Sprite2D:
	var sprite = Sprite2D.new()
	var image = Image.create(int(radius * 2), int(radius * 2), false, Image.FORMAT_RGBA8)

	# Draw circle
	var center = Vector2(radius, radius)
	for x in int(radius * 2):
		for y in int(radius * 2):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				var alpha = 1.0 - (dist / radius) * 0.3  # Slight gradient
				image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))

	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = true
	return sprite

func _create_item_icon(item_type: String) -> Node2D:
	var icon = Node2D.new()
	icon.name = "Icon"

	# Simple shape indicators
	match item_type:
		"boost":
			# Arrow pointing up
			var arrow = Polygon2D.new()
			arrow.polygon = PackedVector2Array([
				Vector2(0, -8), Vector2(6, 4), Vector2(0, 0), Vector2(-6, 4)
			])
			arrow.color = Color.WHITE
			icon.add_child(arrow)
		"shield":
			# Shield shape
			var shield = Polygon2D.new()
			shield.polygon = PackedVector2Array([
				Vector2(0, -8), Vector2(7, -4), Vector2(7, 2),
				Vector2(0, 8), Vector2(-7, 2), Vector2(-7, -4)
			])
			shield.color = Color.WHITE
			icon.add_child(shield)
		"repair":
			# Plus sign
			var plus_h = Polygon2D.new()
			plus_h.polygon = PackedVector2Array([
				Vector2(-6, -2), Vector2(6, -2), Vector2(6, 2), Vector2(-6, 2)
			])
			plus_h.color = Color.WHITE
			icon.add_child(plus_h)
			var plus_v = Polygon2D.new()
			plus_v.polygon = PackedVector2Array([
				Vector2(-2, -6), Vector2(2, -6), Vector2(2, 6), Vector2(-2, 6)
			])
			plus_v.color = Color.WHITE
			icon.add_child(plus_v)

	return icon

## Handle pickup collection
func _on_pickup_collected(body: Node, pickup: Area2D) -> void:
	if not body is Car:
		return

	var car = body as Car
	var item_type = pickup.get_meta("item_type")
	var spawn_index = pickup.get_meta("spawn_index")

	# Apply effect
	_apply_item_effect(car, item_type)

	# Remove pickup
	active_pickups.erase(pickup)
	pickup.queue_free()

	# Start respawn timer
	var respawn_time = ITEM_TYPES[item_type].get("respawn_time", 10.0)
	respawn_timers[spawn_index] = respawn_time

	item_collected.emit(car, item_type)
	print("[ItemManager] %s collected %s" % [car.name, item_type])

## Apply item effect to car
func _apply_item_effect(car: Car, item_type: String) -> void:
	var item_data = ITEM_TYPES.get(item_type, {})
	var duration = item_data.get("duration", 0.0)

	match item_type:
		"boost":
			_apply_boost(car, duration)
		"shield":
			_apply_shield(car, duration)
		"repair":
			_apply_repair(car)

func _apply_boost(car: Car, duration: float) -> void:
	# Initialize car effects dict if needed
	if car not in car_effects:
		car_effects[car] = {}

	# Store original max speed if not already boosted
	if "boost" not in car_effects[car]:
		car_effects[car]["boost"] = {
			"timer": duration,
			"original_max_speed": car.MAX_SPEED
		}
		# Apply 30% speed boost
		car.MAX_SPEED *= 1.3
		item_effect_started.emit(car, "boost", duration)
	else:
		# Refresh timer if already boosted
		car_effects[car]["boost"]["timer"] = duration

func _apply_shield(car: Car, duration: float) -> void:
	if car not in car_effects:
		car_effects[car] = {}

	car_effects[car]["shield"] = {
		"timer": duration,
		"active": true
	}

	# Visual indicator - add shield effect to car
	_add_shield_visual(car)

	item_effect_started.emit(car, "shield", duration)

func _apply_repair(car: Car) -> void:
	if not DamageSystem:
		return

	var damage_state = DamageSystem.get_damage_state(car)
	if damage_state == null:
		return

	# Find most damaged part
	var worst_part = ""
	var worst_health = 1.0

	for part in damage_state.part_health:
		if damage_state.part_health[part] < worst_health:
			worst_health = damage_state.part_health[part]
			worst_part = part

	# Repair 25% of that part
	if worst_part != "":
		var new_health = min(1.0, worst_health + 0.25)
		damage_state.set_part_health(worst_part, new_health)
		print("[ItemManager] Repaired %s: %.0f%% -> %.0f%%" % [worst_part, worst_health * 100, new_health * 100])

func _add_shield_visual(car: Car) -> void:
	# Add visual shield indicator
	var shield_visual = Node2D.new()
	shield_visual.name = "ShieldEffect"

	var shield_sprite = _create_circle_sprite(35.0, Color(0.2, 0.8, 1.0, 0.4))
	shield_visual.add_child(shield_sprite)

	car.add_child(shield_visual)

func _remove_shield_visual(car: Car) -> void:
	var shield_effect = car.get_node_or_null("ShieldEffect")
	if shield_effect:
		shield_effect.queue_free()

## Update respawn timers
func _update_respawn_timers(delta: float) -> void:
	var to_spawn: Array[int] = []

	for spawn_index in respawn_timers:
		respawn_timers[spawn_index] -= delta
		if respawn_timers[spawn_index] <= 0:
			to_spawn.append(spawn_index)

	for spawn_index in to_spawn:
		respawn_timers.erase(spawn_index)
		_spawn_item_at_index(spawn_index)

## Update active effects on cars
func _update_active_effects(delta: float) -> void:
	var cars_to_clean: Array = []

	for car in car_effects:
		if not is_instance_valid(car):
			cars_to_clean.append(car)
			continue

		var effects_to_remove: Array[String] = []

		for effect_type in car_effects[car]:
			var effect_data = car_effects[car][effect_type]
			effect_data["timer"] -= delta

			if effect_data["timer"] <= 0:
				effects_to_remove.append(effect_type)

		for effect_type in effects_to_remove:
			_remove_effect(car, effect_type)

	for car in cars_to_clean:
		car_effects.erase(car)

## Remove an effect from a car
func _remove_effect(car: Car, effect_type: String) -> void:
	if car not in car_effects or effect_type not in car_effects[car]:
		return

	var effect_data = car_effects[car][effect_type]

	match effect_type:
		"boost":
			# Restore original max speed
			car.MAX_SPEED = effect_data.get("original_max_speed", car.MAX_SPEED)
		"shield":
			_remove_shield_visual(car)

	car_effects[car].erase(effect_type)
	item_effect_ended.emit(car, effect_type)
	print("[ItemManager] %s effect ended on %s" % [effect_type, car.name])

## Check if car has active shield (called by damage system)
func has_shield(car: Car) -> bool:
	if car not in car_effects:
		return false
	if "shield" not in car_effects[car]:
		return false
	return car_effects[car]["shield"].get("active", false)

## Consume shield on hit
func consume_shield(car: Car) -> void:
	if has_shield(car):
		car_effects[car]["shield"]["timer"] = 0  # Will be removed next frame
		print("[ItemManager] Shield consumed on %s" % car.name)

## Get active effects for a car (for UI display)
func get_active_effects(car: Car) -> Array[String]:
	var effects: Array[String] = []
	if car in car_effects:
		for effect_type in car_effects[car]:
			effects.append(effect_type)
	return effects

## Get remaining time for an effect
func get_effect_time_remaining(car: Car, effect_type: String) -> float:
	if car not in car_effects:
		return 0.0
	if effect_type not in car_effects[car]:
		return 0.0
	return car_effects[car][effect_type].get("timer", 0.0)

## Clear all items (for race end)
func clear_all() -> void:
	for pickup in active_pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	active_pickups.clear()
	respawn_timers.clear()
	car_effects.clear()
