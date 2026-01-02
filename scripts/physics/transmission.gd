class_name Transmission
extends RefCounted
## Automatic transmission simulation for arcade racing
## Provides gear-based acceleration curves and engine feel

signal gear_changed(new_gear: int, rpm_percent: float)

# Transmission configuration
var gear_ratios: Array[float] = [3.5, 2.5, 1.8, 1.3, 1.0, 0.8]  # 6 gears
var final_drive: float = 3.5
var reverse_ratio: float = -3.2

# Engine parameters
var max_rpm: float = 8000.0
var idle_rpm: float = 1000.0
var redline_rpm: float = 7500.0
var optimal_shift_rpm: float = 7000.0  # RPM to shift up at
var downshift_rpm: float = 3000.0      # RPM to shift down at

# Torque curve (normalized, indexed by RPM percentage)
# Creates a realistic power band with peak around 70-80%
var torque_curve: Array[float] = [
	0.4,   # 0% (idle)
	0.55,  # ~15%
	0.7,   # ~30%
	0.85,  # ~45%
	0.95,  # ~60%
	1.0,   # ~75% (peak torque)
	0.95,  # ~90%
	0.85   # 100% (redline)
]

# Current state
var current_gear: int = 1              # 1-6, 0 = neutral, -1 = reverse
var current_rpm: float = 1000.0
var engine_torque: float = 0.0         # Current torque output (0-1)

# Shift timing
var shift_cooldown: float = 0.0
var shift_delay: float = 0.15          # Time between shifts

## Update transmission state
## speed: current car speed
## throttle: throttle input (0-1)
## delta: frame time
func update(speed: float, throttle: float, delta: float) -> void:
	shift_cooldown = max(0.0, shift_cooldown - delta)

	# Calculate RPM from speed and current gear
	_update_rpm(speed, throttle)

	# Auto-shift logic
	if shift_cooldown <= 0:
		_auto_shift()

	# Calculate torque output
	_update_torque(throttle)

## Calculate RPM based on speed and gear
func _update_rpm(speed: float, throttle: float) -> void:
	if current_gear == 0:  # Neutral
		# Rev freely based on throttle
		var target_rpm = idle_rpm + throttle * (redline_rpm - idle_rpm) * 0.8
		current_rpm = lerp(current_rpm, target_rpm, 0.1)
		return

	var gear_ratio: float
	if current_gear == -1:  # Reverse
		gear_ratio = reverse_ratio
		speed = abs(speed)
	else:
		gear_ratio = gear_ratios[current_gear - 1]

	# RPM = speed * gear_ratio * final_drive * magic_number
	# The magic number converts our speed units to something sensible
	var target_rpm = abs(speed) * abs(gear_ratio) * final_drive * 25.0
	target_rpm = clamp(target_rpm, idle_rpm, max_rpm)

	# RPM changes quickly
	current_rpm = lerp(current_rpm, target_rpm, 0.3)

	# If on throttle but RPM dropping (stalling), keep it above idle
	if throttle > 0.1 and current_rpm < idle_rpm * 1.2:
		current_rpm = idle_rpm * 1.2

## Automatic gear shifting
func _auto_shift() -> void:
	if current_gear <= 0:
		return  # Don't auto-shift in neutral or reverse

	var should_upshift = current_rpm >= optimal_shift_rpm and current_gear < gear_ratios.size()
	var should_downshift = current_rpm <= downshift_rpm and current_gear > 1

	if should_upshift:
		shift_up()
	elif should_downshift:
		shift_down()

## Calculate torque from RPM
func _update_torque(throttle: float) -> void:
	if current_gear == 0:
		engine_torque = 0.0
		return

	# Get position on torque curve
	var rpm_percent = (current_rpm - idle_rpm) / (max_rpm - idle_rpm)
	rpm_percent = clamp(rpm_percent, 0.0, 1.0)

	# Sample torque curve
	var curve_index = rpm_percent * (torque_curve.size() - 1)
	var lower = int(curve_index)
	var upper = min(lower + 1, torque_curve.size() - 1)
	var t = curve_index - lower

	var base_torque = lerp(torque_curve[lower], torque_curve[upper], t)

	# Apply gear multiplication (lower gears = more torque)
	var gear_ratio: float
	if current_gear == -1:
		gear_ratio = abs(reverse_ratio)
	else:
		gear_ratio = gear_ratios[current_gear - 1]

	var gear_mult = gear_ratio / gear_ratios[0]  # Normalize to first gear

	# Final torque = base * gear * throttle
	engine_torque = base_torque * gear_mult * throttle

## Shift up
func shift_up() -> void:
	if current_gear >= gear_ratios.size():
		return

	if current_gear == -1:
		current_gear = 0  # Reverse to neutral
	elif current_gear == 0:
		current_gear = 1  # Neutral to first
	else:
		current_gear += 1

	shift_cooldown = shift_delay
	# RPM drops on upshift
	current_rpm *= 0.7
	gear_changed.emit(current_gear, current_rpm / max_rpm)

## Shift down
func shift_down() -> void:
	if current_gear <= -1:
		return

	if current_gear == 1:
		current_gear = 0  # First to neutral (for safety)
	elif current_gear == 0:
		current_gear = -1  # Neutral to reverse
	else:
		current_gear -= 1
		# RPM increases on downshift
		current_rpm = min(current_rpm * 1.4, redline_rpm)

	shift_cooldown = shift_delay
	gear_changed.emit(current_gear, current_rpm / max_rpm)

## Get gear for display
func get_gear_display() -> String:
	match current_gear:
		-1: return "R"
		0: return "N"
		_: return str(current_gear)

## Get RPM percentage for display (0-1)
func get_rpm_percent() -> float:
	return (current_rpm - idle_rpm) / (max_rpm - idle_rpm)

## Check if near redline
func is_near_redline() -> bool:
	return current_rpm >= redline_rpm * 0.95

## Get acceleration multiplier based on current torque
func get_acceleration_multiplier() -> float:
	return engine_torque

## Reset to first gear (for race start)
func reset() -> void:
	current_gear = 1
	current_rpm = idle_rpm
	shift_cooldown = 0.0

## Configure transmission type
func configure(trans_type: String) -> void:
	match trans_type:
		"sport":
			optimal_shift_rpm = 7200.0
			downshift_rpm = 3500.0
			shift_delay = 0.12
		"comfort":
			optimal_shift_rpm = 5500.0
			downshift_rpm = 2500.0
			shift_delay = 0.25
		"race":
			optimal_shift_rpm = 7500.0
			downshift_rpm = 4000.0
			shift_delay = 0.08
			gear_ratios = [3.2, 2.3, 1.7, 1.3, 1.05, 0.85]  # Closer ratios
		_:  # default
			pass
