@tool
class_name XtremeWorldMap
extends Resource
## World Map - Defines the structure of a world with level nodes and connections

## World identifier
@export var world_id: StringName = &""

## Display name
@export var display_name: String = "World 1"

## World description
@export var description: String = ""

## Level nodes in this world
@export var level_nodes: Array[XtremeWorldMapNode] = []

## Connections between nodes (for visual paths)
@export var connections: Array[XtremeWorldMapConnection] = []

## Starting node (where player begins in this world)
@export var start_node: StringName = &""

## World unlock requirements
@export_group("Unlock Requirements")

## Worlds that must be completed to unlock this one
@export var required_worlds: Array[StringName] = []

## Specific levels that must be completed to unlock
@export var required_levels: Array[StringName] = []

## Minimum total completion percentage required
@export var required_completion: float = 0.0

@export_group("Visuals")

## Background scene for world map
@export var background_scene: PackedScene

## World theme color
@export var theme_color: Color = Color.WHITE

## World icon
@export var icon: Texture2D

## Get a node by ID
func get_node(node_id: StringName) -> XtremeWorldMapNode:
	for node in level_nodes:
		if node.node_id == node_id:
			return node
	return null

## Get all nodes of a specific type
func get_nodes_by_type(type: XtremeWorldMapNode.NodeType) -> Array[XtremeWorldMapNode]:
	var result: Array[XtremeWorldMapNode] = []
	for node in level_nodes:
		if node.node_type == type:
			result.append(node)
	return result

## Get all level nodes
func get_level_nodes() -> Array[XtremeWorldMapNode]:
	return get_nodes_by_type(XtremeWorldMapNode.NodeType.LEVEL)

## Get connections from a node
func get_connections_from(node_id: StringName) -> Array[XtremeWorldMapConnection]:
	var result: Array[XtremeWorldMapConnection] = []
	for conn in connections:
		if conn.from_node == node_id:
			result.append(conn)
	return result

## Get connections to a node
func get_connections_to(node_id: StringName) -> Array[XtremeWorldMapConnection]:
	var result: Array[XtremeWorldMapConnection] = []
	for conn in connections:
		if conn.to_node == node_id:
			result.append(conn)
	return result

## Get adjacent nodes (connected to a node)
func get_adjacent_nodes(node_id: StringName) -> Array[StringName]:
	var adjacent: Array[StringName] = []
	for conn in connections:
		if conn.from_node == node_id and conn.to_node not in adjacent:
			adjacent.append(conn.to_node)
		if not conn.one_way and conn.to_node == node_id and conn.from_node not in adjacent:
			adjacent.append(conn.from_node)
	return adjacent

## Add a level node
func add_level_node(level_id: StringName, position: Vector2, display_name: String = "") -> XtremeWorldMapNode:
	var node := XtremeWorldMapNode.new()
	node.node_id = level_id
	node.node_type = XtremeWorldMapNode.NodeType.LEVEL
	node.level_id = level_id
	node.display_name = display_name if display_name else String(level_id)
	node.position = position
	level_nodes.append(node)
	
	if start_node == &"":
		start_node = level_id
	
	return node

## Add a connection between nodes
func add_connection(from: StringName, to: StringName, one_way: bool = false) -> XtremeWorldMapConnection:
	var conn := XtremeWorldMapConnection.new()
	conn.from_node = from
	conn.to_node = to
	conn.one_way = one_way
	connections.append(conn)
	return conn

## Check if world is unlocked based on progress
func is_unlocked(world_progress: XtremeWorldProgress) -> bool:
	# Check required worlds
	for req_world in required_worlds:
		if not world_progress.is_world_unlocked(req_world):
			return false
	
	# Check required levels
	for req_level in required_levels:
		if not world_progress.is_level_completed(req_level):
			return false
	
	# Check completion percentage
	if required_completion > 0.0 and world_progress.completion_percentage < required_completion:
		return false
	
	return true

## Create a simple linear world
static func create_linear(world_id: StringName, level_ids: Array[StringName]) -> XtremeWorldMap:
	var world := XtremeWorldMap.new()
	world.world_id = world_id
	world.display_name = String(world_id)
	
	var x := 0.0
	var prev_id: StringName = &""
	
	for level_id in level_ids:
		world.add_level_node(level_id, Vector2(x, 0))
		
		if prev_id != &"":
			world.add_connection(prev_id, level_id)
		
		prev_id = level_id
		x += 100.0
	
	return world
