@tool
class_name ZoneVisualSettings
extends Resource

## =============================================================================
## ZONE VISUAL SETTINGS
## =============================================================================
## Per-zone configuration for retro visual effects.
## Each zone/level can have unique visual parameters for variety.
##
## Usage:
##   1. Create a ZoneVisualSettings resource for each zone
##   2. Assign it to your level scene or zone manager
##   3. Call apply_to_scene() when entering the zone
## =============================================================================

## ===== METADATA =====
@export_group("Zone Info")
@export var zone_name: String = "Untitled Zone"
@export var zone_act: int = 1
@export_multiline var description: String = ""

## ===== RETRO SHADER SETTINGS =====
@export_group("Retro Effects")
@export var retro_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var retro_intensity: float = 0.35

## Override individual effects (-1.0 = use global setting)
@export_subgroup("Effect Overrides")
@export_range(-1.0, 1.0, 0.05) var vertex_jitter_override: float = -1.0
@export_range(-1.0, 1.0, 0.05) var affine_warp_override: float = -1.0
@export_range(-1.0, 1.0, 0.05) var color_reduction_override: float = -1.0
@export_range(-1.0, 1.0, 0.05) var dither_override: float = -1.0

## ===== LIGHTING =====
@export_group("Lighting")
@export var light_direction: Vector3 = Vector3(0.3, -0.7, -0.5)
@export var light_color: Color = Color(1.0, 0.98, 0.95)
@export_range(0.0, 2.0, 0.05) var light_intensity: float = 1.0
@export var ambient_color: Color = Color(0.3, 0.3, 0.35)
@export_range(0.0, 1.0, 0.05) var ambient_intensity: float = 0.4

## ===== ATMOSPHERE / DISTANCE EFFECTS =====
@export_group("Atmosphere")
@export var fog_enabled: bool = true
@export var fog_color: Color = Color(0.1, 0.1, 0.15, 1.0)
@export_range(10.0, 500.0, 5.0) var fog_start_distance: float = 50.0
@export_range(20.0, 1000.0, 10.0) var fog_end_distance: float = 150.0

## Distance at which wireframe/dissolve effects begin
@export_range(10.0, 500.0, 5.0) var effect_distance: float = 100.0

## ===== SKY / BACKGROUND =====
@export_group("Background")
@export var sky_top_color: Color = Color(0.2, 0.1, 0.4, 1.0)
@export var sky_horizon_color: Color = Color(0.5, 0.3, 0.6, 1.0)
@export var ground_color: Color = Color(0.1, 0.05, 0.15, 1.0)

## Optional skybox/environment resource
@export var custom_environment: Environment

## ===== COLOR GRADING =====
@export_group("Color Grading")
@export var color_tint: Color = Color.WHITE
@export_range(0.5, 2.0, 0.05) var saturation: float = 1.0
@export_range(0.5, 2.0, 0.05) var contrast: float = 1.0
@export_range(0.5, 1.5, 0.05) var brightness: float = 1.0

## ===== POST-PROCESSING =====
@export_group("Post-Processing")
@export var post_process_enabled: bool = true
@export_range(0.25, 1.0, 0.05) var render_scale: float = 0.75
@export_range(16, 256, 8) var color_band_levels: int = 64


## ===== METHODS =====

## Apply these settings to the scene
func apply_to_scene(scene_root: Node) -> void:
	_apply_retro_settings()
	_apply_environment(scene_root)
	_apply_post_process(scene_root)


## Apply retro shader settings via the global singleton
func _apply_retro_settings() -> void:
	var params := _get_retro_params()
	if not params:
		return
	
	params.retro_enabled = retro_enabled
	params.retro_intensity = retro_intensity
	params.vertex_jitter_override = vertex_jitter_override
	params.affine_warp_override = affine_warp_override
	params.color_reduction_override = color_reduction_override
	params.dither_override = dither_override
	params.light_direction = light_direction
	params.light_color = light_color
	params.light_intensity = light_intensity
	params.ambient_color = ambient_color
	params.ambient_intensity = ambient_intensity


## Apply environment settings
func _apply_environment(scene_root: Node) -> void:
	# Find WorldEnvironment in scene
	var world_env := _find_node_by_class(scene_root, "WorldEnvironment") as WorldEnvironment
	
	if world_env:
		if custom_environment:
			world_env.environment = custom_environment
		elif world_env.environment:
			# Modify existing environment
			var env := world_env.environment
			
			# Update sky if procedural
			if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
				var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
				sky_mat.sky_top_color = sky_top_color
				sky_mat.sky_horizon_color = sky_horizon_color
				sky_mat.ground_bottom_color = ground_color
				sky_mat.ground_horizon_color = sky_horizon_color.lerp(ground_color, 0.5)
			
			# Update fog
			env.fog_enabled = fog_enabled
			if fog_enabled:
				env.fog_light_color = fog_color
				# Note: Godot 4 fog works differently, using density instead of distance
				# We'll approximate with density
				env.fog_density = 0.01 / (fog_end_distance - fog_start_distance) * 100.0


