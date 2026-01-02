class_name CameraShake
extends Node
## Adds screen shake effect to Camera2D on impacts

@export var max_shake: float = 15.0  # Maximum shake offset in pixels
@export var decay_rate: float = 5.0  # How fast shake decays

var camera: Camera2D
var shake_amount: float = 0.0
var _original_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Find parent camera
	var parent = get_parent()
	if parent is Camera2D:
		camera = parent
		_original_offset = camera.offset

func _process(delta: float) -> void:
	if not camera or not GameSettings.screen_shake_enabled:
		return

	if shake_amount > 0:
		# Apply random shake offset
		var shake_offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		camera.offset = _original_offset + shake_offset

		# Decay shake over time
		shake_amount = max(0, shake_amount - decay_rate * delta * shake_amount)

		# Stop shake when very small
		if shake_amount < 0.1:
			shake_amount = 0
			camera.offset = _original_offset
	else:
		camera.offset = _original_offset

## Trigger a shake with given intensity (0.0 - 1.0)
func shake(intensity: float) -> void:
	if not GameSettings.screen_shake_enabled:
		return

	intensity = clamp(intensity, 0.0, 1.0)
	var new_shake = intensity * max_shake

	# Only increase shake, don't reduce if already shaking harder
	shake_amount = max(shake_amount, new_shake)

## Calculate shake intensity from impact speed
static func intensity_from_speed(impact_speed: float, min_speed: float = 100.0, max_speed: float = 500.0) -> float:
	if impact_speed < min_speed:
		return 0.0
	return clamp((impact_speed - min_speed) / (max_speed - min_speed), 0.0, 1.0)
