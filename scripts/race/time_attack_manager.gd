extends Node
## TimeAttackManager autoload - do not add class_name (causes conflicts with autoload)
## Manages Time Attack mode - solo practice with ghost cars and best time tracking

signal new_best_lap(track_id: String, lap_time: float)
signal ghost_loaded(track_id: String)

const GHOST_SAVE_PATH: String = "user://ghost_data/"
const RECORDING_INTERVAL: float = 0.05  # Record position every 50ms

# Ghost data structure
# {
#     "track_id": String,
#     "lap_time": float,
#     "frames": [{"time": float, "position": Vector2, "rotation": float}]
# }

var is_time_attack_mode: bool = false
var current_track_id: String = ""

# Recording state
var is_recording: bool = false
var recording_start_time: float = 0.0
var recorded_frames: Array = []
var record_timer: float = 0.0

# Playback state
var ghost_data: Dictionary = {}
var current_playback_frame: int = 0
var playback_time: float = 0.0

# Best times (also stored in PlayerProgress)
var best_times: Dictionary = {}  # track_id -> lap_time

func _ready() -> void:
	# Ensure ghost save directory exists
	DirAccess.make_dir_recursive_absolute(GHOST_SAVE_PATH.replace("user://", OS.get_user_data_dir() + "/"))

## Start Time Attack mode for a track
func start_time_attack(track_id: String) -> void:
	is_time_attack_mode = true
	current_track_id = track_id
	recorded_frames.clear()
	is_recording = false

	# Load best ghost if exists
	_load_ghost_data(track_id)

	# Load best times from PlayerProgress
	if PlayerProgress:
		best_times[track_id] = PlayerProgress.get_best_lap_time(track_id)

	print("[TimeAttack] Started for track: %s" % track_id)

## End Time Attack mode
func end_time_attack() -> void:
	is_time_attack_mode = false
	is_recording = false
	ghost_data.clear()
	recorded_frames.clear()
	print("[TimeAttack] Ended")

## Start recording a lap
func start_lap_recording(car: Node2D) -> void:
	if not is_time_attack_mode:
		return

	is_recording = true
	recording_start_time = Time.get_ticks_msec() / 1000.0
	recorded_frames.clear()
	record_timer = 0.0

	# Record initial frame
	_record_frame(car, 0.0)

	print("[TimeAttack] Started recording lap")

## Process recording (call from _physics_process)
func process_recording(car: Node2D, delta: float) -> void:
	if not is_recording or not car:
		return

	record_timer += delta
	if record_timer >= RECORDING_INTERVAL:
		record_timer = 0.0
		var elapsed = Time.get_ticks_msec() / 1000.0 - recording_start_time
		_record_frame(car, elapsed)

func _record_frame(car: Node2D, time: float) -> void:
	recorded_frames.append({
		"time": time,
		"position": car.global_position,
		"rotation": car.rotation
	})

## Finish recording a lap
func finish_lap_recording(lap_time: float) -> bool:
	if not is_recording:
		return false

	is_recording = false

	var best_time: float = best_times.get(current_track_id, 0.0)
	var is_new_best: bool = best_time <= 0.0 or lap_time < best_time

	if is_new_best:
		# Save new best
		best_times[current_track_id] = lap_time

		ghost_data = {
			"track_id": current_track_id,
			"lap_time": lap_time,
			"frames": recorded_frames.duplicate(true)
		}

		_save_ghost_data(current_track_id)

		# Update PlayerProgress
		if PlayerProgress:
			var stats = PlayerProgress.statistics
			var best_lap_times: Dictionary = stats.get("best_lap_times", {})
			best_lap_times[current_track_id] = lap_time
			stats["best_lap_times"] = best_lap_times
			PlayerProgress.save_progress()

		new_best_lap.emit(current_track_id, lap_time)
		print("[TimeAttack] New best lap: %.3f" % lap_time)
		return true

	print("[TimeAttack] Lap finished: %.3f (best: %.3f)" % [lap_time, best_time])
	return false

## Cancel current recording
func cancel_recording() -> void:
	is_recording = false
	recorded_frames.clear()

