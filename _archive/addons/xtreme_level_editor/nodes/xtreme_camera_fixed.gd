class_name XtremeCameraFixed
extends Camera3D

## Xtreme Fixed Camera System
## 
## This is a more authentic recreation of the Sonic Xtreme camera behavior:
## - Camera is ALWAYS positioned relative to a fixed world axis
## - Camera NEVER rotates - it always faces the same direction
## - The curved world shader creates the illusion of the world wrapping around the player
## - Player movement appears to "rotate" the world beneath them
##
## This creates the distinctive Sonic Xtreme feel where you're always
## looking in one direction while the world curves around you.

## The player/target to follow
@export var target: Node3D

@export_group("Camera Position")
## Which world axis the camera looks along
enum CameraAxis {
	NEGATIVE_Z,  ## Camera looks toward -Z (default forward)
	POSITIVE_Z,  ## Camera looks toward +Z
	NEGATIVE_X,  ## Camera looks toward -X
	POSITIVE_X,  ## Camera looks toward +X
}
@export var look_axis: CameraAxis = CameraAxis.NEGATIVE_Z

## Height offset above the target
@export var height_offset: float = 3.0

## Distance from target along the look axis
@export var distance: float = 10.0

## Pitch angle (tilt down to look at player)
@export_range(-45, 45) var pitch_degrees: float = -10.0

@export_group("Curved World")
## Automatically update all curved world shader materials
@export var auto_update_shaders: bool = true

## Cached shader materials (auto-populated if auto_update_shaders is true)
@export var shader_materials: Array[ShaderMaterial] = []

@export_group("Advanced")
## Lock Y position to target (camera moves up/down with player)
@export var follow_target_y: bool = true

## Y position if not following target (fixed camera height)
@export var fixed_y_position: float = 5.0

## Enable this if your level wraps around (experimental)
@export var wraparound_mode: bool = false

var _initialized: bool = false

func _ready() -> void:
	_setup_camera_orientation()
	
	if auto_update_shaders:
		# Wait a frame for scene to be fully loaded
		var tree := get_tree()
		if tree:
			await tree.process_frame
		_collect_shader_materials()
	
	_initialized = true

func _setup_camera_orientation() -> void:
	# Set camera rotation based on look axis
	match look_axis:
		CameraAxis.NEGATIVE_Z:
			rotation_degrees = Vector3(pitch_degrees, 0, 0)
		CameraAxis.POSITIVE_Z:
			rotation_degrees = Vector3(pitch_degrees, 180, 0)
		CameraAxis.NEGATIVE_X:
			rotation_degrees = Vector3(pitch_degrees, 90, 0)
		CameraAxis.POSITIVE_X:
			rotation_degrees = Vector3(pitch_degrees, -90, 0)

func _process(_delta: float) -> void:
	if not target:
		return
	
	_update_camera_position()
	_update_shader_parameters()

func _update_camera_position() -> void:
	var target_pos := target.global_position
	
	# Calculate camera position based on axis
	var offset := Vector3.ZERO
	match look_axis:
		CameraAxis.NEGATIVE_Z:
			offset = Vector3(0, 0, distance)  # Behind on +Z
		CameraAxis.POSITIVE_Z:
			offset = Vector3(0, 0, -distance)  # Behind on -Z
		CameraAxis.NEGATIVE_X:
			offset = Vector3(distance, 0, 0)  # Behind on +X
		CameraAxis.POSITIVE_X:
			offset = Vector3(-distance, 0, 0)  # Behind on -X
	
	# Set position
	global_position = Vector3(
		target_pos.x + offset.x,
		(target_pos.y if follow_target_y else fixed_y_position) + height_offset,
		target_pos.z + offset.z
	)

func _update_shader_parameters() -> void:
	if shader_materials.is_empty():
		return
	
	var center := target.global_position if target else global_position
	
	for mat in shader_materials:
		if is_instance_valid(mat):
			mat.set_shader_parameter("curve_center", center)

func _collect_shader_materials() -> void:
	if not is_inside_tree():
		return
	shader_materials.clear()
	var tree := get_tree()
	if not tree or not tree.root:
		return
	_find_curved_materials(tree.root)
	print("[XtremeCameraFixed] Found %d curved world materials" % shader_materials.size())

func _find_curved_materials(node: Node) -> void:
	if node is MeshInstance3D:
		_check_mesh_materials(node as MeshInstance3D)
	
	for child in node.get_children():
		_find_curved_materials(child)

func _check_mesh_materials(mesh: MeshInstance3D) -> void:
	# Check override material
	if _is_curved_shader(mesh.material_override):
		shader_materials.append(mesh.material_override as ShaderMaterial)
	
	# Check surface materials
	for i in range(mesh.get_surface_override_material_count()):
		var mat := mesh.get_surface_override_material(i)
		if _is_curved_shader(mat):
			shader_materials.append(mat as ShaderMaterial)

func _is_curved_shader(mat: Material) -> bool:
	if not mat is ShaderMaterial:
		return false
	var shader_mat := mat as ShaderMaterial
	return shader_mat.get_shader_parameter("curve_center") != null

## Refresh the cached shader materials (call after loading new level geometry)
func refresh_shaders() -> void:
	_collect_shader_materials()

## Change which axis the camera looks along
func set_look_axis(axis: CameraAxis) -> void:
	look_axis = axis
	_setup_camera_orientation()
