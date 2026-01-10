@tool
class_name XtremeGrindRail
extends Resource
## Grind Rail - A rail path for grinding sequences (cell-aware with Bezier curves)

## Unique identifier
@export var rail_id: StringName = &""

## Display name
@export var display_name: String = "Grind Rail"

## Control points for the Bezier curve (in grid cell coordinates)
@export var control_points: Array[Vector3] = []

## Cells occupied by this rail (for collision detection in editor)
@export var occupied_cells: Array[Vector3i] = []

@export_group("Rail Properties")

## Rail speed multiplier (1.0 = normal)
@export var speed_multiplier: float = 1.0

## Can player jump off this rail?
@export var allow_jump_off: bool = true

## Can player crouch to go faster?
@export var allow_crouch_boost: bool = true

## Crouch speed multiplier
@export var crouch_speed_multiplier: float = 1.5

## Does rail loop back to start?
@export var is_loop: bool = false

@export_group("Branching")

## Connected rails at the end (branching)
@export var branch_connections: Array[StringName] = []

## Default branch if no input
@export var default_branch: StringName = &""

## Branch input directions (matches branch_connections indices)
## 0=none, 1=left, 2=right
@export var branch_directions: Array[int] = []

@export_group("Streaming")

## Chunk sets this rail passes through (for pre-loading)
@export var chunks_traversed: Array[StringName] = []

@export_group("Visuals")

## Editor color
@export var editor_color: Color = Color.YELLOW

## Rail mesh scene (optional, for custom visuals)
@export var rail_scene: PackedScene

## Rail width for mesh generation
@export var rail_width: float = 0.3

## Get a point along the rail (t: 0.0 to 1.0)
func get_point_at(t: float) -> Vector3:
	if control_points.size() < 2:
		return Vector3.ZERO
	
	t = clampf(t, 0.0, 1.0)
	
	if control_points.size() == 2:
		# Linear interpolation
		return control_points[0].lerp(control_points[1], t)
	elif control_points.size() == 3:
		# Quadratic Bezier
		return _quadratic_bezier(control_points[0], control_points[1], control_points[2], t)
	elif control_points.size() >= 4:
		# Cubic Bezier (using first 4 points, or chained for more)
		return _cubic_bezier(control_points[0], control_points[1], control_points[2], control_points[3], t)
	
	return Vector3.ZERO

## Get the tangent (direction) at a point on the rail
func get_tangent_at(t: float) -> Vector3:
	var delta := 0.01
	var p1 := get_point_at(t)
	var p2 := get_point_at(minf(t + delta, 1.0))
	return (p2 - p1).normalized()

## Get total length of the rail (approximation)
func get_length() -> float:
	var length := 0.0
	var segments := 20
	var prev := get_point_at(0.0)
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var point := get_point_at(t)
		length += prev.distance_to(point)
		prev = point
	return length

## Calculate which cells this rail occupies
func calculate_occupied_cells(cell_size: Vector3) -> void:
	occupied_cells.clear()
	
	var length := get_length()
	var step := minf(cell_size.x, cell_size.z) * 0.5
	var steps := int(length / step) + 1
	
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var world_pos := get_point_at(t)
		var cell := Vector3i(
			floori(world_pos.x / cell_size.x),
			floori(world_pos.y / cell_size.y),
			floori(world_pos.z / cell_size.z)
		)
		if cell not in occupied_cells:
			occupied_cells.append(cell)

## Check if a cell is occupied by this rail
func occupies_cell(cell: Vector3i) -> bool:
	return cell in occupied_cells

## Add a control point
func add_control_point(point: Vector3) -> void:
	control_points.append(point)

## Insert a control point at index
func insert_control_point(index: int, point: Vector3) -> void:
	control_points.insert(index, point)

## Remove a control point
func remove_control_point(index: int) -> void:
	if index >= 0 and index < control_points.size():
		control_points.remove_at(index)

## Move a control point
func move_control_point(index: int, new_pos: Vector3) -> void:
	if index >= 0 and index < control_points.size():
		control_points[index] = new_pos

func _quadratic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var q0 := p0.lerp(p1, t)
	var q1 := p1.lerp(p2, t)
	return q0.lerp(q1, t)

func _cubic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var q0 := p0.lerp(p1, t)
	var q1 := p1.lerp(p2, t)
	var q2 := p2.lerp(p3, t)
	var r0 := q0.lerp(q1, t)
	var r1 := q1.lerp(q2, t)
	return r0.lerp(r1, t)

## Create a simple straight rail
static func create_straight(start: Vector3, end: Vector3) -> XtremeGrindRail:
	var rail := XtremeGrindRail.new()
	rail.rail_id = StringName("rail_%d" % randi())
	rail.control_points = [start, end]
	return rail

## Create a curved rail with control point
static func create_curved(start: Vector3, control: Vector3, end: Vector3) -> XtremeGrindRail:
	var rail := XtremeGrindRail.new()
	rail.rail_id = StringName("rail_%d" % randi())
	rail.control_points = [start, control, end]
	return rail
