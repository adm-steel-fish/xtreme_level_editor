@tool
class_name XtremeWorldProgress
extends Resource
## World Progress - Tracks overall game save state

## Save slot identifier
@export var slot_id: int = 0

## Player name for this save
@export var player_name: String = "Player"

## Progress for each level (key = level_id)
@export var level_progress: Dictionary = {}

## Currently selected world (for world map)
@export var current_world: StringName = &""

## Last played level
@export var last_played_level: StringName = &""

## Total play time across all levels (seconds)
@export var total_play_time: float = 0.0

## Total rings collected across all levels
@export var total_rings: int = 0

## Total score across all levels
@export var total_score: int = 0

## Number of levels completed
@export var levels_completed: int = 0

## Number of secret exits found
@export var secrets_found: int = 0

## Game completion percentage
@export var completion_percentage: float = 0.0

## Date created (Unix timestamp)
@export var created_date: int = 0

## Date last played (Unix timestamp)
@export var last_played_date: int = 0

## Unlocked worlds
@export var unlocked_worlds: Array[StringName] = []

## Custom data (achievements, collectibles, etc.)
@export var custom_data: Dictionary = {}

## Get progress for a level (creates if doesn't exist)
func get_level_progress(level_id: StringName) -> XtremeLevelProgress:
	if level_id in level_progress:
		return level_progress[level_id]
	
	# Create new progress entry
	var progress := XtremeLevelProgress.create_for_level(level_id, false)
	level_progress[level_id] = progress
	return progress

## Set level progress
func set_level_progress(level_id: StringName, progress: XtremeLevelProgress) -> void:
	level_progress[level_id] = progress

## Check if a level is unlocked
func is_level_unlocked(level_id: StringName) -> bool:
	if level_id in level_progress:
		return level_progress[level_id].is_playable()
	return false

## Check if a level is completed
func is_level_completed(level_id: StringName) -> bool:
	if level_id in level_progress:
		return level_progress[level_id].is_completed()
	return false

## Unlock a level
func unlock_level(level_id: StringName) -> void:
	var progress := get_level_progress(level_id)
	progress.unlock()

## Unlock multiple levels
func unlock_levels(level_ids: Array[StringName]) -> void:
	for level_id in level_ids:
		unlock_level(level_id)

## Record a level completion and update totals
func record_level_completion(level_id: StringName, time: float, rings: int, score: int, rank: String, is_secret: bool = false) -> Dictionary:
	var progress := get_level_progress(level_id)
	var was_completed := progress.is_completed()
	var had_secret := progress.secret_exit_found
	
	var improvements := progress.record_completion(time, rings, score, rank, is_secret)
	
	# Update totals
	total_rings += rings
	total_score += score
	total_play_time += time
	last_played_level = level_id
	last_played_date = int(Time.get_unix_time_from_system())
	
	# Update completion counts
	if not was_completed and progress.is_completed():
		levels_completed += 1
	
	if not had_secret and progress.secret_exit_found:
		secrets_found += 1
	
	# Recalculate completion percentage
	_update_completion_percentage()
	
	return improvements

## Unlock a world
func unlock_world(world_id: StringName) -> void:
	if world_id not in unlocked_worlds:
		unlocked_worlds.append(world_id)

## Check if a world is unlocked
func is_world_unlocked(world_id: StringName) -> bool:
	return world_id in unlocked_worlds

## Update completion percentage based on all levels
func _update_completion_percentage() -> void:
	if level_progress.is_empty():
		completion_percentage = 0.0
		return
	
	var total_points := 0.0
	var earned_points := 0.0
	
	for level_id in level_progress:
		var progress: XtremeLevelProgress = level_progress[level_id]
		# Each level is worth 1 point for completion, 0.5 for secret
		total_points += 1.5
		if progress.is_completed():
			earned_points += 1.0
		if progress.secret_exit_found:
			earned_points += 0.5
	
	completion_percentage = (earned_points / total_points) * 100.0

## Get all completed level IDs
func get_completed_levels() -> Array[StringName]:
	var completed: Array[StringName] = []
	for level_id in level_progress:
		var progress: XtremeLevelProgress = level_progress[level_id]
		if progress.is_completed():
			completed.append(level_id)
	return completed

## Get all unlocked level IDs
func get_unlocked_levels() -> Array[StringName]:
	var unlocked: Array[StringName] = []
	for level_id in level_progress:
		var progress: XtremeLevelProgress = level_progress[level_id]
		if progress.is_playable():
			unlocked.append(level_id)
	return unlocked

## Reset all progress (new game)
func reset() -> void:
	for level_id in level_progress:
		var progress: XtremeLevelProgress = level_progress[level_id]
		progress.reset()
	
	current_world = &""
	last_played_level = &""
	total_play_time = 0.0
	total_rings = 0
	total_score = 0
	levels_completed = 0
	secrets_found = 0
	completion_percentage = 0.0
	unlocked_worlds.clear()
	custom_data.clear()

## Create a new save
static func create_new(slot_id: int, player_name: String = "Player") -> XtremeWorldProgress:
	var progress := XtremeWorldProgress.new()
	progress.slot_id = slot_id
	progress.player_name = player_name
	progress.created_date = int(Time.get_unix_time_from_system())
	progress.last_played_date = progress.created_date
	return progress
