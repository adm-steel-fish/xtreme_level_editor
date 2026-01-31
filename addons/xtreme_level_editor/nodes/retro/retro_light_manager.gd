@tool
class_name RetroLightManager
extends Node3D

## =============================================================================
## RETRO LIGHT MANAGER
## =============================================================================
## Manages PS1/Saturn-style vertex lighting for the scene.
## 
## Unlike modern lighting which calculates per-pixel, retro lighting:
## - Uses a single global directional light
## - Calculates lighting per-vertex (Gouraud shading)
## - Has no real shadows (or simple blob shadows only)
## - Emissive objects glow without affecting other objects
##
## This node updates all retro shader materials with consistent lighting values.
## =============================================================================

signal lighting_changed()

## ===== MAIN LIGHT =====
@export_group("Main Light")
@export var light_enabled: bool = true:
	set(value):
		light_enabled = value
		_apply_lighting()
		lighting_changed.emit()

@export var light_direction: Vector3 = Vector3(0.3, -0.7, -0.5):
	set(value):
		light_direction = value.normalized()
		_apply_lighting()
		lighting_changed.emit()

@export var light_color: Color = Color(1.0, 0.98, 0.95):
	set(value):
		light_color = value
		_apply_lighting()
		lighting_changed.emit()

@export_range(0.0, 2.0, 0.05) var light_intensity: float = 1.0:
	set(value):
		light_intensity = value
		_apply_lighting()
		lighting_changed.emit()

## ===== AMBIENT =====
@export_group("Ambient Light")
@export var ambient_color: Color = Color(0.3, 0.3, 0.35):
	set(value):
		ambient_color = value
		_apply_lighting()
		lighting_changed.emit()

@export_range(0.0, 1.0, 0.05) var ambient_intensity: float = 0.4:
	set(value):
		ambient_intensity = value
		_apply_lighting()
		lighting_changed.emit()

## ===== SHADING OPTIONS =====
@export_group("Shading")
@export var use_half_lambert: bool = true:
	set(value):
		use_half_lambert = value
		_apply_lighting()
		lighting_changed.emit()

## ===== FOG =====
@export_group("Distance Fog")
@export var fog_enabled: bool = true:
	set(value):
		fog_enabled = value
		_apply_fog()
		lighting_changed.emit()

@export var fog_color: Color = Color(0.1, 0.1, 0.15):
	set(value):
		fog_color = value
		_apply_fog()
		lighting_changed.emit()

@export_range(10.0, 500.0, 5.0) var fog_start: float = 50.0:
	set(value):
		fog_start = value
		_apply_fog()
		lighting_changed.emit()

@export_range(20.0, 1000.0, 10.0) var fog_end: float = 150.0:
	set(value):
		fog_end = value
		_apply_fog()
		lighting_changed.emit()

## ===== HEIGHT FOG =====
@export_group("Height Fog")
@export var height_fog_enabled: bool = false:
	set(value):
		height_fog_enabled = value
		_apply_fog()
		lighting_changed.emit()

@export var height_fog_bottom: float = -10.0:
	set(value):
		height_fog_bottom = value
		_apply_fog()
		lighting_changed.emit()

@export var height_fog_top: float = 30.0:
	set(value):
		height_fog_top = value
		_apply_fog()
		lighting_changed.emit()

@export_range(0.0, 1.0, 0.05) var height_fog_density: float = 0.5:
	set(value):
		height_fog_density = value
		_apply_fog()
		lighting_changed.emit()

## ===== AUTO-UPDATE =====
@export_group("Settings")
@export var auto_update_materials: bool = true
@export var update_in_editor: bool = true
@export var update_environment: bool = true

# Internal
var _materials: Array[ShaderMaterial] = []
var _environment: Environment


func _ready() -> void:
	if auto_update_materials:
		call_deferred("_scan_materials")
	
	if update_environment:
		call_deferred("_find_environment")
	
	_apply_all()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and not update_in_editor:
		return
	
	# Could add dynamic light direction from a DirectionalLight3D here if desired


## ===== MATERIAL SCANNING =====

func _scan_materials() -> void:
	_materials.clear()
	_scan_node(get_tree().root)
	_apply_all()


func _scan_node(node: Node) -> void:
	# Check MeshInstance3D
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		
		# Check material override
		var mat := mesh_inst.material_override
		if mat and mat is ShaderMaterial:
			_register_material(mat as ShaderMaterial)
		
		# Check surface materials
		if mesh_inst.mesh:
			for i in mesh_inst.mesh.get_surface_count():
				var surface_mat := mesh_inst.get_surface_override_material(i)
				if surface_mat and surface_mat is ShaderMaterial:
					_register_material(surface_mat as ShaderMaterial)
				elif not surface_mat:
					surface_mat = mesh_inst.mesh.surface_get_material(i)
					if surface_mat and surface_mat is ShaderMaterial:
						_register_material(surface_mat as ShaderMaterial)
	
	# Recurse children
	for child in node.get_children():
		_scan_node(child)


func _register_material(mat: ShaderMaterial) -> void:
	if mat in _materials:
		return
	
	# Check if it's a retro shader by looking for our uniforms
	if _has_lighting_uniforms(mat):
		_materials.append(mat)


func _has_lighting_uniforms(mat: ShaderMaterial) -> bool:
	if not mat.shader:
		return false
	
	# Check for our retro shader lighting uniforms
	for uniform in mat.shader.get_shader_uniform_list():
		if uniform["name"] == "lighting_enabled" or uniform["name"] == "light_direction":
			return true
	
	return false


