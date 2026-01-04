@tool
class_name XtremeTraversalProfile
extends Resource

## Defines the player's movement capabilities for procedural level generation.
## The generator uses these values to determine valid connections between areas.

@export_group("Basic Movement")
## Maximum horizontal distance the player can cover in a single jump (in cells)
@export var max_jump_distance_cells: int = 3

## Maximum height the player can jump (in cells)
@export var max_jump_height_cells: int = 2

## Maximum safe fall distance without damage (in cells)
@export var max_safe_fall_cells: int = 4

## Base run speed (used for timing calculations)
@export var run_speed: float = 10.0

@export_group("Special Abilities")
## Can the player double jump?
@export var can_double_jump: bool = false

## Additional height from double jump (in cells)
@export var double_jump_height_cells: int = 1

## Can the player wall jump?
@export var can_wall_jump: bool = false

## Can the player dash/boost?
@export var can_dash: bool = false

## Dash distance (in cells)
@export var dash_distance_cells: int = 2

@export_group("Advanced")
## Can traverse slopes (affects which angles are walkable)
@export var max_walkable_slope_degrees: float = 45.0

## Can the player grind on rails?
@export var can_grind: bool = false

## Enumeration of traversal types for tagging connections
enum TraversalType {
	WALK,           ## Simple horizontal movement
	JUMP_UP_1,      ## Jump up 1 cell
	JUMP_UP_2,      ## Jump up 2 cells
	JUMP_ACROSS_SHORT,  ## Jump 1-2 cells horizontally
	JUMP_ACROSS_LONG,   ## Jump 3+ cells horizontally
	FALL_SHORT,     ## Fall 1-2 cells
	FALL_LONG,      ## Fall 3+ cells
	DOUBLE_JUMP,    ## Requires double jump ability
	WALL_JUMP,      ## Requires wall jump ability
	DASH,           ## Requires dash ability
	GRIND,          ## Requires rail grinding
}

## Check if a traversal type is available with current abilities
func can_use_traversal(type: TraversalType) -> bool:
	match type:
		TraversalType.DOUBLE_JUMP:
			return can_double_jump
		TraversalType.WALL_JUMP:
			return can_wall_jump
		TraversalType.DASH:
			return can_dash
		TraversalType.GRIND:
			return can_grind
		_:
			return true

## Determine required traversal type between two grid positions
func get_required_traversal(from: Vector3i, to: Vector3i) -> TraversalType:
	var delta := to - from
	var horizontal_dist := Vector2(delta.x, delta.z).length()
	var vertical_dist := delta.y
	
	# Falling
	if vertical_dist < 0:
		if abs(vertical_dist) <= 2:
			return TraversalType.FALL_SHORT
		else:
			return TraversalType.FALL_LONG
	
	# Walking (same level, adjacent)
	if vertical_dist == 0 and horizontal_dist <= 1.5:
		return TraversalType.WALK
	
	# Jumping up
	if vertical_dist > 0:
		if vertical_dist == 1:
			return TraversalType.JUMP_UP_1
		elif vertical_dist == 2:
			return TraversalType.JUMP_UP_2
		else:
			# Needs special ability
			if can_double_jump and vertical_dist <= max_jump_height_cells + double_jump_height_cells:
				return TraversalType.DOUBLE_JUMP
			elif can_wall_jump:
				return TraversalType.WALL_JUMP
	
	# Horizontal jumping
	if horizontal_dist > 1.5:
		if horizontal_dist <= 2:
			return TraversalType.JUMP_ACROSS_SHORT
		else:
			return TraversalType.JUMP_ACROSS_LONG
	
	return TraversalType.WALK

## Check if traversal between two points is possible
func is_traversable(from: Vector3i, to: Vector3i) -> bool:
	var delta := to - from
	var horizontal_dist := Vector2(delta.x, delta.z).length()
	var vertical_dist := delta.y
	
	# Check fall distance
	if vertical_dist < -max_safe_fall_cells:
		return false
	
	# Check jump height
	var effective_jump_height := max_jump_height_cells
	if can_double_jump:
		effective_jump_height += double_jump_height_cells
	
	if vertical_dist > effective_jump_height:
		return false
	
	# Check horizontal distance
	var effective_jump_distance := max_jump_distance_cells
	if can_dash:
		effective_jump_distance += dash_distance_cells
	
	if horizontal_dist > effective_jump_distance:
		return false
	
	return true
