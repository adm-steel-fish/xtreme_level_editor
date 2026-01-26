@tool
class_name RetroSettings
extends Resource

## =============================================================================
## RETRO SETTINGS RESOURCE
## =============================================================================
## Saveable configuration for retro visual effects.
## Can be used for:
##   - Global game settings
##   - Per-zone visual configurations
##   - Player preferences
##   - Preset libraries
## =============================================================================

## ===== METADATA =====
@export_group("Metadata")
@export var setting_name: String = "Default"
@export_multiline var description: String = ""

## ===== CORE RETRO SETTINGS =====
@export_group("Retro Effects")
@export var retro_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var retro_intensity: float = 0.35

## Individual effect overrides (-1.0 = use automatic)
@export_subgroup("Effect Overrides")
@export_range(-1.0, 1.0, 0.05) var vertex_jitter_override: float = -1.0
@export_range(-1.0, 1.0, 0.05) var affine_warp_override: float = -1.0
@export_range(-1.0, 1.0, 0.05) var color_reduction_override: float = -1.0
@export_range(-1.0, 1.0, 0.05) var dither_override: float = -1.0
@export_range(32.0, 512.0, 8.0) var jitter_resolution: float = 128.0

## ===== LIGHTING SETTINGS =====
@export_group("Lighting")
@export var lighting_enabled: bool = true
@export var light_direction: Vector3 = Vector3(0.3, -0.7, -0.5)
@export var light_color: Color = Color(1.0, 0.98, 0.95)
@export_range(0.0, 2.0, 0.05) var light_intensity: float = 1.0
@export var ambient_color: Color = Color(0.3, 0.3, 0.35)
@export_range(0.0, 1.0, 0.05) var ambient_intensity: float = 0.4
@export var use_half_lambert: bool = true

## ===== POST-PROCESSING (Phase 1.2) =====
@export_group("Post-Processing")
@export var post_process_enabled: bool = true
@export_range(0.25, 1.0, 0.05) var render_scale: float = 0.75  ## Resolution downscaling
@export_range(16, 256, 8) var color_band_levels: int = 64     ## Posterization levels


## ===== METHODS =====

## Apply these settings to the global RetroShaderParams singleton
func apply_to_global() -> void:
	var params := _get_retro_params()
	if not params:
		push_warning("RetroSettings: RetroShaderParams singleton not found")
		return
	
	params.retro_enabled = retro_enabled
	params.retro_intensity = retro_intensity
	params.vertex_jitter_override = vertex_jitter_override
	params.affine_warp_override = affine_warp_override
	params.color_reduction_override = color_reduction_override
	params.dither_override = dither_override
	params.jitter_resolution = jitter_resolution
	params.lighting_enabled = lighting_enabled
	params.light_direction = light_direction
	params.light_color = light_color
	params.light_intensity = light_intensity
	params.ambient_color = ambient_color
	params.ambient_intensity = ambient_intensity
	params.use_half_lambert = use_half_lambert


## Load current global settings into this resource
func load_from_global() -> void:
	var params := _get_retro_params()
	if not params:
		push_warning("RetroSettings: RetroShaderParams singleton not found")
		return
	
	retro_enabled = params.retro_enabled
	retro_intensity = params.retro_intensity
	vertex_jitter_override = params.vertex_jitter_override
	affine_warp_override = params.affine_warp_override
	color_reduction_override = params.color_reduction_override
	dither_override = params.dither_override
	jitter_resolution = params.jitter_resolution
	lighting_enabled = params.lighting_enabled
	light_direction = params.light_direction
	light_color = params.light_color
	light_intensity = params.light_intensity
	ambient_color = params.ambient_color
	ambient_intensity = params.ambient_intensity
	use_half_lambert = params.use_half_lambert


## Create a copy of this settings resource
func duplicate_settings() -> RetroSettings:
	var copy := RetroSettings.new()
	copy.setting_name = setting_name + " (Copy)"
	copy.description = description
	copy.retro_enabled = retro_enabled
	copy.retro_intensity = retro_intensity
	copy.vertex_jitter_override = vertex_jitter_override
	copy.affine_warp_override = affine_warp_override
	copy.color_reduction_override = color_reduction_override
	copy.dither_override = dither_override
	copy.jitter_resolution = jitter_resolution
	copy.lighting_enabled = lighting_enabled
	copy.light_direction = light_direction
	copy.light_color = light_color
	copy.light_intensity = light_intensity
	copy.ambient_color = ambient_color
	copy.ambient_intensity = ambient_intensity
	copy.use_half_lambert = use_half_lambert
	copy.post_process_enabled = post_process_enabled
	copy.render_scale = render_scale
	copy.color_band_levels = color_band_levels
	return copy


