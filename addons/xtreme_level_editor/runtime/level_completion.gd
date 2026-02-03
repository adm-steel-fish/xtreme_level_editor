extends Node
class_name XtremeLevelCompletion
## Handles level completion: score tally, rank calculation, and results

## Emitted when tally animation starts
signal tally_started

## Emitted during tally (for UI updates)
signal tally_progress(category: String, current: int, target: int)

## Emitted when tally completes
signal tally_completed(results: Dictionary)

## Emitted when rank is calculated
signal rank_calculated(rank: String, score: int)

## Rank thresholds (customizable per game)
@export var rank_thresholds: Dictionary = {
	"S": 50000,
	"A": 40000,
	"B": 30000,
	"C": 20000,
	"D": 10000,
	"E": 0
}

## Score values
@export_group("Score Values")
@export var ring_value: int = 100
@export var time_bonus_base: int = 10000
@export var time_bonus_decay: float = 0.01  # Per second
@export var secret_exit_bonus: int = 10000
@export var no_damage_bonus: int = 5000
@export var perfect_ring_bonus: int = 5000  # All rings in level collected

## Tally animation speed
@export_group("Tally Animation")
@export var tally_speed: float = 50.0  # Points per tick
@export var tally_tick_interval: float = 0.02  # Seconds between ticks

## Current level stats (set before completion)
var level_start_time: float = 0.0
var rings_collected: int = 0
var total_rings_in_level: int = 0
var damage_taken: int = 0
var is_secret_exit: bool = false
var custom_bonuses: Dictionary = {}  # Custom bonus name -> value

## Calculated results
var _completion_time: float = 0.0
var _final_score: int = 0
var _final_rank: String = ""
var _tally_results: Dictionary = {}

## Tally state
var _tallying: bool = false
var _current_tally_category: String = ""
var _tally_current: int = 0
var _tally_target: int = 0

## Start tracking a level
func start_level(total_rings: int = 0) -> void:
	level_start_time = Time.get_ticks_msec() / 1000.0
	rings_collected = 0
	total_rings_in_level = total_rings
	damage_taken = 0
	is_secret_exit = false
	custom_bonuses.clear()
	_final_score = 0
	_final_rank = ""
	_tally_results.clear()

## Add rings
func add_rings(count: int) -> void:
	rings_collected += count

## Record damage
func take_damage(amount: int = 1) -> void:
	damage_taken += amount

## Add a custom bonus
func add_bonus(name: String, value: int) -> void:
	custom_bonuses[name] = value

## Complete the level and calculate results
func complete_level(secret_exit: bool = false) -> Dictionary:
	is_secret_exit = secret_exit
	_completion_time = (Time.get_ticks_msec() / 1000.0) - level_start_time
	
	# Calculate all score components
	_tally_results = _calculate_score_breakdown()
	_final_score = _tally_results["total"]
	_final_rank = _calculate_rank(_final_score)
	
	_tally_results["rank"] = _final_rank
	_tally_results["time"] = _completion_time
	_tally_results["is_secret"] = is_secret_exit
	
	return _tally_results

## Calculate score breakdown
func _calculate_score_breakdown() -> Dictionary:
	var breakdown := {}
	var total := 0
	
	# Ring score
	var ring_score := rings_collected * ring_value
	breakdown["rings"] = ring_score
	total += ring_score
	
	# Time bonus (decreases with time)
	var time_bonus := maxi(0, int(time_bonus_base - (_completion_time * time_bonus_decay * time_bonus_base)))
	breakdown["time_bonus"] = time_bonus
	total += time_bonus
	
	# No damage bonus
	if damage_taken == 0:
		breakdown["no_damage"] = no_damage_bonus
		total += no_damage_bonus
	
	# Perfect rings bonus
	if total_rings_in_level > 0 and rings_collected >= total_rings_in_level:
		breakdown["perfect_rings"] = perfect_ring_bonus
		total += perfect_ring_bonus
	
	# Secret exit bonus
	if is_secret_exit:
		breakdown["secret_exit"] = secret_exit_bonus
		total += secret_exit_bonus
	
	# Custom bonuses
	for bonus_name in custom_bonuses:
		var bonus_value: int = custom_bonuses[bonus_name]
		breakdown[bonus_name] = bonus_value
		total += bonus_value
	
	breakdown["total"] = total
	return breakdown

## Calculate rank from score
func _calculate_rank(score: int) -> String:
	for rank in ["S", "A", "B", "C", "D", "E"]:
		if rank in rank_thresholds and score >= rank_thresholds[rank]:
			return rank
	return "E"

## Start animated tally (for results screen)
func start_tally() -> void:
	if _tally_results.is_empty():
		push_warning("XtremeLevelCompletion: No results to tally")
		return
	
	_tallying = true
	tally_started.emit()
	
	# Start coroutine for tally animation
	_run_tally()

## Run tally animation
func _run_tally() -> void:
	var categories := ["rings", "time_bonus", "no_damage", "perfect_rings", "secret_exit"]
	
	# Add custom bonuses
	for bonus_name in custom_bonuses:
		if bonus_name not in categories:
			categories.append(bonus_name)
	
	for category in categories:
		if category not in _tally_results or _tally_results[category] == 0:
			continue
		
		_current_tally_category = category
		_tally_target = _tally_results[category]
		_tally_current = 0
		
		while _tally_current < _tally_target:
			_tally_current = mini(_tally_current + int(tally_speed), _tally_target)
			tally_progress.emit(category, _tally_current, _tally_target)
			var tree := get_tree()
			if tree:
				await tree.create_timer(tally_tick_interval).timeout
			else:
				break
	
	_tallying = false
	tally_completed.emit(_tally_results)
	rank_calculated.emit(_final_rank, _final_score)

## Skip tally animation
func skip_tally() -> void:
	_tallying = false
	tally_completed.emit(_tally_results)
	rank_calculated.emit(_final_rank, _final_score)

## Get results without animation
func get_results() -> Dictionary:
	return _tally_results

## Get final rank
func get_rank() -> String:
	return _final_rank

## Get final score
func get_score() -> int:
	return _final_score

## Get completion time
func get_time() -> float:
	return _completion_time

## Format time for display (MM:SS.ms)
static func format_time(seconds: float) -> String:
	var minutes := int(seconds / 60)
	var secs := int(fmod(seconds, 60))
	var ms := int(fmod(seconds * 100, 100))
	return "%d:%02d.%02d" % [minutes, secs, ms]

## Format score with commas
static func format_score(score: int) -> String:
	var s := str(score)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result