## Apply post-processing settings
func _apply_post_process(scene_root: Node) -> void:
	# Find RetroViewportContainer
	var viewport_container := _find_node_by_class(scene_root, "RetroViewportContainer")
	
	if viewport_container:
		viewport_container.post_process_enabled = post_process_enabled
		viewport_container.render_scale = render_scale
		viewport_container.effect_intensity = retro_intensity
		viewport_container.band_levels = color_band_levels
		viewport_container.saturation = saturation
		viewport_container.contrast = contrast
		viewport_container.brightness = brightness
		viewport_container.color_tint = color_tint


func _get_retro_params() -> Node:
	if Engine.has_singleton("RetroShaderParams"):
		return Engine.get_singleton("RetroShaderParams")
	
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("RetroShaderParams")
	
	return null


func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	if node.is_class(class_name_str) or node.get_class() == class_name_str:
		return node
	
	# Check script class_name
	if node.get_script():
		var script := node.get_script() as Script
		if script.get_global_name() == class_name_str:
			return node
	
	for child in node.get_children():
		var found := _find_node_by_class(child, class_name_str)
		if found:
			return found
	
	return null


## ===== PRESET FACTORY METHODS =====

## Create a Green Hill-style zone (bright, grassy)
static func create_green_hill_preset() -> ZoneVisualSettings:
	var settings := ZoneVisualSettings.new()
	settings.zone_name = "Green Hill"
	settings.description = "Bright, sunny grassy zone"
	
	settings.light_direction = Vector3(0.3, -0.8, -0.4)
	settings.light_color = Color(1.0, 0.98, 0.9)
	settings.light_intensity = 1.2
	settings.ambient_color = Color(0.4, 0.45, 0.35)
	settings.ambient_intensity = 0.5
	
	settings.sky_top_color = Color(0.3, 0.6, 1.0)
	settings.sky_horizon_color = Color(0.7, 0.85, 1.0)
	settings.ground_color = Color(0.2, 0.4, 0.2)
	
	settings.fog_color = Color(0.5, 0.7, 0.9)
	settings.fog_start_distance = 80.0
	settings.fog_end_distance = 200.0
	
	return settings


## Create a Chemical Plant-style zone (industrial, purple/blue)
static func create_chemical_plant_preset() -> ZoneVisualSettings:
	var settings := ZoneVisualSettings.new()
	settings.zone_name = "Chemical Plant"
	settings.description = "Industrial zone with purple tones"
	
	settings.light_direction = Vector3(0.2, -0.6, -0.5)
	settings.light_color = Color(0.9, 0.85, 1.0)
	settings.light_intensity = 1.0
	settings.ambient_color = Color(0.3, 0.25, 0.4)
	settings.ambient_intensity = 0.45
	
	settings.sky_top_color = Color(0.15, 0.1, 0.3)
	settings.sky_horizon_color = Color(0.4, 0.2, 0.5)
	settings.ground_color = Color(0.1, 0.05, 0.15)
	
	settings.fog_color = Color(0.2, 0.1, 0.3)
	settings.fog_start_distance = 60.0
	settings.fog_end_distance = 150.0
	
	settings.color_tint = Color(0.95, 0.9, 1.0)
	
	return settings


## Create a Lava Reef-style zone (hot, orange/red)
static func create_lava_reef_preset() -> ZoneVisualSettings:
	var settings := ZoneVisualSettings.new()
	settings.zone_name = "Lava Reef"
	settings.description = "Hot volcanic zone"
	
	settings.light_direction = Vector3(0.1, -0.5, -0.6)
	settings.light_color = Color(1.0, 0.8, 0.6)
	settings.light_intensity = 1.1
	settings.ambient_color = Color(0.5, 0.25, 0.15)
	settings.ambient_intensity = 0.5
	
	settings.sky_top_color = Color(0.3, 0.1, 0.05)
	settings.sky_horizon_color = Color(0.8, 0.4, 0.2)
	settings.ground_color = Color(0.2, 0.05, 0.0)
	
	settings.fog_color = Color(0.4, 0.15, 0.05)
	settings.fog_start_distance = 40.0
	settings.fog_end_distance = 120.0
	
	settings.color_tint = Color(1.0, 0.95, 0.9)
	settings.saturation = 1.1
	
	return settings


## Create a night zone (dark, blue tones)
static func create_night_preset() -> ZoneVisualSettings:
	var settings := ZoneVisualSettings.new()
	settings.zone_name = "Night Zone"
	settings.description = "Dark nighttime setting"
	
	settings.light_direction = Vector3(0.5, -0.3, -0.5)
	settings.light_color = Color(0.7, 0.75, 0.9)
	settings.light_intensity = 0.6
	settings.ambient_color = Color(0.15, 0.15, 0.25)
	settings.ambient_intensity = 0.6
	
	settings.sky_top_color = Color(0.02, 0.02, 0.08)
	settings.sky_horizon_color = Color(0.1, 0.1, 0.2)
	settings.ground_color = Color(0.02, 0.02, 0.05)
	
	settings.fog_color = Color(0.05, 0.05, 0.1)
	settings.fog_start_distance = 50.0
	settings.fog_end_distance = 130.0
	
	settings.brightness = 0.9
	
	return settings
