extends Node3D
class_name XtremeTestRailCourseBuilder

@export var regenerate_on_ready: bool = true
@export var base_height: float = 4.0


func _ready() -> void:
	if regenerate_on_ready:
		call_deferred("_rebuild_rails")


func _rebuild_rails() -> void:
	for child in get_children():
		child.queue_free()
	
	_add_flat_rail()
	_add_diagonal_rail()
	_add_loop_hills_rail()
	_add_horizontal_helix_rail()


func _create_rail(name: String, points: Array[Vector3], color: Color, closed: bool = false) -> void:
	var rail := XtremeTestGrindRail.new()
	rail.name = name
	rail.debug_color = color
	rail.curve = Curve3D.new()
	rail.curve.bake_interval = 0.25
	for point in points:
		rail.curve.add_point(point)
	rail.curve.closed = closed
	add_child(rail)


func _add_flat_rail() -> void:
	var points: Array[Vector3] = [
		Vector3(-34.0, base_height, -18.0),
		Vector3(34.0, base_height, -18.0),
	]
	_create_rail("RailFlat", points, Color(0.95, 0.95, 0.25))


func _add_diagonal_rail() -> void:
	var points: Array[Vector3] = [
		Vector3(-34.0, base_height, 2.0),
		Vector3(-8.0, base_height + 4.0, 10.0),
		Vector3(16.0, base_height + 10.0, 17.0),
		Vector3(34.0, base_height + 14.0, 22.0),
	]
	_create_rail("RailDiagonal", points, Color(0.25, 0.9, 0.95))


func _add_loop_hills_rail() -> void:
	var points: Array[Vector3] = []
	var count := 20
	for i in range(count):
		var t := float(i) / float(count)
		var angle := t * TAU
		var x := cos(angle) * 25.0
		var z := sin(angle) * 16.0 + 44.0
		var y := base_height + 8.0 + sin(angle * 2.0) * 3.0 + sin(angle * 5.0) * 1.4
		points.append(Vector3(x, y, z))
	_create_rail("RailLoopHills", points, Color(1.0, 0.55, 0.25), true)


func _add_horizontal_helix_rail() -> void:
	var points: Array[Vector3] = []
	var count := 88
	for i in range(count):
		var t := float(i) / float(count - 1)
		var angle := t * TAU * 3.2
		var x := -32.0 + t * 72.0
		var y := base_height + 8.0 + cos(angle) * 4.0
		var z := 74.0 + sin(angle) * 4.0
		points.append(Vector3(x, y, z))
	_create_rail("RailHelixHorizontal", points, Color(0.95, 0.25, 0.95))
