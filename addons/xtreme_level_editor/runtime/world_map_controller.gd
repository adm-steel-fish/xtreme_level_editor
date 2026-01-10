extends Node
class_name XtremeWorldMapController
## Controls player navigation on the world map

## Emitted when player moves to a new node
signal node_changed(old_node: StringName, new_node: StringName)

## Emitted when player selects a level to play
signal level_selected(level_id: StringName)

## Emitted when navigation is blocked (locked path)
signal navigation_blocked(from_node: StringName, to_node: StringName, reason: String)

## Current world map
@export var world_map: XtremeWorldMap

## World progress for unlock checks
@export var world_progress: XtremeWorldProgress

## Current node the player is at
var current_node: StringName = &"":
	set(value):
		var old := current_node
		current_node = value
		if old != value:
			node_changed.emit(old, value)

## Movement speed on map (for animated movement)
@export var move_speed: float = 200.0

## Is player currently moving between nodes?
var _is_moving: bool = false
var _move_target: StringName = &""
var _move_progress: float = 0.0
var _move_start_pos: Vector2 = Vector2.ZERO
var _move_end_pos: Vector2 = Vector2.ZERO

## Visual representation of player on map
var player_visual: Node2D

func _ready() -> void:
	if world_map and world_map.start_node != &"":
		current_node = world_map.start_node

func _process(delta: float) -> void:
	if _is_moving and player_visual:
		_move_progress += delta * move_speed / _move_start_pos.distance_to(_move_end_pos)
		
		if _move_progress >= 1.0:
			_move_progress = 1.0
			_is_moving = false
			current_node = _move_target
			player_visual.position = _move_end_pos
		else:
			player_visual.position = _move_start_pos.lerp(_move_end_pos, _move_progress)

## Try to move in a direction
func try_move(direction: Vector2) -> bool:
	if _is_moving or not world_map:
		return false
	
	var current := world_map.get_node(current_node)
	if not current:
		return false
	
	# Find best matching adjacent node based on direction
	var adjacent := world_map.get_adjacent_nodes(current_node)
	var best_node: StringName = &""
	var best_dot: float = -2.0
	
	for adj_id in adjacent:
		var adj_node := world_map.get_node(adj_id)
		if not adj_node:
			continue
		
		# Check if path is unlocked
		if not _is_path_unlocked(current_node, adj_id):
			continue
		
		# Check if node is unlocked
		if not adj_node.is_unlocked(world_progress):
			continue
		
		# Calculate direction to this node
		var to_adj := (adj_node.position - current.position).normalized()
		var dot := direction.normalized().dot(to_adj)
		
		if dot > best_dot and dot > 0.3:  # Must be roughly in the right direction
			best_dot = dot
			best_node = adj_id
	
	if best_node != &"":
		return move_to(best_node)
	
	return false

## Move to a specific node
func move_to(target_node: StringName) -> bool:
	if _is_moving or not world_map:
		return false
	
	var current := world_map.get_node(current_node)
	var target := world_map.get_node(target_node)
	
	if not current or not target:
		return false
	
	# Check if there's a valid path
	if not _is_path_unlocked(current_node, target_node):
		navigation_blocked.emit(current_node, target_node, "Path is locked")
		return false
	
	# Check if target is unlocked
	if not target.is_unlocked(world_progress):
		navigation_blocked.emit(current_node, target_node, "Node is locked")
		return false
	
	# Start movement
	_is_moving = true
	_move_target = target_node
	_move_progress = 0.0
	_move_start_pos = current.position
	_move_end_pos = target.position
	
	return true

## Check if path between two nodes is unlocked
func _is_path_unlocked(from: StringName, to: StringName) -> bool:
	for conn in world_map.connections:
		if conn.from_node == from and conn.to_node == to:
			return conn.is_unlocked(world_progress)
		if not conn.one_way and conn.to_node == from and conn.from_node == to:
			return conn.is_unlocked(world_progress)
	return false

## Select the current level (start playing)
func select_current_level() -> bool:
	var node := world_map.get_node(current_node) if world_map else null
	
	if not node:
		return false
	
	if node.node_type != XtremeWorldMapNode.NodeType.LEVEL:
		return false
	
	if not node.is_unlocked(world_progress):
		navigation_blocked.emit(current_node, current_node, "Level is locked")
		return false
	
	level_selected.emit(node.level_id)
	return true

## Warp to another world (for WARP nodes)
func warp() -> Dictionary:
	var node := world_map.get_node(current_node) if world_map else null
	
	if not node or node.node_type != XtremeWorldMapNode.NodeType.WARP:
		return {}
	
	return {
		"target_world": node.warp_target_world,
		"target_node": node.warp_target_node
	}

## Get current node data
func get_current_node_data() -> XtremeWorldMapNode:
	if world_map:
		return world_map.get_node(current_node)
	return null

## Get available moves from current position
func get_available_moves() -> Array[StringName]:
	if not world_map:
		return []
	
	var available: Array[StringName] = []
	var adjacent := world_map.get_adjacent_nodes(current_node)
	
	for adj_id in adjacent:
		var adj_node := world_map.get_node(adj_id)
		if not adj_node:
			continue
		
		if not _is_path_unlocked(current_node, adj_id):
			continue
		
		if not adj_node.is_unlocked(world_progress):
			continue
		
		available.append(adj_id)
	
	return available

## Teleport to a node instantly (no animation)
func teleport_to(node_id: StringName) -> bool:
	if not world_map:
		return false
	
	var node := world_map.get_node(node_id)
	if not node:
		return false
	
	_is_moving = false
	current_node = node_id
	
	if player_visual:
		player_visual.position = node.position
	
	return true

## Get node positions for UI drawing
func get_all_node_positions() -> Dictionary:
	var positions := {}
	
	if world_map:
		for node in world_map.level_nodes:
			if node.is_visible(world_progress):
				positions[node.node_id] = {
					"position": node.position,
					"type": node.node_type,
					"unlocked": node.is_unlocked(world_progress),
					"status": node.get_status(world_progress)
				}
	
	return positions

## Get connection data for UI drawing
func get_all_connections() -> Array[Dictionary]:
	var conns: Array[Dictionary] = []
	
	if world_map:
		for conn in world_map.connections:
			if conn.is_visible(world_progress):
				var from_node := world_map.get_node(conn.from_node)
				var to_node := world_map.get_node(conn.to_node)
				
				if from_node and to_node:
					conns.append({
						"from": conn.from_node,
						"to": conn.to_node,
						"from_pos": from_node.position,
						"to_pos": to_node.position,
						"unlocked": conn.is_unlocked(world_progress),
						"one_way": conn.one_way,
						"type": conn.connection_type
					})
	
	return conns
