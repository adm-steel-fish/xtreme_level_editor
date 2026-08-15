extends Path3D
class_name XtremeTestGrindRail

@export var show_debug_mesh: bool = true
@export var debug_color: Color = Color(0.1, 0.95, 1.0, 1.0)
@export var debug_segment_length: float = 1.0


func _ready() -> void:
	add_to_group("rails")
	add_to_group("targetable")
	_rebuild_debug_mesh()


func _rebuild_debug_mesh() -> void:
	var debug_mesh := get_node_or_null("DebugMesh") as MeshInstance3D
	if not debug_mesh:
		debug_mesh = MeshInstance3D.new()
		debug_mesh.name = "DebugMesh"
		add_child(debug_mesh)
	
	debug_mesh.visible = show_debug_mesh
	if not show_debug_mesh or not curve or curve.get_point_count() < 2:
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
		var t0 := length * (float(i) / float(segments))
		var t1 := length * (float(i + 1) / float(segments))
		line_mesh.surface_set_color(debug_color)
		line_mesh.surface_add_vertex(curve.sample_baked(t0, true))
		line_mesh.surface_add_vertex(curve.sample_baked(t1, true))
	line_mesh.surface_end()
	
	debug_mesh.mesh = line_mesh
	# Use the curved-world retro shader so the rail bends with the level it
	# sits on; a StandardMaterial3D would render dead straight through it.
	var material: Material = RetroMaterial.create_unlit(debug_color, 1.2)
	if material == null:
		var fallback := StandardMaterial3D.new()
		fallback.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fallback.albedo_color = debug_color
		fallback.no_depth_test = false
		material = fallback
	debug_mesh.material_override = material
