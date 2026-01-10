extends Node
class_name XtremeGameManager
## Central game manager coordinating levels, saves, and world map

## Game states
enum GameState {
	BOOT,           ## Initial loading
	TITLE,          ## Title screen
	SAVE_SELECT,    ## Save file selection
	WORLD_MAP,      ## World map navigation
	LEVEL_LOADING,  ## Loading a level
	PLAYING,        ## In-level gameplay
	PAUSED,         ## Game paused
	LEVEL_COMPLETE, ## Level completion screen
	GAME_OVER       ## Game over screen
}

## Current game state
var state: GameState = GameState.BOOT:
	set(value):
		var old := state
		state = value
		state_changed.emit(old, value)

## Emitted when game state changes
signal state_changed(old_state: GameState, new_state: GameState)

## Emitted when level starts
signal level_started(level_id: StringName)

## Emitted when level completes
signal level_completed(results: Dictionary)

## Emitted when returning to world map
signal returned_to_world_map

## Save manager instance
var save_manager: XtremeSaveManager

## Level completion system instance
var level_completion: XtremeLevelCompletion

## World map controller instance
var world_map_controller: XtremeWorldMapController

## Spawn manager instance
var spawn_manager: XtremeSpawnManager

## Currently loaded level manifest
var current_level_manifest: XtremeLevelManifest

## Currently loaded chunk set
var current_chunk_set: XtremeChunkSetData

## Current level ID being played
var current_level_id: StringName = &""

## All world maps (loaded at game start)
var world_maps: Dictionary = {}  # world_id -> XtremeWorldMap

## Player node reference
var player: Node3D

func _ready() -> void:
	# Create subsystems
	save_manager = XtremeSaveManager.new()
	save_manager.name = "SaveManager"
	add_child(save_manager)
	
	level_completion = XtremeLevelCompletion.new()
	level_completion.name = "LevelCompletion"
	add_child(level_completion)
	
	world_map_controller = XtremeWorldMapController.new()
	world_map_controller.name = "WorldMapController"
	add_child(world_map_controller)
	
	spawn_manager = XtremeSpawnManager.new()
	spawn_manager.name = "SpawnManager"
	add_child(spawn_manager)
	
	# Connect signals
	world_map_controller.level_selected.connect(_on_level_selected)
	level_completion.tally_completed.connect(_on_tally_completed)

## Initialize with a save slot
func start_game(slot_id: int) -> bool:
	if save_manager.load_and_set_current(slot_id):
		world_map_controller.world_progress = save_manager.current_progress
		state = GameState.WORLD_MAP
		return true
	return false

## Create new game
func new_game(slot_id: int, player_name: String = "Player") -> bool:
	var progress := save_manager.create_new_save(slot_id, player_name)
	if progress:
		world_map_controller.world_progress = progress
		_unlock_starting_content()
		state = GameState.WORLD_MAP
		return true
	return false

## Unlock starting content for new game
func _unlock_starting_content() -> void:
	var progress := save_manager.current_progress
	if not progress:
		return
	
	# Unlock first world
	if not world_maps.is_empty():
		var first_world_id: StringName = world_maps.keys()[0]
		progress.unlock_world(first_world_id)
		
		# Unlock first level in first world
		var first_world: XtremeWorldMap = world_maps[first_world_id]
		if first_world and first_world.start_node != &"":
			progress.unlock_level(first_world.start_node)

## Load a world map
func load_world_map(world_id: StringName) -> bool:
	if world_id not in world_maps:
		push_error("XtremeGameManager: World '%s' not found" % world_id)
		return false
	
	world_map_controller.world_map = world_maps[world_id]
	
	# Teleport to start or last visited node
	var progress := save_manager.current_progress
	if progress and progress.last_played_level != &"":
		# Try to teleport to last played level if in this world
		if world_map_controller.world_map.get_node(progress.last_played_level):
			world_map_controller.teleport_to(progress.last_played_level)
		else:
			world_map_controller.teleport_to(world_maps[world_id].start_node)
	else:
		world_map_controller.teleport_to(world_maps[world_id].start_node)
	
	return true

