class_name LiverySystem
extends RefCounted
## Renders livery patterns on car sprites

# Standard car sprite size (adjust based on your car)
const CAR_WIDTH: int = 30
const CAR_HEIGHT: int = 15

## Generate a livery texture for a car
static func generate_livery(livery_id: String, primary_color: Color, secondary_color: Color) -> ImageTexture:
	var image = Image.create(CAR_WIDTH, CAR_HEIGHT, false, Image.FORMAT_RGBA8)

	match livery_id:
		"livery_solid":
			_draw_solid(image, primary_color)
		"livery_stripes":
			_draw_stripes(image, primary_color, secondary_color)
		"livery_gradient":
			_draw_gradient(image, primary_color, secondary_color)
		"livery_flames":
			_draw_flames(image, primary_color, secondary_color)
		"livery_carbon":
			_draw_carbon(image, primary_color)
		"livery_camo":
			_draw_camo(image, primary_color, secondary_color)
		_:
			_draw_solid(image, primary_color)

	return ImageTexture.create_from_image(image)

## Apply livery to a car sprite
static func apply_to_car(car: Node, livery_id: String, primary_color: Color, secondary_color: Color) -> void:
	var sprite = car.get_node_or_null("Sprite2D")
	if not sprite:
		return

	# For simple implementation, use modulate for solid colors
	# For patterns, we'd need to create/modify the texture
	match livery_id:
		"livery_solid":
			sprite.modulate = primary_color
		"livery_stripes", "livery_gradient", "livery_flames", "livery_carbon", "livery_camo":
			# These would require custom textures
			# For now, use primary color with slight modification
			sprite.modulate = primary_color
		_:
			sprite.modulate = primary_color

# =============================================================================
# Livery Pattern Drawing Functions
# =============================================================================

static func _draw_solid(image: Image, color: Color) -> void:
	image.fill(color)

static func _draw_stripes(image: Image, primary: Color, secondary: Color) -> void:
	# Fill with primary
	image.fill(primary)

	# Draw two vertical stripes
	var stripe_width = 3
	var center_x = CAR_WIDTH / 2

	for y in CAR_HEIGHT:
		for x in range(center_x - stripe_width - 2, center_x - 2):
			if x >= 0 and x < CAR_WIDTH:
				image.set_pixel(x, y, secondary)
		for x in range(center_x + 2, center_x + stripe_width + 2):
			if x >= 0 and x < CAR_WIDTH:
				image.set_pixel(x, y, secondary)

static func _draw_gradient(image: Image, primary: Color, secondary: Color) -> void:
	for y in CAR_HEIGHT:
		var t = float(y) / float(CAR_HEIGHT)
		var blend_color = primary.lerp(secondary, t)
		for x in CAR_WIDTH:
			image.set_pixel(x, y, blend_color)

static func _draw_flames(image: Image, primary: Color, secondary: Color) -> void:
	# Fill with primary
	image.fill(primary)

	# Simple flame pattern from front
	var flame_color = Color.ORANGE.lerp(secondary, 0.3)

	for x in CAR_WIDTH:
		# Flame height varies with position
		var wave = sin(float(x) * 0.5) * 2 + 3
		var flame_height = int(wave)

		for y in flame_height:
			if y < CAR_HEIGHT:
				var intensity = 1.0 - (float(y) / float(flame_height))
				var pixel_color = flame_color
				pixel_color.a = intensity
				image.set_pixel(x, y, primary.lerp(flame_color, intensity))

static func _draw_carbon(image: Image, primary: Color) -> void:
	# Carbon fiber weave pattern
	var dark = primary.darkened(0.3)
	var light = primary.lightened(0.1)

	for y in CAR_HEIGHT:
		for x in CAR_WIDTH:
			# Create weave pattern
			var pattern = ((x + y) % 4 < 2) != ((x - y) % 4 < 2)
			image.set_pixel(x, y, light if pattern else dark)