# =============================================================================
# Ghost Playback
# =============================================================================

## Start ghost playback from beginning
func start_ghost_playback() -> void:
	if ghost_data.is_empty():
		return

	current_playback_frame = 0
	playback_time = 0.0

## Update ghost playback (returns position and rotation for ghost car)
func update_ghost_playback(delta: float) -> Dictionary:
	if ghost_data.is_empty():
		return {}

	var frames: Array = ghost_data.get("frames", [])
	if frames.is_empty():
		return {}

	playback_time += delta

	# Find the appropriate frame
	while current_playback_frame < frames.size() - 1:
		var next_frame = frames[current_playback_frame + 1]
		if next_frame["time"] <= playback_time:
			current_playback_frame += 1
		else:
			break

	# Interpolate between frames
	if current_playback_frame >= frames.size() - 1:
		var last_frame = frames[frames.size() - 1]
		return {
			"position": last_frame["position"],
			"rotation": last_frame["rotation"],
			"finished": true
		}

	var current_frame = frames[current_playback_frame]
	var next_frame = frames[current_playback_frame + 1]

	var t: float = 0.0
	var time_diff = next_frame["time"] - current_frame["time"]
	if time_diff > 0:
		t = (playback_time - current_frame["time"]) / time_diff
		t = clamp(t, 0.0, 1.0)

	return {
		"position": current_frame["position"].lerp(next_frame["position"], t),
		"rotation": lerp_angle(current_frame["rotation"], next_frame["rotation"], t),
		"finished": false
	}

## Check if ghost is available for current track
func has_ghost() -> bool:
	return not ghost_data.is_empty()

## Get best time for current track
func get_best_time() -> float:
	return best_times.get(current_track_id, 0.0)

## Get ghost lap time
func get_ghost_lap_time() -> float:
	return ghost_data.get("lap_time", 0.0)

# =============================================================================
# Save/Load Ghost Data
# =============================================================================

func _get_ghost_path(track_id: String) -> String:
	return GHOST_SAVE_PATH + track_id.replace("/", "_") + ".json"

func _save_ghost_data(track_id: String) -> void:
	var path = _get_ghost_path(track_id)

	# Convert Vector2 to arrays for JSON
	var save_data = ghost_data.duplicate(true)
	var frames: Array = save_data.get("frames", [])
	for i in frames.size():
		var pos: Vector2 = frames[i]["position"]
		frames[i]["position"] = [pos.x, pos.y]

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("[TimeAttack] Saved ghost to: %s" % path)

func _load_ghost_data(track_id: String) -> void:
	ghost_data.clear()

	var path = _get_ghost_path(track_id)
	if not FileAccess.file_exists(path):
		print("[TimeAttack] No ghost data for track: %s" % track_id)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()

		var data = JSON.parse_string(content)
		if data and data is Dictionary:
			# Convert position arrays back to Vector2
			var frames: Array = data.get("frames", [])
			for i in frames.size():
				var pos_arr: Array = frames[i]["position"]
				frames[i]["position"] = Vector2(pos_arr[0], pos_arr[1])

			ghost_data = data
			ghost_loaded.emit(track_id)
			print("[TimeAttack] Loaded ghost for track: %s (%.3fs)" % [track_id, ghost_data.get("lap_time", 0.0)])

## Delete ghost data for a track
func delete_ghost(track_id: String) -> void:
	var path = _get_ghost_path(track_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[TimeAttack] Deleted ghost for: %s" % track_id)

	if current_track_id == track_id:
		ghost_data.clear()

# =============================================================================
# Comparison Data
# =============================================================================

## Get time difference between current and ghost at a given point
func get_time_delta_at_position(current_time: float, current_progress: float) -> float:
	if ghost_data.is_empty():
		return 0.0

	var ghost_lap_time: float = ghost_data.get("lap_time", 0.0)
	if ghost_lap_time <= 0:
		return 0.0

	# Estimate ghost time at same progress
	var ghost_time_at_progress = ghost_lap_time * current_progress

	# Positive = behind ghost, Negative = ahead of ghost
	return current_time - ghost_time_at_progress
