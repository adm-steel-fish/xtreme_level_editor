extends Node
class_name XtremeSaveManager
## Manages saving and loading game progress

## Emitted when save completes
signal save_completed(slot_id: int, success: bool)

## Emitted when load completes
signal load_completed(slot_id: int, success: bool)

## Emitted when save data is corrupted or invalid
signal save_corrupted(slot_id: int)

## Save directory
const SAVE_DIR := "user://saves/"
const SAVE_EXTENSION := ".tres"
const SAVE_PREFIX := "save_"
const MAX_SAVE_SLOTS := 10

## Currently loaded progress (null if none)
var current_progress: XtremeWorldProgress

## Auto-save enabled
@export var auto_save_enabled: bool = true

## Auto-save interval (seconds)
@export var auto_save_interval: float = 60.0

## Last auto-save time
var _last_auto_save_time: float = 0.0

func _ready() -> void:
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _process(delta: float) -> void:
	if auto_save_enabled and current_progress:
		_last_auto_save_time += delta
		if _last_auto_save_time >= auto_save_interval:
			save_current()
			_last_auto_save_time = 0.0

## Get save file path for a slot
func _get_save_path(slot_id: int) -> String:
	return SAVE_DIR + SAVE_PREFIX + str(slot_id) + SAVE_EXTENSION

## Check if a save slot exists
func save_exists(slot_id: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot_id))

## Get info about a save slot (for save select screen)
func get_save_info(slot_id: int) -> Dictionary:
	if not save_exists(slot_id):
		return {"exists": false}
	
	var progress := load_progress(slot_id)
	if not progress:
		return {"exists": false, "corrupted": true}
	
	return {
		"exists": true,
		"slot_id": slot_id,
		"player_name": progress.player_name,
		"completion_percentage": progress.completion_percentage,
		"total_play_time": progress.total_play_time,
		"levels_completed": progress.levels_completed,
		"last_played_date": progress.last_played_date,
		"created_date": progress.created_date
	}

## Get info for all save slots
func get_all_save_info() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	for i in range(MAX_SAVE_SLOTS):
		saves.append(get_save_info(i))
	return saves

## Create a new save in a slot
func create_new_save(slot_id: int, player_name: String = "Player") -> XtremeWorldProgress:
	var progress := XtremeWorldProgress.create_new(slot_id, player_name)
	
	# Save immediately
	if save_progress(progress):
		current_progress = progress
		return progress
	
	return null

## Save progress to file
func save_progress(progress: XtremeWorldProgress) -> bool:
	if not progress:
		return false
	
	var path := _get_save_path(progress.slot_id)
	
	# Update last played date
	progress.last_played_date = int(Time.get_unix_time_from_system())
	
	var error := ResourceSaver.save(progress, path)
	var success := error == OK
	
	save_completed.emit(progress.slot_id, success)
	
	if not success:
		push_error("XtremeSaveManager: Failed to save to slot %d: %s" % [progress.slot_id, error_string(error)])
	
	return success

## Save current progress
func save_current() -> bool:
	if current_progress:
		return save_progress(current_progress)
	return false

## Load progress from file
func load_progress(slot_id: int) -> XtremeWorldProgress:
	var path := _get_save_path(slot_id)
	
	if not FileAccess.file_exists(path):
		load_completed.emit(slot_id, false)
		return null
	
	var resource := load(path)
	
	if resource is XtremeWorldProgress:
		load_completed.emit(slot_id, true)
		return resource
	else:
		save_corrupted.emit(slot_id)
		push_error("XtremeSaveManager: Save file corrupted for slot %d" % slot_id)
		load_completed.emit(slot_id, false)
		return null

## Load and set as current progress
func load_and_set_current(slot_id: int) -> bool:
	var progress := load_progress(slot_id)
	if progress:
		current_progress = progress
		return true
	return false

## Delete a save slot
func delete_save(slot_id: int) -> bool:
	var path := _get_save_path(slot_id)
	
	if not FileAccess.file_exists(path):
		return true  # Already doesn't exist
	
	var error := DirAccess.remove_absolute(path)
	
	if error == OK:
		if current_progress and current_progress.slot_id == slot_id:
			current_progress = null
		return true
	
	push_error("XtremeSaveManager: Failed to delete slot %d: %s" % [slot_id, error_string(error)])
	return false

## Copy a save to another slot
func copy_save(from_slot: int, to_slot: int) -> bool:
	var progress := load_progress(from_slot)
	if not progress:
		return false
	
	progress.slot_id = to_slot
	return save_progress(progress)

## Get current progress (convenience)
func get_current() -> XtremeWorldProgress:
	return current_progress

## Quick save current to a backup slot
func quick_save() -> bool:
	if current_progress:
		# Save to a backup slot (slot 9 reserved for quick save)
		var backup := current_progress.duplicate()
		backup.slot_id = MAX_SAVE_SLOTS - 1
		return save_progress(backup)
	return false

## Format play time for display
static func format_play_time(seconds: float) -> String:
	var hours := int(seconds / 3600)
	var minutes := int(fmod(seconds, 3600) / 60)
	var secs := int(fmod(seconds, 60))
	
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	else:
		return "%d:%02d" % [minutes, secs]

## Format date for display
static func format_date(unix_time: int) -> String:
	var datetime := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d/%02d/%02d %02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute
	]