## Called when a level is selected from world map
func _on_level_selected(level_id: StringName) -> void:
	start_level(level_id)

## Start a level
func start_level(level_id: StringName) -> void:
	current_level_id = level_id
	state = GameState.LEVEL_LOADING
	
	# Load level manifest
	# In a full implementation, you'd load the actual level scene here
	# For now, this is a framework
	
	# Start level tracking
	level_completion.start_level()
	
	state = GameState.PLAYING
	level_started.emit(level_id)

## Complete current level (called when player reaches goal)
func complete_level(is_secret_exit: bool = false) -> void:
	if state != GameState.PLAYING:
		return
	
	state = GameState.LEVEL_COMPLETE
	
	# Calculate results
	var results := level_completion.complete_level(is_secret_exit)
	
	# Record in save
	var progress := save_manager.current_progress
	if progress:
		var improvements := progress.record_level_completion(
			current_level_id,
			results["time"],
			level_completion.rings_collected,
			results["total"],
			results["rank"],
			is_secret_exit
		)
		results["improvements"] = improvements
		
		# Unlock next levels based on level manifest
		_unlock_next_levels(is_secret_exit)
		
		# Save progress
		save_manager.save_current()
	
	level_completed.emit(results)

## Unlock levels that follow the completed level
func _unlock_next_levels(was_secret_exit: bool) -> void:
	if not current_level_manifest:
		return
	
	var progress := save_manager.current_progress
	if not progress:
		return
	
	# Find goal portals and unlock their target levels
	if current_chunk_set:
		for goal in current_chunk_set.goal_portals:
			if was_secret_exit and goal.goal_type == XtremeGoalPortal.GoalType.SECRET:
				if goal.unlocks_secret_level and goal.secret_level_id:
					progress.unlock_level(StringName(goal.secret_level_id))
			elif not was_secret_exit and goal.goal_type == XtremeGoalPortal.GoalType.STANDARD:
				if goal.unlocks_level:
					progress.unlock_level(StringName(goal.unlocks_level))

## Called when tally animation completes
func _on_tally_completed(results: Dictionary) -> void:
	# UI can now show "Press any button to continue"
	pass

## Return to world map
func return_to_world_map() -> void:
	current_level_id = &""
	current_level_manifest = null
	current_chunk_set = null
	
	state = GameState.WORLD_MAP
	returned_to_world_map.emit()

## Pause game
func pause() -> void:
	if state == GameState.PLAYING:
		state = GameState.PAUSED
		get_tree().paused = true

## Resume game
func resume() -> void:
	if state == GameState.PAUSED:
		state = GameState.PLAYING
		get_tree().paused = false

## Restart current level
func restart_level() -> void:
	if current_level_id != &"":
		start_level(current_level_id)

## Quit to title
func quit_to_title() -> void:
	save_manager.save_current()
	current_level_id = &""
	current_level_manifest = null
	current_chunk_set = null
	state = GameState.TITLE

## Add rings to current level
func add_rings(count: int) -> void:
	if state == GameState.PLAYING:
		level_completion.add_rings(count)

## Record damage taken
func take_damage(amount: int = 1) -> void:
	if state == GameState.PLAYING:
		level_completion.take_damage(amount)

## Get current save progress
func get_progress() -> XtremeWorldProgress:
	return save_manager.current_progress

## Register a world map
func register_world(world_map: XtremeWorldMap) -> void:
	world_maps[world_map.world_id] = world_map

## Get formatted time for current level
func get_current_time_formatted() -> String:
	if level_completion:
		var elapsed := (Time.get_ticks_msec() / 1000.0) - level_completion.level_start_time
		return XtremeLevelCompletion.format_time(elapsed)
	return "0:00.00"

## Get current ring count
func get_current_rings() -> int:
	if level_completion:
		return level_completion.rings_collected
	return 0
