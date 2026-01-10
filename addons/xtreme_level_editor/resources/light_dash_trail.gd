@tool
class_name XtremeLightDashTrail
extends Resource
## Light Dash Trail - A cell-based ring trail for high-speed traversal

## Unique identifier
@export var trail_id: StringName = &""

## Display name
@export var display_name: String = "Light Dash Trail"

## Ring positions (grid cell coordinates)
@export var ring_positions: Array[Vector3i] = []

## Ring types (matches ring_positions indices)
## true = dedicated light dash ring (transparent, auto-replenish)
## false = regular collectible ring
@export var is_dedicated_ring: Array[bool] = []

@export_group("Trail Properties")

## Speed of light dash
@export var dash_speed: float = 30.0

## Can this trail be used with regular rings?
@export var works_with_regular_rings: bool = true

## Activation radius (how close player needs to be to start)
@export var activation_radius: float = 3.0

## Does the trail loop?
@export var is_loop: bool = false

## Time between rings during dash
@export var ring_interval: float = 0.05

@export_group("Ring Properties")

## Do dedicated rings auto-replenish after use?
@export var auto_replenish: bool = true

## Replenish delay in seconds
@export var replenish_delay: float = 3.0

## Are dedicated rings visible (or transparent)?
@export var dedicated_rings_visible: bool = false

## Dedicated ring transparency (if visible)
@export var dedicated_ring_alpha: float = 0.3

@export_group("Streaming")

## Chunk sets this trail passes through
@export var chunks_traversed: Array[StringName] = []

@export_group("Visuals")

## Editor color
@export var editor_color: Color = Color.CYAN

## Ring mesh scene (optional, for custom ring visuals)
@export var ring_scene: PackedScene

## Get world position of a ring
func get_ring_world_position(index: int, cell_size: Vector3) -> Vector3:
	if index < 0 or index >= ring_positions.size():
		return Vector3.ZERO
	
	var cell := ring_positions[index]
	return Vector3(
		cell.x * cell_size.x + cell_size.x / 2.0,
		cell.y * cell_size.y + cell_size.y / 2.0,
		cell.z * cell_size.z + cell_size.z / 2.0
	)

## Get all ring world positions
func get_all_ring_positions(cell_size: Vector3) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for i in range(ring_positions.size()):
		positions.append(get_ring_world_position(i, cell_size))
	return positions

## Get the start position of the trail
func get_start_position(cell_size: Vector3) -> Vector3:
	if ring_positions.is_empty():
		return Vector3.ZERO
	return get_ring_world_position(0, cell_size)

## Get the end position of the trail
func get_end_position(cell_size: Vector3) -> Vector3:
	if ring_positions.is_empty():
		return Vector3.ZERO
	return get_ring_world_position(ring_positions.size() - 1, cell_size)

## Get total length of the trail
func get_length(cell_size: Vector3) -> float:
	if ring_positions.size() < 2:
		return 0.0
	
	var length := 0.0
	for i in range(1, ring_positions.size()):
		var p1 := get_ring_world_position(i - 1, cell_size)
		var p2 := get_ring_world_position(i, cell_size)
		length += p1.distance_to(p2)
	return length

## Get estimated dash duration
func get_dash_duration(cell_size: Vector3) -> float:
	var length := get_length(cell_size)
	if dash_speed > 0:
		return length / dash_speed
	return 0.0

## Add a ring to the trail
func add_ring(cell: Vector3i, is_dedicated: bool = true) -> void:
	ring_positions.append(cell)
	is_dedicated_ring.append(is_dedicated)

## Insert a ring at index
func insert_ring(index: int, cell: Vector3i, is_dedicated: bool = true) -> void:
	ring_positions.insert(index, cell)
	is_dedicated_ring.insert(index, is_dedicated)

## Remove a ring
func remove_ring(index: int) -> void:
	if index >= 0 and index < ring_positions.size():
		ring_positions.remove_at(index)
		if index < is_dedicated_ring.size():
			is_dedicated_ring.remove_at(index)

## Move a ring
func move_ring(index: int, new_cell: Vector3i) -> void:
	if index >= 0 and index < ring_positions.size():
		ring_positions[index] = new_cell

## Check if a cell has a ring
func has_ring_at(cell: Vector3i) -> bool:
	return cell in ring_positions

## Get ring index at cell (-1 if none)
func get_ring_index_at(cell: Vector3i) -> int:
	return ring_positions.find(cell)

## Check if trail is valid (has at least 2 rings)
func is_valid() -> bool:
	return ring_positions.size() >= 2

## Generate a straight trail between two points
static func create_straight(start: Vector3i, end: Vector3i, dedicated: bool = true) -> XtremeLightDashTrail:
	var trail := XtremeLightDashTrail.new()
	trail.trail_id = StringName("trail_%d" % randi())
	
	# Bresenham-like line in 3D
	var delta := end - start
	var steps := maxi(maxi(abs(delta.x), abs(delta.y)), abs(delta.z))
	
	if steps == 0:
		trail.add_ring(start, dedicated)
		return trail
	
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var cell := Vector3i(
			roundi(start.x + delta.x * t),
			roundi(start.y + delta.y * t),
			roundi(start.z + delta.z * t)
		)
		if not trail.has_ring_at(cell):
			trail.add_ring(cell, dedicated)
	
	return trail

## Auto-generate trail between placed rings (fill gaps)
func auto_fill_gaps() -> void:
	if ring_positions.size() < 2:
		return
	
	var new_positions: Array[Vector3i] = []
	var new_dedicated: Array[bool] = []
	
	for i in range(ring_positions.size() - 1):
		var start := ring_positions[i]
		var end := ring_positions[i + 1]
		var start_dedicated := is_dedicated_ring[i] if i < is_dedicated_ring.size() else true
		
		new_positions.append(start)
		new_dedicated.append(start_dedicated)
		
		# Fill gap between start and end
		var delta := end - start
		var steps := maxi(maxi(abs(delta.x), abs(delta.y)), abs(delta.z))
		
		if steps > 1:
			for j in range(1, steps):
				var t := float(j) / float(steps)
				var cell := Vector3i(
					roundi(start.x + delta.x * t),
					roundi(start.y + delta.y * t),
					roundi(start.z + delta.z * t)
				)
				if cell not in new_positions:
					new_positions.append(cell)
					new_dedicated.append(start_dedicated)
	
	# Add last ring
	new_positions.append(ring_positions[ring_positions.size() - 1])
	var last_dedicated := is_dedicated_ring[ring_positions.size() - 1] if ring_positions.size() - 1 < is_dedicated_ring.size() else true
	new_dedicated.append(last_dedicated)
	
	ring_positions = new_positions
	is_dedicated_ring = new_dedicated
