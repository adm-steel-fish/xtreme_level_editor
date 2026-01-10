@tool
class_name XtremeSpawnPoint
extends Resource
## Spawn Point - A location where the player can spawn within a chunk set

## Unique identifier
@export var spawn_id: StringName = &""

## World position (in Godot units, not grid cells)
@export var position: Vector3 = Vector3.ZERO

## Rotation (Y-axis, in degrees)
@export var rotation_y: float = 0.0

## Is this the default spawn point for this chunk set?
@export var is_default: bool = false

## Display name for editor
@export var display_name: String = "Spawn Point"

## Optional: grid cell position (for editor use)
@export var grid_position: Vector3i = Vector3i.ZERO

## Get spawn transform
func get_transform() -> Transform3D:
	var t := Transform3D.IDENTITY
	t = t.rotated(Vector3.UP, deg_to_rad(rotation_y))
	t.origin = position
	return t
