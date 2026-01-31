extends Area3D
class_name XtremeTestEnemy

## Simple test enemy that can be targeted and destroyed by homing attack
## Supports both retro ShaderMaterial and standard StandardMaterial3D

@export var health: int = 1
@export var bounce_velocity: float = 15.0
@export var use_retro_shader: bool = true  ## Use PS1/Saturn style retro shader

var _is_destroyed: bool = false
var _material: Material
var _is_shader_material: bool = false
var _original_color: Color = Color(0.9, 0.2, 0.2, 1.0)


func _ready() -> void:
	# Add to targetable group so player can lock on
	add_to_group("enemies")
	add_to_group("targetable")
	
	# Connect body entered signal
	body_entered.connect(_on_body_entered)
	
	# Setup material
	_setup_material()


func _setup_material() -> void:
	var mesh = get_node_or_null("MeshInstance3D")
	if not mesh or not mesh is MeshInstance3D:
		return
	
	var original_mat = mesh.get_surface_override_material(0)
	if not original_mat:
		original_mat = mesh.mesh.surface_get_material(0) if mesh.mesh else null
	
	# Check if already using a shader material
	if original_mat and original_mat is ShaderMaterial:
		_material = original_mat.duplicate()
		_is_shader_material = true
		mesh.set_surface_override_material(0, _material)
	elif use_retro_shader:
		# Try to create a retro shader material
		_material = _create_retro_enemy_material()
		if _material:
			_is_shader_material = true
			mesh.set_surface_override_material(0, _material)
		else:
			_setup_standard_material(mesh, original_mat)
	else:
		_setup_standard_material(mesh, original_mat)


func _create_retro_enemy_material() -> ShaderMaterial:
	# Try to load the retro vertex color shader (good for enemies)
	var shader = load("res://addons/xtreme_level_editor/shaders/retro/retro_vertex_color.gdshader")
	if not shader:
		return null
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	
	# Configure as red enemy
	mat.set_shader_parameter("retro_enabled", true)
	mat.set_shader_parameter("retro_intensity", 0.35)
	mat.set_shader_parameter("color_tint", Color(0.9, 0.2, 0.2, 1.0))
	mat.set_shader_parameter("saturation_boost", 1.2)
	mat.set_shader_parameter("damage_flash_enabled", false)
	mat.set_shader_parameter("damage_flash_color", Vector3(1.0, 1.0, 1.0))
	mat.set_shader_parameter("damage_flash_intensity", 0.0)
	
	return mat


func _setup_standard_material(mesh: MeshInstance3D, original_mat: Material) -> void:
	if original_mat and original_mat is StandardMaterial3D:
		_material = original_mat.duplicate()
		_original_color = (_material as StandardMaterial3D).albedo_color
	else:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = _original_color
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.1, 0.1, 1.0)
		mat.emission_energy_multiplier = 0.3
		_material = mat
	
	_is_shader_material = false
	mesh.set_surface_override_material(0, _material)


func _on_body_entered(body: Node3D) -> void:
	if _is_destroyed:
		return
	
	# Check if it's the player
	if body is PlayerController:
		var player = body as PlayerController
		
		# Check if player is in homing attack or butt bounce
		if player.current_state == PlayerController.State.HOMING_ATTACK or \
		   player.current_state == PlayerController.State.BUTT_BOUNCE_DESCENDING:
			take_damage(1)


func take_damage(amount: int) -> void:
	health -= amount
	
	if health <= 0:
		destroy()
	else:
		# Flash white
		_flash()


func _flash() -> void:
	if not _material:
		return
	
	if _is_shader_material:
		# Use retro shader's damage flash
		var shader_mat = _material as ShaderMaterial
		shader_mat.set_shader_parameter("damage_flash_enabled", true)
		shader_mat.set_shader_parameter("damage_flash_intensity", 0.8)
		
		# Tween flash back to normal
		var tween = create_tween()
		tween.tween_method(
			func(val: float): shader_mat.set_shader_parameter("damage_flash_intensity", val),
			0.8, 0.0, 0.15
		)
		tween.tween_callback(func(): shader_mat.set_shader_parameter("damage_flash_enabled", false))
	else:
		# Standard material flash
		var std_mat = _material as StandardMaterial3D
		var original = std_mat.albedo_color
		std_mat.albedo_color = Color.WHITE
		
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and std_mat:
			std_mat.albedo_color = original


func destroy() -> void:
	_is_destroyed = true
	
	# Simple destroy effect - scale down and remove
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(queue_free)
