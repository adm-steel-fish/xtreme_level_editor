@tool
class_name XtremeRollerCoaster
extends Resource
## Roller Coaster - A free-form path for locked ride sequences

## Unique identifier
@export var coaster_id: StringName = &""

## Display name
@export var display_name: String = "Roller Coaster"

## Control points for the path (world coordinates, free-form)
@export var control_points: Array[Vector3] = []

## Tangent handles for smooth curves (one per control point)
@export var tangent_in: Array[Vector3] = []
@export var tangent_out: Array[Vector3] = []

@export_group("Ride Properties")

## Base speed of the coaster
@export var base_speed: float = 15.0

## Speed multiplier on downward slopes
@export var downhill_multiplier: float = 1.5

## Speed multiplier on upward slopes
@export var uphill_multiplier: float = 0.7

## Minimum speed (never goes below this)
@export var min_speed: float = 5.0

## Maximum speed (capped)
@export var max_speed: float = 40.0

## Duration of ride in seconds (calculated or manual)
@export var ride_duration: float = 0.0

## Is the player locked in (can't jump off)?
@export var locked_ride: bool = true

## Does the coaster loop back to start?
@export var is_loop: bool = false

@export_group("Entry/Exit")

## Entry point position (where player boards)
@export var entry_position: Vector3 = Vector3.ZERO

## Exit point position (where player disembarks)
@export var exit_position: Vector3 = Vector3.ZERO

## Entry trigger radius
@export var entry_radius: float = 2.0

@export_group("Streaming")

## Chunk sets this coaster passes through
@export var chunks_traversed: Array[StringName] = []

## Pre-load chunks at this percentage of ride completion
@export var preload_threshold: float = 0.3

@export_group("Visuals")

## Editor color
@export var editor_color: Color = Color.RED

## Track mesh scene (optional)
@export var track_scene: PackedScene

## Cart/car mesh scene (optional)  
@export var cart_scene: PackedScene

## Track width
@export var track_width: float = 1.0

## Get a point along the coaster (t: 0.0 to 1.0)
func get_point_at(t: float) -> Vector3:
	if control_points.size() < 2:
		return Vector3.ZERO
	
	t = clampf(t, 0.0, 1.0)
	
	# Find which segment we're on
	var num_segments := control_points.size() - 1
	var segment_t := t * num_segments
	var segment_index := mini(int(segment_t), num_segments - 1)
	var local_t := segment_t - segment_index
	
	# Hermite interpolation using tangents
	var p0 := control_points[segment_index]
	var p1 := control_points[segment_index + 1]
	var t0 := tangent_out[segment_index] if segment_index < tangent_out.size() else (p1 - p0)
	var t1 := tangent_in[segment_index + 1] if segment_index + 1 < tangent_in.size() else (p1 - p0)
	
	return _hermite_interpolate(p0, t0, p1, t1, local_t)

## Get the tangent at a point
func get_tangent_at(t: float) -> Vector3:
	var delta := 0.01
	var p1 := get_point_at(t)
	var p2 := get_point_at(minf(t + delta, 1.0))
	return (p2 - p1).normalized()

## Get the up vector at a point (for banking)
func get_up_at(t: float) -> Vector3:
	var tangent := get_tangent_at(t)
	var right := tangent.cross(Vector3.UP).normalized()
	return right.cross(tangent).normalized()

## Get transform at a point (position, rotation)
func get_transform_at(t: float) -> Transform3D:
	var pos := get_point_at(t)
	var forward := get_tangent_at(t)
	var up := get_up_at(t)
	var right := forward.cross(up).normalized()
	
	var basis := Basis(right, up, -forward)
	return Transform3D(basis, pos)

## Get speed at a point based on slope
func get_speed_at(t: float) -> float:
	var tangent := get_tangent_at(t)
	var slope := tangent.y  # Positive = uphill, Negative = downhill
	
	var speed := base_speed
	if slope < -0.1:
		speed *= downhill_multiplier * (1.0 + abs(slope))
	elif slope > 0.1:
		speed *= uphill_multiplier / (1.0 + slope)
	
	return clampf(speed, min_speed, max_speed)

## Get total length
func get_length() -> float:
	var length := 0.0
	var segments := 50
	var prev := get_point_at(0.0)
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var point := get_point_at(t)
		length += prev.distance_to(point)
		prev = point
	return length

## Calculate ride duration based on speed
func calculate_duration() -> void:
	var total_time := 0.0
	var segments := 100
	var prev_pos := get_point_at(0.0)
	
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var pos := get_point_at(t)
		var dist := prev_pos.distance_to(pos)
		var speed := get_speed_at(t)
		total_time += dist / speed
		prev_pos = pos
	
	ride_duration = total_time

## Add a control point with auto-generated tangents
func add_control_point(point: Vector3) -> void:
	control_points.append(point)
	
	# Auto-generate tangents
	if control_points.size() == 1:
		tangent_in.append(Vector3.FORWARD)
		tangent_out.append(Vector3.FORWARD)
	else:
		var prev := control_points[control_points.size() - 2]
		var dir := (point - prev).normalized() * 2.0
		tangent_in.append(dir)
		tangent_out.append(dir)
		# Update previous point's out tangent
		if tangent_out.size() >= 2:
			tangent_out[tangent_out.size() - 2] = dir

## Set tangent handles for a point
func set_tangents(index: int, t_in: Vector3, t_out: Vector3) -> void:
	if index >= 0 and index < control_points.size():
		if index < tangent_in.size():
			tangent_in[index] = t_in
		if index < tangent_out.size():
			tangent_out[index] = t_out

func _hermite_interpolate(p0: Vector3, t0: Vector3, p1: Vector3, t1: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	
	var h00 := 2*t3 - 3*t2 + 1
	var h10 := t3 - 2*t2 + t
	var h01 := -2*t3 + 3*t2
	var h11 := t3 - t2
	
	return p0 * h00 + t0 * h10 + p1 * h01 + t1 * h11

## Create a simple coaster with two points
static func create_simple(start: Vector3, end: Vector3) -> XtremeRollerCoaster:
	var coaster := XtremeRollerCoaster.new()
	coaster.coaster_id = StringName("coaster_%d" % randi())
	coaster.add_control_point(start)
	coaster.add_control_point(end)
	coaster.entry_position = start
	coaster.exit_position = end
	return coaster
