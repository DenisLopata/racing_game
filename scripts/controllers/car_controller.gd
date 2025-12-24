class_name CarController
extends RefCounted
## Base class for car input controllers (player or AI)
## Subclasses implement get_input() to provide throttle, brake, and steering values

## Input state returned by the controller each frame
class InputState:
	var throttle: float = 0.0  # 0.0 to 1.0 (accelerate)
	var brake: float = 0.0     # 0.0 to 1.0 (brake/reverse)
	var steer: float = 0.0     # -1.0 (left) to 1.0 (right)

	func _init(t: float = 0.0, b: float = 0.0, s: float = 0.0) -> void:
		throttle = t
		brake = b
		steer = s

## Reference to the car being controlled (set by car when controller is assigned)
var car: Node = null

## Called every physics frame to get input values
## Override in subclasses
func get_input() -> InputState:
	return InputState.new()

## Called when controller is assigned to a car
func on_attached(controlled_car: Node) -> void:
	car = controlled_car

## Called when controller is removed from a car
func on_detached() -> void:
	car = null
