extends CanvasLayer
## Pause Menu - shown when player presses ESC during race

signal resume_requested
signal restart_requested
signal quit_requested

func _ready() -> void:
	# Start hidden
	hide()
	# Ensure pause menu processes even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	# Handle ESC to close pause menu when visible
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()

func show_pause() -> void:
	show()
	get_tree().paused = true

func hide_pause() -> void:
	hide()
	get_tree().paused = false

func _on_resume_pressed() -> void:
	hide_pause()
	resume_requested.emit()

func _on_restart_pressed() -> void:
	hide_pause()
	restart_requested.emit()

func _on_quit_pressed() -> void:
	hide_pause()
	quit_requested.emit()