func _find_environment() -> void:
	# Find WorldEnvironment in scene
	var world_env := _find_node_by_type(get_tree().root, "WorldEnvironment") as WorldEnvironment
	if world_env:
		_environment = world_env.environment


func _find_node_by_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name:
		return node
	
	for child in node.get_children():
		var found := _find_node_by_type(child, type_name)
		if found:
			return found
	
	return null


## ===== APPLY SETTINGS =====

func _apply_all() -> void:
	_apply_lighting()
	_apply_fog()
	_apply_to_environment()


func _apply_lighting() -> void:
	for mat in _materials:
		if not is_instance_valid(mat):
			continue
		
		_set_uniform_safe(mat, "lighting_enabled", light_enabled)
		_set_uniform_safe(mat, "light_direction", light_direction)
		_set_uniform_safe(mat, "light_color", Vector3(light_color.r, light_color.g, light_color.b))
		_set_uniform_safe(mat, "light_intensity", light_intensity)
		_set_uniform_safe(mat, "ambient_color", Vector3(ambient_color.r, ambient_color.g, ambient_color.b))
		_set_uniform_safe(mat, "ambient_intensity", ambient_intensity)
		_set_uniform_safe(mat, "use_half_lambert", use_half_lambert)


func _apply_fog() -> void:
	for mat in _materials:
		if not is_instance_valid(mat):
			continue
		
		_set_uniform_safe(mat, "fog_enabled", fog_enabled)
		_set_uniform_safe(mat, "fog_color", Vector3(fog_color.r, fog_color.g, fog_color.b))
		_set_uniform_safe(mat, "fog_start", fog_start)
		_set_uniform_safe(mat, "fog_end", fog_end)
		_set_uniform_safe(mat, "height_fog_enabled", height_fog_enabled)
		_set_uniform_safe(mat, "height_fog_bottom", height_fog_bottom)
		_set_uniform_safe(mat, "height_fog_top", height_fog_top)
		_set_uniform_safe(mat, "height_fog_density", height_fog_density)


func _apply_to_environment() -> void:
	if not update_environment or not _environment:
		return
	
	# Sync Godot's built-in fog with our settings
	_environment.fog_enabled = fog_enabled
	if fog_enabled:
		_environment.fog_light_color = fog_color
		# Approximate density from start/end
		var range_val := fog_end - fog_start
		if range_val > 0:
			_environment.fog_density = 0.02 / (range_val / 100.0)


func _set_uniform_safe(mat: ShaderMaterial, uniform_name: String, value: Variant) -> void:
	if not mat or not mat.shader:
		return
	
	# Check if uniform exists
	for uniform in mat.shader.get_shader_uniform_list():
		if uniform["name"] == uniform_name:
			mat.set_shader_parameter(uniform_name, value)
			return


## ===== PUBLIC API =====

## Manually register a material for lighting updates
func register_material(mat: ShaderMaterial) -> void:
	if mat and mat not in _materials:
		_materials.append(mat)
		_apply_lighting()
		_apply_fog()


## Unregister a material
func unregister_material(mat: ShaderMaterial) -> void:
	_materials.erase(mat)


## Force refresh all materials in scene
func refresh_materials() -> void:
	_scan_materials()


## Apply settings from a ZoneVisualSettings resource
func apply_zone_settings(settings: Resource) -> void:
	if not settings:
		return
	
	# Extract lighting settings
	if "light_direction" in settings:
		light_direction = settings.light_direction
	if "light_color" in settings:
		light_color = settings.light_color
	if "light_intensity" in settings:
		light_intensity = settings.light_intensity
	if "ambient_color" in settings:
		ambient_color = settings.ambient_color
	if "ambient_intensity" in settings:
		ambient_intensity = settings.ambient_intensity
	
	# Extract fog settings
	if "fog_enabled" in settings:
		fog_enabled = settings.fog_enabled
	if "fog_color" in settings:
		fog_color = settings.fog_color
	if "fog_start_distance" in settings:
		fog_start = settings.fog_start_distance
	if "fog_end_distance" in settings:
		fog_end = settings.fog_end_distance


## ===== PRESETS =====

## Apply sunny outdoor lighting
func apply_sunny_preset() -> void:
	light_direction = Vector3(0.3, -0.8, -0.4)
	light_color = Color(1.0, 0.98, 0.9)
	light_intensity = 1.2
	ambient_color = Color(0.4, 0.45, 0.5)
	ambient_intensity = 0.5
	fog_color = Color(0.6, 0.7, 0.85)


## Apply night lighting
func apply_night_preset() -> void:
	light_direction = Vector3(0.5, -0.3, -0.5)
	light_color = Color(0.7, 0.75, 0.9)
	light_intensity = 0.6
	ambient_color = Color(0.15, 0.15, 0.25)
	ambient_intensity = 0.6
	fog_color = Color(0.05, 0.05, 0.1)


## Apply indoor/cave lighting
func apply_indoor_preset() -> void:
	light_direction = Vector3(0.0, -1.0, 0.0)
	light_color = Color(0.9, 0.85, 0.7)
	light_intensity = 0.8
	ambient_color = Color(0.25, 0.2, 0.15)
	ambient_intensity = 0.7
	fog_color = Color(0.1, 0.08, 0.05)


## Apply dramatic sunset lighting
func apply_sunset_preset() -> void:
	light_direction = Vector3(0.8, -0.3, -0.4)
	light_color = Color(1.0, 0.6, 0.3)
	light_intensity = 1.1
	ambient_color = Color(0.3, 0.2, 0.3)
	ambient_intensity = 0.5
	fog_color = Color(0.5, 0.3, 0.2)
