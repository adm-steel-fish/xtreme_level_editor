extends Path3D
class_name XtremeTestAutoSequencePath

enum SequenceType {
	AUTO_TRAIL,
	ROLLER_COASTER
}

@export var sequence_type: SequenceType = SequenceType.AUTO_TRAIL
@export var auto_speed: float = 24.0
@export var exit_jump_velocity: float = 12.0
@export var mount_height_offset: float = 0.9
@export var start_from_beginning: bool = true
@export var entry_trigger_radius: float = 2.2

@export_group("Visuals - Auto Trail")
@export var show_debug_mesh: bool = true
@export var debug_color: Color = Color(0.98, 0.9, 0.2, 1.0)
@export var debug_segment_length: float = 1.0

@export_group("Visuals - Roller Coaster")
@export var coaster_track_width: float = 2.2
@export var coaster_track_height: float = 0.5
@export var coaster_segment_length: float = 1.25
@export var coaster_side_rail_width: float = 0.2
@export var coaster_side_rail_height: float = 0.7
@export var coaster_color: Color = Color(0.84, 0.38, 0.16, 1.0)


func _ready() -> void:
	add_to_group("auto_sequence")
	_ensure_entry_trigger()
	_rebuild_visuals()


func _ensure_entry_trigger() -> void:
	var trigger := get_node_or_null("EntryTrigger") as Area3D
	if not trigger:
		trigger = Area3D.new()
		trigger.name = "EntryTrigger"
		add_child(trigger)

	trigger.position = curve.get_point_position(0) if curve and curve.get_point_count() > 0 else Vector3.ZERO
	if not trigger.body_entered.is_connected(_on_entry_trigger_body_entered):
		trigger.body_entered.connect(_on_entry_trigger_body_entered)

	var collision := trigger.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision:
		collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		trigger.add_child(collision)

	var sphere := collision.shape as SphereShape3D
	if not sphere:
		sphere = SphereShape3D.new()
		collision.shape = sphere
	sphere.radius = maxf(entry_trigger_radius, 0.25)

	var marker := trigger.get_node_or_null("EntryMarker") as MeshInstance3D
	if not marker:
		marker = MeshInstance3D.new()
		marker.name = "EntryMarker"
		trigger.add_child(marker)
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.35
	marker_mesh.height = 0.7
	marker.mesh = marker_mesh
	var marker_material: Material = RetroMaterial.create_unlit(debug_color, 1.2)
	if marker_material == null:
		var fallback := StandardMaterial3D.new()
		fallback.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fallback.albedo_color = debug_color
		marker_material = fallback
	marker.material_override = marker_material


func _rebuild_visuals() -> void:
	_rebuild_auto_trail_line()
	_rebuild_coaster_track()


func _rebuild_auto_trail_line() -> void:
	var debug_mesh := get_node_or_null("DebugMesh") as MeshInstance3D
	if not debug_mesh:
		debug_mesh = MeshInstance3D.new()
		debug_mesh.name = "DebugMesh"
		add_child(debug_mesh)

	var show_line := sequence_type == SequenceType.AUTO_TRAIL and show_debug_mesh
	debug_mesh.visible = show_line
	if not show_line or not curve or curve.get_point_count() < 2:
		debug_mesh.mesh = null
		return

	var length := curve.get_baked_length()
	if length <= 0.001:
		debug_mesh.mesh = null
		return

	var segments := maxi(8, int(ceili(length / maxf(debug_segment_length, 0.2))))
	var line_mesh := ImmediateMesh.new()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(segments):
		var d0 := length * (float(i) / float(segments))
		var d1 := length * (float(i + 1) / float(segments))
		line_mesh.surface_set_color(debug_color)
		line_mesh.surface_add_vertex(curve.sample_baked(d0, true))
		line_mesh.surface_add_vertex(curve.sample_baked(d1, true))
	line_mesh.surface_end()

	debug_mesh.mesh = line_mesh
	var material: Material = RetroMaterial.create_unlit(debug_color, 1.2)
	if material == null:
		var fallback := StandardMaterial3D.new()
		fallback.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fallback.albedo_color = debug_color
		material = fallback
	debug_mesh.material_override = material


func _rebuild_coaster_track() -> void:
	var root := get_node_or_null("TrackSegments") as Node3D
	if not root:
		root = Node3D.new()
		root.name = "TrackSegments"
		add_child(root)

	for child in root.get_children():
		child.queue_free()

	root.visible = sequence_type == SequenceType.ROLLER_COASTER
	if sequence_type != SequenceType.ROLLER_COASTER:
		return
	if not curve or curve.get_point_count() < 2:
		return

	var length := curve.get_baked_length()
	if length <= 0.001:
		return

	var steps := maxi(6, int(ceili(length / maxf(coaster_segment_length, 0.25))))
	var material: Material = RetroMaterial.create_standard(coaster_color)
	if material == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = coaster_color
		fallback.roughness = 0.75
		material = fallback

	for i in range(steps):
		var d0 := length * (float(i) / float(steps))
		var d1 := length * (float(i + 1) / float(steps))
		var p0 := curve.sample_baked(d0, true)
		var p1 := curve.sample_baked(d1, true)
		_add_track_segment(root, p0, p1, material, i)


func _add_track_segment(root: Node3D, p0: Vector3, p1: Vector3, material: StandardMaterial3D, index: int) -> void:
	var direction := p1 - p0
	var length := direction.length()
	if length <= 0.001:
		return

	var forward := direction / length
	var up := Vector3.UP
	if absf(forward.dot(up)) > 0.95:
		up = Vector3.FORWARD
	var basis := Basis.looking_at(forward, up)

	var segment := StaticBody3D.new()
	segment.name = "TrackSegment_%03d" % index
	var midpoint := (p0 + p1) * 0.5
	segment.transform = Transform3D(basis, midpoint - basis.y * (coaster_track_height * 0.5))
	root.add_child(segment)

	_add_track_box(segment, Vector3(coaster_track_width, coaster_track_height, length), Vector3.ZERO, material)

	var side_offset := (coaster_track_width * 0.5) - (coaster_side_rail_width * 0.5)
	var side_height_center := (coaster_track_height * 0.5) + (coaster_side_rail_height * 0.5)
	var side_size := Vector3(coaster_side_rail_width, coaster_side_rail_height, length)
	_add_track_box(segment, side_size, Vector3(side_offset, side_height_center, 0.0), material)
	_add_track_box(segment, side_size, Vector3(-side_offset, side_height_center, 0.0), material)


func _add_track_box(parent: Node3D, size: Vector3, local_pos: Vector3, material: StandardMaterial3D) -> void:
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	collision.position = local_pos
	parent.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_pos
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)


func _on_entry_trigger_body_entered(body: Node) -> void:
	if not (body is PlayerController):
		return
	var player := body as PlayerController
	if player.current_state == PlayerController.State.AUTO_PATH:
		return
	player.start_auto_path(self, auto_speed, start_from_beginning, exit_jump_velocity, mount_height_offset)
