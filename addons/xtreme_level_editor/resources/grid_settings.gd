@tool
class_name XtremeGridSettings
extends Resource

## Global grid settings that affect all level editor instances.
## Change these to adjust cell sizes project-wide.

## Cell dimensions on X axis (in Godot units)
@export var cell_size_x: float = 2.0:
	set(value):
		cell_size_x = maxf(0.1, value)
		emit_changed()

## Cell dimensions on Y axis (in Godot units)
@export var cell_size_y: float = 2.0:
	set(value):
		cell_size_y = maxf(0.1, value)
		emit_changed()

## Cell dimensions on Z axis (in Godot units)
@export var cell_size_z: float = 2.0:
	set(value):
		cell_size_z = maxf(0.1, value)
		emit_changed()

## Returns cell size as Vector3
func get_cell_size() -> Vector3:
	return Vector3(cell_size_x, cell_size_y, cell_size_z)

## Sets all cell dimensions at once
func set_cell_size(size: Vector3) -> void:
	cell_size_x = size.x
	cell_size_y = size.y
	cell_size_z = size.z

## Convert grid coordinates to world position (center of cell)
func grid_to_world(grid_pos: Vector3i) -> Vector3:
	return Vector3(
		grid_pos.x * cell_size_x + cell_size_x * 0.5,
		grid_pos.y * cell_size_y + cell_size_y * 0.5,
		grid_pos.z * cell_size_z + cell_size_z * 0.5
	)

## Convert world position to grid coordinates
func world_to_grid(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_pos.x / cell_size_x),
		floori(world_pos.y / cell_size_y),
		floori(world_pos.z / cell_size_z)
	)
