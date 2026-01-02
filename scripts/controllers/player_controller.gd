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

	# Handbrake (space bar or gamepad button) - for drift initiation
	if InputMap.has_action("handbrake"):
		state.handbrake = Input.get_action_strength("handbrake")
	else:
		# Fallback: use ui_accept (space/enter) if handbrake action not defined
		state.handbrake = Input.get_action_strength("ui_accept")

	# Clutch kick (shift or gamepad button) - for advanced drift control
	if InputMap.has_action("clutch"):
		state.clutch = Input.get_action_strength("clutch")
	else:
		state.clutch = 0.0

	return state
