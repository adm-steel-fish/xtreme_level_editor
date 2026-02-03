extends Area3D
class_name XtremeTestCurrency

## Simple test currency (ring) for light dash testing
## Each ring is collected individually
## Supports both retro ShaderMaterial and standard StandardMaterial3D

@export var value: int = 1
@export var rotation_speed: float = 180.0
@export var use_retro_shader: bool = true  ## Use PS1/Saturn style retro shader

var _collected: bool = false
var _unique_material: Material  # Each instance gets its own material (can be ShaderMaterial or StandardMaterial3D)
var _is_shader_material: bool = false

signal collected(currency: XtremeTestCurrency)


func _ready() -> void:
	# Add to currency group so player can light dash
	add_to_group("currency")
	
	# Connect body entered signal
	body_entered.connect(_on_body_entered)
	
	# IMPORTANT: Create a unique material for this ring instance
	# This prevents all rings from fading when one is collected
	_create_unique_material()
	_orient_ring()


func _create_unique_material() -> void:
	var mesh = get_node_or_null("MeshInstance3D")
	if not mesh or not mesh is MeshInstance3D:
		return
	
	var original_mat = mesh.get_surface_override_material(0)
	if not original_mat:
		original_mat = mesh.mesh.surface_get_material(0) if mesh.mesh else null
	
	# Check if it's already a retro shader material
	if original_mat and original_mat is ShaderMaterial:
		_unique_material = original_mat.duplicate()
		_is_shader_material = true
		mesh.set_surface_override_material(0, _unique_material)
	elif use_retro_shader:
		# Try to create a retro shader material
		_unique_material = _create_retro_ring_material()
		if _unique_material:
			_is_shader_material = true
			mesh.set_surface_override_material(0, _unique_material)
		else:
			# Fallback to standard material
			_create_standard_material(mesh, original_mat)
	else:
		_create_standard_material(mesh, original_mat)


func _create_retro_ring_material() -> ShaderMaterial:
	# Try to load the retro unlit shader
	var shader = load("res://addons/xtreme_level_editor/shaders/retro/retro_unlit.gdshader")
	if not shader:
		return null
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	
	# Configure as gold ring
	mat.set_shader_parameter("retro_enabled", true)
	mat.set_shader_parameter("retro_intensity", 0.35)
	mat.set_shader_parameter("albedo", Color(1.0, 0.85, 0.0, 1.0))
	mat.set_shader_parameter("use_texture", false)
	mat.set_shader_parameter("use_vertex_color", false)
	mat.set_shader_parameter("brightness", 1.2)
	mat.set_shader_parameter("pulse_enabled", true)
	mat.set_shader_parameter("pulse_speed", 3.0)
	mat.set_shader_parameter("pulse_intensity", 0.15)
	mat.set_shader_parameter("pulse_color", Vector3(1.0, 1.0, 1.0))
	mat.set_shader_parameter("rim_enabled", true)
	mat.set_shader_parameter("rim_color", Vector3(1.0, 1.0, 1.0))
	mat.set_shader_parameter("rim_intensity", 0.3)
	mat.set_shader_parameter("rim_power", 2.0)
	mat.set_shader_parameter("fade_alpha", 1.0)
	
	return mat


func _create_standard_material(mesh: MeshInstance3D, original_mat: Material) -> void:
	if original_mat and original_mat is StandardMaterial3D:
		# Duplicate the material so each ring has its own
		_unique_material = original_mat.duplicate()
	else:
		# Create a default gold material if none exists
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.1, 1.0)
		mat.metallic = 0.8
		mat.roughness = 0.2
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.1, 1.0)
		mat.emission_energy_multiplier = 0.2
		_unique_material = mat
	_is_shader_material = false
	mesh.set_surface_override_material(0, _unique_material)


func _orient_ring() -> void:
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh.rotation_degrees.x = 90.0
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision:
		collision.rotation_degrees.x = 90.0


func _process(delta: float) -> void:
	if _collected:
		return
	# Spin the ring
	rotate_y(deg_to_rad(rotation_speed * delta))


func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	
	# Check if it's the player
	if body is PlayerController:
		collect()


## Called by player controller during light dash or by collision
func collect() -> void:
	if _collected:
		return
	
	_collected = true
	collected.emit(self)
	
	# Disable collision immediately to prevent double-collection
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Simple collect effect - scale up and fade using our unique material
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 1.5, 0.15)
	
	# Fade out using our unique material
	if _unique_material:
		if _is_shader_material:
			# Use retro shader's fade_alpha parameter
			tween.tween_property(_unique_material, "shader_parameter/fade_alpha", 0.0, 0.15)
		else:
			# Standard material fade
			var std_mat = _unique_material as StandardMaterial3D
			std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tween.tween_property(std_mat, "albedo_color:a", 0.0, 0.15)
	
	tween.chain().tween_callback(queue_free)
