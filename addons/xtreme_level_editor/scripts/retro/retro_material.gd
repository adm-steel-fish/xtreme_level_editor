@tool
class_name RetroMaterial
extends RefCounted

## =============================================================================
## RETRO MATERIAL FACTORY
## =============================================================================
## Helper class for creating and configuring retro shader materials.
## Provides factory methods for common material types and easy configuration.
##
## Usage:
##   var mat = RetroMaterial.create_standard(Color.RED)
##   var ring_mat = RetroMaterial.create_ring()
##   var char_mat = RetroMaterial.create_character()
## =============================================================================

## Shader type enum
enum ShaderType {
	STANDARD,       ## General purpose with texture + vertex color support
	VERTEX_COLOR,   ## Optimized for vertex-colored models (characters)
	TEXTURED,       ## Optimized for textured environments
	UNLIT           ## Self-illuminated objects (collectibles)
}

## Shader paths
const SHADER_PATHS := {
	ShaderType.STANDARD: "res://addons/xtreme_level_editor/shaders/retro/retro_standard.gdshader",
	ShaderType.VERTEX_COLOR: "res://addons/xtreme_level_editor/shaders/retro/retro_vertex_color.gdshader",
	ShaderType.TEXTURED: "res://addons/xtreme_level_editor/shaders/retro/retro_textured.gdshader",
	ShaderType.UNLIT: "res://addons/xtreme_level_editor/shaders/retro/retro_unlit.gdshader"
}

## ===== FACTORY METHODS =====

## Create a standard retro material
static func create_standard(
	albedo_color: Color = Color.WHITE,
	retro_intensity: float = 0.35
) -> ShaderMaterial:
	var material := _create_base_material(ShaderType.STANDARD)
	if material:
		material.set_shader_parameter("albedo", albedo_color)
		material.set_shader_parameter("retro_intensity", retro_intensity)
		material.set_shader_parameter("use_texture", false)
		material.set_shader_parameter("use_vertex_color", false)
	return material


## Create a textured retro material
static func create_textured(
	texture: Texture2D,
	tint: Color = Color.WHITE,
	retro_intensity: float = 0.35
) -> ShaderMaterial:
	var material := _create_base_material(ShaderType.TEXTURED)
	if material:
		material.set_shader_parameter("albedo_texture", texture)
		material.set_shader_parameter("albedo_tint", tint)
		material.set_shader_parameter("retro_intensity", retro_intensity)
	return material


## Create a vertex color material (for characters like Sonic Mania style)
static func create_character(
	tint: Color = Color.WHITE,
	retro_intensity: float = 0.35,
	saturation_boost: float = 1.1
) -> ShaderMaterial:
	var material := _create_base_material(ShaderType.VERTEX_COLOR)
	if material:
		material.set_shader_parameter("color_tint", tint)
		material.set_shader_parameter("retro_intensity", retro_intensity)
		material.set_shader_parameter("saturation_boost", saturation_boost)
	return material


## Create an unlit material for collectibles
static func create_unlit(
	color: Color = Color.WHITE,
	brightness: float = 1.2,
	retro_intensity: float = 0.35
) -> ShaderMaterial:
	var material := _create_base_material(ShaderType.UNLIT)
	if material:
		material.set_shader_parameter("albedo", color)
		material.set_shader_parameter("brightness", brightness)
		material.set_shader_parameter("retro_intensity", retro_intensity)
	return material


## Create a gold ring material
static func create_ring(retro_intensity: float = 0.35) -> ShaderMaterial:
	var material := create_unlit(Color(1.0, 0.85, 0.0), 1.2, retro_intensity)
	if material:
		material.set_shader_parameter("pulse_enabled", true)
		material.set_shader_parameter("pulse_speed", 3.0)
		material.set_shader_parameter("pulse_intensity", 0.15)
		material.set_shader_parameter("pulse_color", Vector3(1.0, 1.0, 1.0))
		material.set_shader_parameter("rim_enabled", true)
		material.set_shader_parameter("rim_intensity", 0.3)
	return material


## Create a blue sphere material
static func create_blue_sphere(retro_intensity: float = 0.35) -> ShaderMaterial:
	var material := create_unlit(Color(0.2, 0.5, 1.0), 1.1, retro_intensity)
	if material:
		material.set_shader_parameter("pulse_enabled", false)
		material.set_shader_parameter("rim_enabled", true)
		material.set_shader_parameter("rim_intensity", 0.4)
		material.set_shader_parameter("rim_power", 2.5)
	return material


