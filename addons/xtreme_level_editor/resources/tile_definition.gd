@tool
class_name XtremeTileDefinition
extends Resource

## Defines a single tile type with all its properties.
## Create one of these for each unique tile in your game.

## Unique identifier for this tile type
@export var tile_id: StringName = &"unknown"

## Display name shown in the editor palette
@export var display_name: String = "Unknown Tile"

## Category for organizing in palette (e.g., "Geometry", "Hazards", "Enemies")
@export var category: String = "Uncategorized"

## Color used for visualization in the editor
@export var editor_color: Color = Color.GRAY

## Icon texture for palette (optional)
@export var icon: Texture2D

@export_group("Size")
## Size of this object in cells (for multi-cell objects)
## Most tiles are 1x1x1, but larger objects like trees, buildings can span multiple cells
@export var cell_size: Vector3i = Vector3i(1, 1, 1):
	set(value):
		cell_size = Vector3i(
			clampi(value.x, 1, 9),
			clampi(value.y, 1, 9),
			clampi(value.z, 1, 9)
		)

## Whether this is a multi-cell object (calculated from cell_size)
func is_multicell() -> bool:
	return cell_size.x > 1 or cell_size.y > 1 or cell_size.z > 1

@export_group("Visual")
## The scene to instantiate for this tile (contains mesh, collision, etc.)
@export var tile_scene: PackedScene

## Preview mesh for editor visualization (if different from scene)
@export var preview_mesh: Mesh

@export_group("Behavior")
## Type classification
enum TileType {
	EMPTY,          ## Nothing - passable air
	SOLID,          ## Solid geometry - blocks movement
	PLATFORM,       ## One-way platform - passable from below
	HAZARD,         ## Damages player on contact
	ENEMY,          ## Enemy spawn point
	COLLECTIBLE,    ## Item/ring/collectible spawn
	CHECKPOINT,     ## Checkpoint/spawn point
	GOAL,           ## Level end trigger
	TRIGGER,        ## Generic trigger zone
	DECORATION,     ## Non-solid visual element
	RAIL,           ## Grindable rail segment
	SPRING,         ## Bounce pad/spring
	BOOST,          ## Speed boost pad
	WATER,          ## Water volume (swimming)
	TRANSPORT,      ## Pipe/door/warp zone (chunk set transition)
	SPAWN,          ## Player spawn point marker
}

@export var tile_type: TileType = TileType.SOLID

## Is this tile solid for collision purposes?
@export var is_solid: bool = true

## Can the player stand on top of this tile?
@export var is_standable: bool = true

## Does this tile damage the player?
@export var is_hazardous: bool = false

## Damage amount if hazardous
@export var damage_amount: int = 1

@export_group("Custom Properties")
## Custom properties that can be passed to the tile scene
## Useful for enemy patrol distance, spring force, etc.
@export var custom_properties: Dictionary = {}

@export_group("Generation")
## Weight for procedural placement (higher = more likely to be placed)
@export_range(0.0, 10.0) var generation_weight: float = 1.0

## Maximum consecutive placements allowed
@export var max_consecutive: int = -1  # -1 = unlimited

## Theme/biome tags this tile belongs to
@export var theme_tags: PackedStringArray = []

## Which faces can connect to other tiles (for WFC-style generation)
## Format: +X, -X, +Y, -Y, +Z, -Z
@export var connection_tags: Dictionary = {
	"positive_x": "default",
	"negative_x": "default",
	"positive_y": "default",
	"negative_y": "default",
	"positive_z": "default",
	"negative_z": "default",
}

@export_group("Traversal")
## Required traversal type to reach this tile from adjacent ground
@export var required_traversal: XtremeTraversalProfile.TraversalType = XtremeTraversalProfile.TraversalType.WALK

## Check if this tile can connect to another on a given face
func can_connect_to(other: XtremeTileDefinition, face: String) -> bool:
	if other == null:
		return true  # Can connect to empty space
	
	var opposite_face := _get_opposite_face(face)
	var my_tag: String = connection_tags.get(face, "default")
	var other_tag: String = other.connection_tags.get(opposite_face, "default")
	
	return my_tag == other_tag or my_tag == "any" or other_tag == "any"

func _get_opposite_face(face: String) -> String:
	match face:
		"positive_x": return "negative_x"
		"negative_x": return "positive_x"
		"positive_y": return "negative_y"
		"negative_y": return "positive_y"
		"positive_z": return "negative_z"
		"negative_z": return "positive_z"
	return face

## Check if this tile matches a theme
func matches_theme(theme: String) -> bool:
	return theme_tags.is_empty() or theme in theme_tags

## Get the footprint size after rotation
func get_rotated_size(rotation: Vector3i) -> Vector3i:
	var result := cell_size
	# Apply Y rotation (most common)
	if rotation.y % 2 == 1:  # 90 or 270 degrees
		result = Vector3i(result.z, result.y, result.x)
	# Apply X rotation
	if rotation.x % 2 == 1:
		result = Vector3i(result.x, result.z, result.y)
	# Apply Z rotation
	if rotation.z % 2 == 1:
		result = Vector3i(result.y, result.x, result.z)
	return result
