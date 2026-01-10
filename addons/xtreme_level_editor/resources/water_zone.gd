@tool
class_name XtremeWaterZone
extends Resource
## Water Zone - Defines an area of water for swimming/underwater sections

## Water types
enum WaterType {
	NORMAL,         ## Standard water (swimming)
	SHALLOW,        ## Shallow water (wading, no swimming)
	DEEP,           ## Deep water (can drown if no air)
	HAZARDOUS,      ## Damaging water (acid, lava-like)
	CURRENT,        ## Water with strong current
	BUBBLE          ## Breathable underwater area
}

## Unique identifier
@export var zone_id: StringName = &""

## Type of water
@export var water_type: WaterType = WaterType.NORMAL

## Display name
@export var display_name: String = "Water Zone"

@export_group("Bounds")

## Minimum corner (grid cells)
@export var bounds_min: Vector3i = Vector3i.ZERO

## Maximum corner (grid cells)
@export var bounds_max: Vector3i = Vector3i(4, 2, 4)

## Surface Y level (grid cells) - where the water surface is
@export var surface_level: int = 2

@export_group("Properties")

## Does this water have a current?
@export var has_current: bool = false

## Current direction (normalized)
@export var current_direction: Vector3 = Vector3.ZERO

## Current strength (units per second)
@export var current_strength: float = 0.0

## Damage per second (for hazardous water)
@export var damage_per_second: float = 0.0

## Can player breathe in this water? (for bubble zones)
@export var is_breathable: bool = false

## Buoyancy multiplier (1.0 = normal, higher = more floaty)
@export var buoyancy: float = 1.0

## Drag multiplier (1.0 = normal, higher = slower movement)
@export var drag: float = 1.0

@export_group("Visuals")

## Water color tint
@export var water_color: Color = Color(0.2, 0.4, 0.8, 0.5)

## Surface color
@export var surface_color: Color = Color(0.3, 0.5, 0.9, 0.7)

## Editor color for visualization
@export var editor_color: Color = Color(0.2, 0.4, 0.8, 0.3)

## Use custom water shader?
@export var use_custom_shader: bool = false

## Custom shader path
@export var custom_shader_path: String = ""

## Get water type name
func get_water_type_name() -> String:
	match water_type:
		WaterType.NORMAL: return "Normal"
		WaterType.SHALLOW: return "Shallow"
		WaterType.DEEP: return "Deep"
		WaterType.HAZARDOUS: return "Hazardous"
		WaterType.CURRENT: return "Current"
		WaterType.BUBBLE: return "Bubble Zone"
	return "Unknown"

## Get world-space bounds
func get_world_bounds(cell_size: Vector3) -> AABB:
	var min_world := Vector3(bounds_min) * cell_size
	var max_world := Vector3(bounds_max + Vector3i.ONE) * cell_size
	return AABB(min_world, max_world - min_world)

## Get surface world Y position
func get_surface_world_y(cell_size_y: float) -> float:
	return surface_level * cell_size_y

## Check if a world position is underwater
func is_position_underwater(world_pos: Vector3, cell_size: Vector3) -> bool:
	var bounds := get_world_bounds(cell_size)
	if not bounds.has_point(world_pos):
		return false
	return world_pos.y < get_surface_world_y(cell_size.y)

## Check if a world position is at surface
func is_position_at_surface(world_pos: Vector3, cell_size: Vector3, tolerance: float = 0.5) -> bool:
	var bounds := get_world_bounds(cell_size)
	if not bounds.has_point(Vector3(world_pos.x, bounds.position.y, world_pos.z)):
		return false
	var surface_y := get_surface_world_y(cell_size.y)
	return absf(world_pos.y - surface_y) < tolerance

## Create a simple water zone
static func create_zone(min_pos: Vector3i, max_pos: Vector3i, surface_y: int = -1) -> XtremeWaterZone:
	var zone := XtremeWaterZone.new()
	zone.zone_id = StringName("water_%d_%d_%d" % [min_pos.x, min_pos.y, min_pos.z])
	zone.bounds_min = min_pos
	zone.bounds_max = max_pos
	zone.surface_level = surface_y if surface_y >= 0 else max_pos.y
	return zone

## Create hazardous water (acid, etc.)
static func create_hazardous(min_pos: Vector3i, max_pos: Vector3i, damage: float = 10.0) -> XtremeWaterZone:
	var zone := create_zone(min_pos, max_pos)
	zone.water_type = WaterType.HAZARDOUS
	zone.damage_per_second = damage
	zone.water_color = Color(0.6, 0.8, 0.2, 0.6)  # Greenish
	zone.editor_color = Color(0.6, 0.8, 0.2, 0.3)
	zone.display_name = "Hazardous Water"
	return zone

## Create water with current
static func create_with_current(min_pos: Vector3i, max_pos: Vector3i, direction: Vector3, strength: float) -> XtremeWaterZone:
	var zone := create_zone(min_pos, max_pos)
	zone.water_type = WaterType.CURRENT
	zone.has_current = true
	zone.current_direction = direction.normalized()
	zone.current_strength = strength
	zone.display_name = "Water (Current)"
	return zone