## Create a red sphere material
static func create_red_sphere(retro_intensity: float = 0.35) -> ShaderMaterial:
	var material := create_unlit(Color(1.0, 0.2, 0.2), 1.1, retro_intensity)
	if material:
		material.set_shader_parameter("pulse_enabled", false)
		material.set_shader_parameter("rim_enabled", true)
		material.set_shader_parameter("rim_intensity", 0.4)
		material.set_shader_parameter("rim_power", 2.5)
	return material


## Create a spring material (yellow/red)
static func create_spring(
	top_color: Color = Color(1.0, 0.9, 0.0),
	retro_intensity: float = 0.35
) -> ShaderMaterial:
	var material := create_unlit(top_color, 1.0, retro_intensity)
	if material:
		material.set_shader_parameter("rim_enabled", false)
		material.set_shader_parameter("pulse_enabled", false)
	return material


## ===== CONFIGURATION METHODS =====

## Apply damage flash to a material
static func set_damage_flash(
	material: ShaderMaterial,
	intensity: float,
	flash_color: Color = Color.WHITE
) -> void:
	if not material:
		return
	
	# Check if shader supports damage flash
	if material.shader and _has_uniform(material, "damage_flash_enabled"):
		material.set_shader_parameter("damage_flash_enabled", intensity > 0.0)
		material.set_shader_parameter("damage_flash_intensity", intensity)
		material.set_shader_parameter("damage_flash_color", Vector3(flash_color.r, flash_color.g, flash_color.b))
	elif material.shader and _has_uniform(material, "flash_enabled"):
		material.set_shader_parameter("flash_enabled", intensity > 0.0)
		material.set_shader_parameter("flash_intensity", intensity)
		material.set_shader_parameter("flash_color", Vector3(flash_color.r, flash_color.g, flash_color.b))


## Set fade alpha (for collection animation)
static func set_fade(material: ShaderMaterial, alpha: float) -> void:
	if material and _has_uniform(material, "fade_alpha"):
		material.set_shader_parameter("fade_alpha", alpha)


## Enable/disable retro effects on a material
static func set_retro_enabled(material: ShaderMaterial, enabled: bool) -> void:
	if material and _has_uniform(material, "retro_enabled"):
		material.set_shader_parameter("retro_enabled", enabled)


## Set retro intensity on a material
static func set_retro_intensity(material: ShaderMaterial, intensity: float) -> void:
	if material and _has_uniform(material, "retro_intensity"):
		material.set_shader_parameter("retro_intensity", clampf(intensity, 0.0, 1.0))


## Configure lighting on a material
static func configure_lighting(
	material: ShaderMaterial,
	light_dir: Vector3,
	light_color: Color,
	light_intensity: float,
	ambient_color: Color,
	ambient_intensity: float
) -> void:
	if not material:
		return
	
	if _has_uniform(material, "light_direction"):
		material.set_shader_parameter("light_direction", light_dir.normalized())
		material.set_shader_parameter("light_color", Vector3(light_color.r, light_color.g, light_color.b))
		material.set_shader_parameter("light_intensity", light_intensity)
		material.set_shader_parameter("ambient_color", Vector3(ambient_color.r, ambient_color.g, ambient_color.b))
		material.set_shader_parameter("ambient_intensity", ambient_intensity)


## ===== INTERNAL HELPERS =====

static func _create_base_material(shader_type: ShaderType) -> ShaderMaterial:
	var shader_path: String = SHADER_PATHS[shader_type]
	var shader := load(shader_path) as Shader
	
	if not shader:
		push_error("RetroMaterial: Failed to load shader: " + shader_path)
		return null
	
	var material := ShaderMaterial.new()
	material.shader = shader
	
	# Set common defaults
	material.set_shader_parameter("retro_enabled", true)
	material.set_shader_parameter("retro_intensity", 0.35)
	
	return material


static func _has_uniform(material: ShaderMaterial, uniform_name: String) -> bool:
	if not material or not material.shader:
		return false
	
	for uniform in material.shader.get_shader_uniform_list():
		if uniform["name"] == uniform_name:
			return true
	return false


## ===== UTILITY =====

## Get shader type from a material
static func get_shader_type(material: ShaderMaterial) -> ShaderType:
	if not material or not material.shader:
		return ShaderType.STANDARD
	
	var path := material.shader.resource_path
	for type in SHADER_PATHS:
		if SHADER_PATHS[type] == path:
			return type
	
	return ShaderType.STANDARD


## Check if a material uses a retro shader
static func is_retro_material(material: Material) -> bool:
	if not material is ShaderMaterial:
		return false
	
	var shader_mat := material as ShaderMaterial
	if not shader_mat.shader:
		return false
	
	return shader_mat.shader.resource_path in SHADER_PATHS.values()