static func _draw_camo(image: Image, primary: Color, secondary: Color) -> void:
	# Simple camo pattern
	var colors = [primary, secondary, primary.darkened(0.2), secondary.lightened(0.2)]

	# Fill with base
	image.fill(primary)

	# Add random patches
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Fixed seed for consistent pattern

	for _i in 15:
		var px = rng.randi_range(0, CAR_WIDTH - 1)
		var py = rng.randi_range(0, CAR_HEIGHT - 1)
		var size = rng.randi_range(2, 5)
		var color = colors[rng.randi_range(0, colors.size() - 1)]

		# Draw blob
		for dx in range(-size, size + 1):
			for dy in range(-size, size + 1):
				var nx = px + dx
				var ny = py + dy
				if nx >= 0 and nx < CAR_WIDTH and ny >= 0 and ny < CAR_HEIGHT:
					if dx * dx + dy * dy <= size * size:
						image.set_pixel(nx, ny, color)

# =============================================================================
# Decal Rendering
# =============================================================================

## Generate a decal overlay texture
static func generate_decal(decal_id: String, color: Color) -> ImageTexture:
	var size = 16
	var image = Image.create(size, size, true, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	match decal_id:
		"decal_number_1":
			_draw_number_1(image, color)
		"decal_star":
			_draw_star(image, color)
		"decal_lightning":
			_draw_lightning(image, color)
		"decal_skull":
			_draw_skull(image, color)

	return ImageTexture.create_from_image(image)

static func _draw_number_1(image: Image, color: Color) -> void:
	var size = image.get_width()
	var center = size / 2

	# Draw "1"
	for y in range(2, size - 2):
		image.set_pixel(center, y, color)
		image.set_pixel(center + 1, y, color)

	# Top serif
	image.set_pixel(center - 1, 2, color)
	image.set_pixel(center - 2, 3, color)

	# Bottom line
	for x in range(center - 2, center + 4):
		image.set_pixel(x, size - 3, color)

static func _draw_star(image: Image, color: Color) -> void:
	var size = image.get_width()
	var center = size / 2

	# Simple 5-pointed star
	var points = []
	for i in 5:
		var angle = -PI / 2 + (2 * PI * i / 5)
		var outer = Vector2(cos(angle), sin(angle)) * (size / 2 - 2) + Vector2(center, center)
		points.append(outer)

		var inner_angle = angle + PI / 5
		var inner = Vector2(cos(inner_angle), sin(inner_angle)) * (size / 4) + Vector2(center, center)
		points.append(inner)

	# Fill star (simplified - just draw lines)
	for i in points.size():
		var p1 = points[i]
		var p2 = points[(i + 1) % points.size()]
		_draw_line(image, p1, p2, color)

static func _draw_lightning(image: Image, color: Color) -> void:
	var size = image.get_width()

	# Lightning bolt shape
	var points = [
		Vector2(size * 0.6, 1),
		Vector2(size * 0.3, size * 0.45),
		Vector2(size * 0.55, size * 0.45),
		Vector2(size * 0.35, size - 1),
		Vector2(size * 0.65, size * 0.55),
		Vector2(size * 0.45, size * 0.55),
	]

	for i in points.size() - 1:
		_draw_line(image, points[i], points[i + 1], color)

static func _draw_skull(image: Image, color: Color) -> void:
	var size = image.get_width()
	var cx = size / 2
	var cy = size / 2 - 1

	# Head circle
	for angle in range(0, 360, 10):
		var rad = deg_to_rad(float(angle))
		var x = int(cx + cos(rad) * 5)
		var y = int(cy + sin(rad) * 4)
		if x >= 0 and x < size and y >= 0 and y < size:
			image.set_pixel(x, y, color)

	# Eyes
	image.set_pixel(cx - 2, cy, Color.TRANSPARENT)
	image.set_pixel(cx + 2, cy, Color.TRANSPARENT)

	# Jaw
	for x in range(cx - 3, cx + 4):
		image.set_pixel(x, size - 3, color)

static func _draw_line(image: Image, p1: Vector2, p2: Vector2, color: Color) -> void:
	var steps = int(p1.distance_to(p2)) + 1
	for i in steps:
		var t = float(i) / float(steps) if steps > 0 else 0
		var p = p1.lerp(p2, t)
		var x = int(p.x)
		var y = int(p.y)
		if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
			image.set_pixel(x, y, color)
