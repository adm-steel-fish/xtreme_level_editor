@tool
class_name RetroShaderParams
extends Node

## =============================================================================
## RETRO SHADER PARAMETERS - Global Controller
## =============================================================================
## Singleton for controlling retro visual effects across all materials.
## Add to Project Settings > AutoLoad for global access.
##
## Usage:
##   RetroShaderParams.set_retro_intensity(0.5)
##   RetroShaderParams.set_lighting_direction(Vector3(0.3, -0.7, -0.5))
##
## The system tracks all materials using retro shaders and updates them
## when global parameters change.
## =============================================================================

## Emitted when any retro parameter changes
signal retro_params_changed()
signal intensity_changed(new_intensity: float)

## ===== RETRO INTENSITY PRESETS =====
enum RetroPreset {
	MODERN,      ## 0% - No retro effects
	MINIMAL,     ## 25% - Subtle hint of retro
	LIGHT,       ## 35% - Default, noticeable but clean
	BALANCED,    ## 50% - Clear retro aesthetic
	HEAVY,       ## 75% - Strong retro feel
	AUTHENTIC    ## 100% - Hardware-accurate PS1/Saturn
}

const PRESET_VALUES := {
	RetroPreset.MODERN: 0.0,
	RetroPreset.MINIMAL: 0.25,
	RetroPreset.LIGHT: 0.35,
	RetroPreset.BALANCED: 0.5,
	RetroPreset.HEAVY: 0.75,
	RetroPreset.AUTHENTIC: 1.0
}

## ===== GLOBAL SETTINGS =====
@export_group("Global Retro Settings")
@export var retro_enabled: bool = true:
	set(value):
		retro_enabled = value
		_update_all_materials()
		retro_params_changed.emit()

@export_range(0.0, 1.0, 0.05) var retro_intensity: float = 0.35:
	set(value):
		retro_intensity = clampf(value, 0.0, 1.0)
		_update_all_materials()
		intensity_changed.emit(retro_intensity)
		retro_params_changed.emit()

@export var current_preset: RetroPreset = RetroPreset.LIGHT:
	set(value):
		current_preset = value
		retro_intensity = PRESET_VALUES[value]

## ===== INDIVIDUAL EFFECT OVERRIDES =====
## Set to -1.0 to use automatic values derived from retro_intensity
@export_group("Effect Overrides")
@export_range(-1.0, 1.0, 0.05) var vertex_jitter_override: float = -1.0:
	set(value):
		vertex_jitter_override = value
		_update_all_materials()

@export_range(-1.0, 1.0, 0.05) var affine_warp_override: float = -1.0:
	set(value):
		affine_warp_override = value
		_update_all_materials()

@export_range(-1.0, 1.0, 0.05) var color_reduction_override: float = -1.0:
	set(value):
		color_reduction_override = value
		_update_all_materials()

@export_range(-1.0, 1.0, 0.05) var dither_override: float = -1.0:
	set(value):
		dither_override = value
		_update_all_materials()

@export_range(32.0, 512.0, 8.0) var jitter_resolution: float = 128.0:
	set(value):
		jitter_resolution = value
		_update_all_materials()

## ===== GLOBAL LIGHTING (Sonic Mania Style) =====
@export_group("Global Lighting")
@export var lighting_enabled: bool = true:
	set(value):
		lighting_enabled = value
		_update_all_materials()

@export var light_direction: Vector3 = Vector3(0.3, -0.7, -0.5):
	set(value):
		light_direction = value.normalized()
		_update_all_materials()

@export var light_color: Color = Color(1.0, 0.98, 0.95):
	set(value):
		light_color = value
		_update_all_materials()

@export_range(0.0, 2.0, 0.05) var light_intensity: float = 1.0:
	set(value):
		light_intensity = value
		_update_all_materials()

@export var ambient_color: Color = Color(0.3, 0.3, 0.35):
	set(value):
		ambient_color = value
		_update_all_materials()

@export_range(0.0, 1.0, 0.05) var ambient_intensity: float = 0.4:
	set(value):
		ambient_intensity = value
		_update_all_materials()

@export var use_half_lambert: bool = true:
	set(value):
		use_half_lambert = value
		_update_all_materials()

## ===== INTERNAL =====
## Tracked materials for bulk updates
var _tracked_materials: Array[ShaderMaterial] = []
var _update_queued: bool = false

## Shader paths for identification
const RETRO_SHADER_PATHS := [
	"res://addons/xtreme_level_editor/shaders/retro/retro_standard.gdshader",
	"res://addons/xtreme_level_editor/shaders/retro/retro_vertex_color.gdshader",
	"res://addons/xtreme_level_editor/shaders/retro/retro_textured.gdshader",
	"res://addons/xtreme_level_editor/shaders/retro/retro_unlit.gdshader"
]


func _ready() -> void:
	# Defer initial update to ensure scene is ready
	call_deferred("_initial_scan")


func _initial_scan() -> void:
	# Scan scene tree for existing retro materials
	if get_tree():
		_scan_node_for_materials(get_tree().root)


## ===== PUBLIC API =====

## Set retro intensity using a preset
func set_preset(preset: RetroPreset) -> void:
	current_preset = preset


## Get the current effective jitter intensity
func get_effective_jitter() -> float:
	if vertex_jitter_override >= 0.0:
		return vertex_jitter_override
	return _get_jitter_from_intensity(retro_intensity)


## Get the current effective affine warp intensity
func get_effective_affine() -> float:
	if affine_warp_override >= 0.0:
		return affine_warp_override
	return _get_affine_from_intensity(retro_intensity)


