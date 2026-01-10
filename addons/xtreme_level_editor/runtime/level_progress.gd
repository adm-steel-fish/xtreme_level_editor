@tool
class_name XtremeLevelProgress
extends Resource
## Level Progress - Tracks completion state for a single level

## Level status
enum LevelStatus {
	LOCKED,         ## Level not yet unlocked
	UNLOCKED,       ## Level available to play
	COMPLETED,      ## Level beaten (normal exit)
	SECRET_FOUND,   ## Level beaten with secret exit found
	PERFECT         ## Level completed with S rank
}

## Level ID this progress is for
@export var level_id: StringName = &""

## Current status
@export var status: LevelStatus = LevelStatus.LOCKED

## Best completion time (seconds)
@export var best_time: float = 0.0

## Best ring count at completion
@export var best_rings: int = 0

## Best score achieved
@export var best_score: int = 0

## Best rank achieved (S, A, B, C, D, E)
@export var best_rank: String = ""

## Number of times completed
@export var completion_count: int = 0

## Has the secret exit been found?
@export var secret_exit_found: bool = false

## Total rings collected across all attempts
@export var total_rings_collected: int = 0

## Total time played in this level (seconds)
@export var total_time_played: float = 0.0

## Date of first completion (Unix timestamp)
@export var first_completion_date: int = 0

## Date of best score (Unix timestamp)
@export var best_score_date: int = 0

## Custom data for game-specific tracking
@export var custom_data: Dictionary = {}

## Check if level is playable
func is_playable() -> bool:
	return status != LevelStatus.LOCKED

## Check if level has been completed at least once
func is_completed() -> bool:
	return status >= LevelStatus.COMPLETED

## Record a completion
func record_completion(time: float, rings: int, score: int, rank: String, is_secret_exit: bool = false) -> Dictionary:
	var improvements := {}
	
	completion_count += 1
	total_rings_collected += rings
	total_time_played += time
	
	# Track first completion
	if first_completion_date == 0:
		first_completion_date = int(Time.get_unix_time_from_system())
	
	# Update best time
	if best_time == 0.0 or time < best_time:
		improvements["time"] = {"old": best_time, "new": time}
		best_time = time
	
	# Update best rings
	if rings > best_rings:
		improvements["rings"] = {"old": best_rings, "new": rings}
		best_rings = rings
	
	# Update best score
	if score > best_score:
		improvements["score"] = {"old": best_score, "new": score}
		best_score = score
		best_score_date = int(Time.get_unix_time_from_system())
	
	# Update best rank
	if _rank_value(rank) > _rank_value(best_rank):
		improvements["rank"] = {"old": best_rank, "new": rank}
		best_rank = rank
	
	# Update status
	if is_secret_exit and not secret_exit_found:
		secret_exit_found = true
		status = LevelStatus.SECRET_FOUND
		improvements["secret_found"] = true
	elif status < LevelStatus.COMPLETED:
		status = LevelStatus.COMPLETED
	
	if rank == "S" and status < LevelStatus.PERFECT:
		status = LevelStatus.PERFECT
	
	return improvements

## Convert rank letter to numeric value for comparison
func _rank_value(rank: String) -> int:
	match rank:
		"S": return 6
		"A": return 5
		"B": return 4
		"C": return 3
		"D": return 2
		"E": return 1
		_: return 0

## Unlock the level
func unlock() -> void:
	if status == LevelStatus.LOCKED:
		status = LevelStatus.UNLOCKED

## Reset progress (for new game)
func reset() -> void:
	status = LevelStatus.LOCKED
	best_time = 0.0
	best_rings = 0
	best_score = 0
	best_rank = ""
	completion_count = 0
	secret_exit_found = false
	total_rings_collected = 0
	total_time_played = 0.0
	first_completion_date = 0
	best_score_date = 0
	custom_data.clear()

## Create for a new level
static func create_for_level(level_id: StringName, unlocked: bool = false) -> XtremeLevelProgress:
	var progress := XtremeLevelProgress.new()
	progress.level_id = level_id
	progress.status = LevelStatus.UNLOCKED if unlocked else LevelStatus.LOCKED
	return progress