## Interpolate between this settings and another (for transitions)
func lerp_to(other: RetroSettings, weight: float) -> RetroSettings:
	var result := RetroSettings.new()
	result.setting_name = "Interpolated"
	
	# Interpolate numeric values
	result.retro_intensity = lerpf(retro_intensity, other.retro_intensity, weight)
	result.vertex_jitter_override = lerpf(vertex_jitter_override, other.vertex_jitter_override, weight)
	result.affine_warp_override = lerpf(affine_warp_override, other.affine_warp_override, weight)
	result.color_reduction_override = lerpf(color_reduction_override, other.color_reduction_override, weight)
	result.dither_override = lerpf(dither_override, other.dither_override, weight)
	result.jitter_resolution = lerpf(jitter_resolution, other.jitter_resolution, weight)
	result.light_direction = light_direction.lerp(other.light_direction, weight)
	result.light_color = light_color.lerp(other.light_color, weight)
	result.light_intensity = lerpf(light_intensity, other.light_intensity, weight)
	result.ambient_color = ambient_color.lerp(other.ambient_color, weight)
	result.ambient_intensity = lerpf(ambient_intensity, other.ambient_intensity, weight)
	result.render_scale = lerpf(render_scale, other.render_scale, weight)
	result.color_band_levels = roundi(lerpf(color_band_levels, other.color_band_levels, weight))
	
	# Boolean values snap at 0.5
	result.retro_enabled = other.retro_enabled if weight > 0.5 else retro_enabled
	result.lighting_enabled = other.lighting_enabled if weight > 0.5 else lighting_enabled
	result.use_half_lambert = other.use_half_lambert if weight > 0.5 else use_half_lambert
	result.post_process_enabled = other.post_process_enabled if weight > 0.5 else post_process_enabled
	
	return result


func _get_retro_params() -> Node:
	# Try to get the autoload singleton
	if Engine.has_singleton("RetroShaderParams"):
		return Engine.get_singleton("RetroShaderParams")
	
	# Fallback: search in tree
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("RetroShaderParams")
	
	return null


## ===== PRESET FACTORY METHODS =====

## Create a "Modern" preset (no retro effects)
static func create_modern_preset() -> RetroSettings:
	var settings := RetroSettings.new()
	settings.setting_name = "Modern"
	settings.description = "No retro effects - clean modern rendering"
	settings.retro_enabled = false
	settings.retro_intensity = 0.0
	settings.render_scale = 1.0
	return settings


## Create a "Minimal" preset (25% - subtle retro hint)
static func create_minimal_preset() -> RetroSettings:
	var settings := RetroSettings.new()
	settings.setting_name = "Minimal"
	settings.description = "Subtle retro hint - barely noticeable effects"
	settings.retro_intensity = 0.25
	settings.render_scale = 0.85
	settings.color_band_levels = 128
	return settings


## Create a "Light" preset (35% - default, noticeable but clean)
static func create_light_preset() -> RetroSettings:
	var settings := RetroSettings.new()
	settings.setting_name = "Light"
	settings.description = "Default setting - noticeable retro feel without compromising playability"
	settings.retro_intensity = 0.35
	settings.render_scale = 0.75
	settings.color_band_levels = 64
	return settings


## Create a "Balanced" preset (50% - clear retro aesthetic)
static func create_balanced_preset() -> RetroSettings:
	var settings := RetroSettings.new()
	settings.setting_name = "Balanced"
	settings.description = "Clear retro aesthetic - unmistakably PS1/Saturn style"
	settings.retro_intensity = 0.5
	settings.render_scale = 0.66
	settings.color_band_levels = 48
	return settings


## Create a "Heavy" preset (75% - strong retro feel)
static func create_heavy_preset() -> RetroSettings:
	var settings := RetroSettings.new()
	settings.setting_name = "Heavy"
	settings.description = "Strong retro feel - significant visual degradation for authenticity"
	settings.retro_intensity = 0.75
	settings.render_scale = 0.5
	settings.color_band_levels = 32
	return settings


## Create an "Authentic" preset (100% - hardware-accurate)
static func create_authentic_preset() -> RetroSettings:
	var settings := RetroSettings.new()
	settings.setting_name = "Authentic"
	settings.description = "Hardware-accurate PS1/Saturn rendering - maximum retro effects"
	settings.retro_intensity = 1.0
	settings.render_scale = 0.33
	settings.color_band_levels = 32
	settings.dither_override = 1.0
	return settings