## Get the current effective color reduction
func get_effective_color_reduction() -> float:
	if color_reduction_override >= 0.0:
		return color_reduction_override
	return retro_intensity


## Get the current effective dither intensity
func get_effective_dither() -> float:
	if dither_override >= 0.0:
		return dither_override
	return retro_intensity


## Register a material for automatic updates
func register_material(material: ShaderMaterial) -> void:
	if material and not _tracked_materials.has(material):
		_tracked_materials.append(material)
		_apply_params_to_material(material)


## Unregister a material
func unregister_material(material: ShaderMaterial) -> void:
	_tracked_materials.erase(material)


## Force update all tracked materials
func refresh_all_materials() -> void:
	_update_all_materials()


## Create a new retro material with current settings
func create_retro_material(shader_type: String = "standard") -> ShaderMaterial:
	var shader_path: String
	match shader_type.to_lower():
		"vertex_color", "vertexcolor", "character":
			shader_path = RETRO_SHADER_PATHS[1]
		"textured", "environment":
			shader_path = RETRO_SHADER_PATHS[2]
		"unlit", "emissive", "collectible":
			shader_path = RETRO_SHADER_PATHS[3]
		_:
			shader_path = RETRO_SHADER_PATHS[0]
	
	var shader := load(shader_path) as Shader
	if not shader:
		push_error("RetroShaderParams: Failed to load shader: " + shader_path)
		return null
	
	var material := ShaderMaterial.new()
	material.shader = shader
	register_material(material)
	return material


## ===== INTERNAL METHODS =====

func _scan_node_for_materials(node: Node) -> void:
	# Check if node has a mesh with materials
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for i in range(mesh_instance.get_surface_override_material_count()):
			var mat := mesh_instance.get_surface_override_material(i)
			if mat is ShaderMaterial:
				_check_and_register_material(mat as ShaderMaterial)
		
		# Also check mesh materials
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				var mat := mesh_instance.mesh.surface_get_material(i)
				if mat is ShaderMaterial:
					_check_and_register_material(mat as ShaderMaterial)
	
	# Recurse children
	for child in node.get_children():
		_scan_node_for_materials(child)


func _check_and_register_material(material: ShaderMaterial) -> void:
	if material.shader:
		var shader_path := material.shader.resource_path
		if shader_path in RETRO_SHADER_PATHS:
			register_material(material)


func _update_all_materials() -> void:
	# Queue update to batch multiple parameter changes
	if not _update_queued:
		_update_queued = true
		call_deferred("_perform_material_update")


func _perform_material_update() -> void:
	_update_queued = false
	
	# Clean up any freed materials
	_tracked_materials = _tracked_materials.filter(func(m): return is_instance_valid(m))
	
	# Update all tracked materials
	for material in _tracked_materials:
		_apply_params_to_material(material)


func _apply_params_to_material(material: ShaderMaterial) -> void:
	if not material or not material.shader:
		return
	
	# Core retro parameters
	_set_shader_param_safe(material, "retro_enabled", retro_enabled)
	_set_shader_param_safe(material, "retro_intensity", retro_intensity)
	_set_shader_param_safe(material, "vertex_jitter_override", vertex_jitter_override)
	_set_shader_param_safe(material, "affine_warp_override", affine_warp_override)
	_set_shader_param_safe(material, "color_reduction_override", color_reduction_override)
	_set_shader_param_safe(material, "dither_override", dither_override)
	_set_shader_param_safe(material, "jitter_resolution", jitter_resolution)
	
	# Lighting parameters (not all shaders have these)
	_set_shader_param_safe(material, "lighting_enabled", lighting_enabled)
	_set_shader_param_safe(material, "light_direction", light_direction)
	_set_shader_param_safe(material, "light_color", light_color)
	_set_shader_param_safe(material, "light_intensity", light_intensity)
	_set_shader_param_safe(material, "ambient_color", ambient_color)
	_set_shader_param_safe(material, "ambient_intensity", ambient_intensity)
	_set_shader_param_safe(material, "use_half_lambert", use_half_lambert)


func _set_shader_param_safe(material: ShaderMaterial, param_name: String, value: Variant) -> void:
	# Only set if the shader has this uniform
	if material.shader.get_shader_uniform_list().any(func(u): return u["name"] == param_name):
		material.set_shader_parameter(param_name, value)


## Intensity mapping functions (matching shader include)
func _get_jitter_from_intensity(intensity: float) -> float:
	return intensity * intensity * 0.85


func _get_affine_from_intensity(intensity: float) -> float:
	return intensity * 0.9


func _get_color_bits_from_intensity(intensity: float) -> float:
	return lerpf(8.0, 5.0, intensity)


## ===== EDITOR HELPER =====
## Print current settings for debugging
func print_current_settings() -> void:
	print("=== RetroShaderParams Settings ===")
	print("Enabled: ", retro_enabled)
	print("Intensity: ", retro_intensity, " (", RetroPreset.keys()[current_preset], ")")
	print("Effective Jitter: ", get_effective_jitter())
	print("Effective Affine: ", get_effective_affine())
	print("Effective Color Reduction: ", get_effective_color_reduction())
	print("Effective Dither: ", get_effective_dither())
	print("Jitter Resolution: ", jitter_resolution)
	print("Light Direction: ", light_direction)
	print("Light Color: ", light_color)
	print("Tracked Materials: ", _tracked_materials.size())
	print("==================================")
