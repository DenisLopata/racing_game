class_name PlayerController
extends CarController
## Controller that reads input from the player (keyboard/gamepad)

func get_input() -> InputState:
	var state = InputState.new()

	# Throttle (forward acceleration)
	state.throttle = Input.get_action_strength("ui_up")

	# Brake (or reverse when stopped)
	state.brake = Input.get_action_strength("ui_down")

	# Steering (-1 left, +1 right)
	state.steer = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")

	return state
