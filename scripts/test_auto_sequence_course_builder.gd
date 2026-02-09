extends Node3D
class_name XtremeTestAutoSequenceCourseBuilder

@export var regenerate_on_ready: bool = true
@export var base_height: float = 6.0


func _ready() -> void:
	if regenerate_on_ready:
		call_deferred("_rebuild_sequences")


func _rebuild_sequences() -> void:
	for child in get_children():
		child.queue_free()

	_add_horizontal_spiral_auto_trail()
	_add_vertical_spiral_auto_trail()
	_add_shuttle_loop_coaster()
	_add_straight_coaster()


func _create_sequence(
	name: String,
	sequence_type: XtremeTestAutoSequencePath.SequenceType,
	points: Array[Vector3],
	color: Color,
	speed: float,
	exit_jump_velocity: float,
	mount_offset: float
) -> XtremeTestAutoSequencePath:
	var sequence := XtremeTestAutoSequencePath.new()
	sequence.name = name
	sequence.sequence_type = sequence_type
	sequence.auto_speed = speed
	sequence.exit_jump_velocity = exit_jump_velocity
	sequence.mount_height_offset = mount_offset
	sequence.entry_trigger_radius = 2.4
	sequence.debug_color = color
	sequence.curve = Curve3D.new()
	sequence.curve.bake_interval = 0.2
	for point in points:
		sequence.curve.add_point(point)
	add_child(sequence)
	return sequence


func _add_horizontal_spiral_auto_trail() -> void:
	var points: Array[Vector3] = []
	var center := Vector3(-94.0, base_height + 6.5, 58.0)
	var turns := 3.2
	var count := 130
	for i in range(count):
		var t := float(i) / float(count - 1)
		var angle := t * TAU * turns
		var radius := lerpf(18.0, 7.5, t)
		var x := center.x + cos(angle) * radius
		var y := center.y + t * 3.0
		var z := center.z + sin(angle) * radius
		points.append(Vector3(x, y, z))

	var sequence := _create_sequence(
		"AutoTrailHorizontalSpiral",
		XtremeTestAutoSequencePath.SequenceType.AUTO_TRAIL,
		points,
		Color(0.96, 0.9, 0.22, 1.0),
		24.0,
		11.0,
		0.9
	)
	sequence.debug_segment_length = 0.7


func _add_vertical_spiral_auto_trail() -> void:
	var points: Array[Vector3] = []
	var center := Vector3(-54.0, base_height + 4.0, 94.0)
	var turns := 2.7
	var count := 110
	for i in range(count):
		var t := float(i) / float(count - 1)
		var angle := t * TAU * turns
		var x := center.x + cos(angle) * 8.0
		var y := center.y + t * 26.0
		var z := center.z + sin(angle) * 8.0
		points.append(Vector3(x, y, z))

	var sequence := _create_sequence(
		"AutoTrailVerticalSpiral",
		XtremeTestAutoSequencePath.SequenceType.AUTO_TRAIL,
		points,
		Color(0.28, 0.95, 0.95, 1.0),
		24.0,
		12.0,
		0.9
	)
	sequence.debug_segment_length = 0.7


func _add_shuttle_loop_coaster() -> void:
	var points: Array[Vector3] = [
		Vector3(18.0, base_height + 5.0, 22.0),
		Vector3(32.0, base_height + 5.0, 22.0),
		Vector3(46.0, base_height + 5.0, 22.0),
		Vector3(58.0, base_height + 5.0, 22.0),
	]

	var loop_center := Vector3(78.0, base_height + 18.0, 22.0)
	var loop_radius := 13.0
	var loop_steps := 36
	for i in range(loop_steps + 1):
		var t := float(i) / float(loop_steps)
		var angle := -PI * 0.5 + t * TAU
		var x := loop_center.x + cos(angle) * loop_radius
		var y := loop_center.y + sin(angle) * loop_radius
		points.append(Vector3(x, y, loop_center.z))

	points.append_array([
		Vector3(96.0, base_height + 10.0, 22.0),
		Vector3(112.0, base_height + 24.0, 22.0),
		Vector3(126.0, base_height + 10.0, 22.0),
		Vector3(110.0, base_height + 6.0, 22.0),
		Vector3(90.0, base_height + 12.0, 22.0),
		Vector3(68.0, base_height + 8.0, 22.0),
		Vector3(50.0, base_height + 5.0, 22.0),
	])

	var sequence := _create_sequence(
		"RollerCoasterShuttleLoop",
		XtremeTestAutoSequencePath.SequenceType.ROLLER_COASTER,
		points,
		Color(0.95, 0.45, 0.15, 1.0),
		26.0,
		12.0,
		1.0
	)
	sequence.coaster_track_width = 2.8
	sequence.coaster_track_height = 0.55
	sequence.coaster_color = Color(0.86, 0.4, 0.16, 1.0)


func _add_straight_coaster() -> void:
	var points: Array[Vector3] = [
		Vector3(20.0, base_height + 5.0, 108.0),
		Vector3(130.0, base_height + 5.0, 108.0),
	]

	var sequence := _create_sequence(
		"RollerCoasterStraight",
		XtremeTestAutoSequencePath.SequenceType.ROLLER_COASTER,
		points,
		Color(0.94, 0.52, 0.2, 1.0),
		23.0,
		11.0,
		1.0
	)
	sequence.coaster_track_width = 2.4
	sequence.coaster_track_height = 0.5
	sequence.coaster_color = Color(0.82, 0.35, 0.14, 1.0)
