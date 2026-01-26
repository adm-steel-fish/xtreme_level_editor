@tool
class_name RetroViewportContainer
extends SubViewportContainer

## =============================================================================
## RETRO VIEWPORT CONTAINER
## =============================================================================
## Sets up a SubViewport with retro post-processing effects.
## The 3D world renders to a SubViewport, which then has post-processing
## applied via a CanvasItem shader.
##
## Structure:
##   RetroViewportContainer (this node)
##   └── SubViewport (3D gameplay renders here)
##       └── [Your 3D scene content]
##
## UI/HUD should be placed as siblings to this container, NOT inside the
## SubViewport, so they remain unaffected by post-processing.
##
## Usage:
##   1. Add RetroViewportContainer to your scene
##   2. Place your 3D content inside the SubViewport child
##   3. Place UI/HUD as siblings (outside this container)
##   4. Adjust retro_intensity and other parameters
## =============================================================================

## Emitted when post-processing parameters change
signal post_process_changed()

## ===== POST-PROCESS SETTINGS =====
@export_group("Retro Post-Processing")
@export var post_process_enabled: bool = true:
	set(value):
		post_process_enabled = value
		_update_post_process_material()

@export_range(0.0, 1.0, 0.05) var effect_intensity: float = 0.35:
	set(value):
		effect_intensity = value
		_update_post_process_material()

## ===== RESOLUTION SETTINGS =====
@export_group("Resolution")
@export_range(0.25, 1.0, 0.05) var render_scale: float = 0.75:
	set(value):
		render_scale = clampf(value, 0.25, 1.0)
		_update_viewport_size()

@export var use_nearest_filtering: bool = true:
	set(value):
		use_nearest_filtering = value
		_update_viewport_settings()

## ===== COLOR BANDING =====
@export_group("Color Banding")
@export var color_banding_enabled: bool = true:
	set(value):
		color_banding_enabled = value
		_update_post_process_material()

@export_range(8, 256, 8) var band_levels: int = 64:
	set(value):
		band_levels = value
		_update_post_process_material()

@export var use_dithering: bool = true:
	set(value):
		use_dithering = value
		_update_post_process_material()

@export_range(0.0, 1.0, 0.05) var dither_strength: float = 0.5:
	set(value):
		dither_strength = value
		_update_post_process_material()

## ===== COLOR ADJUSTMENTS =====
@export_group("Color Adjustments")
@export_range(0.0, 2.0, 0.05) var saturation: float = 1.0:
	set(value):
		saturation = value
		_update_post_process_material()

@export_range(0.5, 2.0, 0.05) var contrast: float = 1.0:
	set(value):
		contrast = value
		_update_post_process_material()

@export_range(0.5, 1.5, 0.05) var brightness: float = 1.0:
	set(value):
		brightness = value
		_update_post_process_material()

@export var color_tint: Color = Color.WHITE:
	set(value):
		color_tint = value
		_update_post_process_material()

## ===== INTERNAL =====
var _viewport: SubViewport
var _post_process_material: ShaderMaterial
var _base_size: Vector2i = Vector2i(1920, 1080)


func _ready() -> void:
	_setup_viewport()
	_setup_post_process()
	
	# Connect to window resize
	if not Engine.is_editor_hint():
		get_tree().root.size_changed.connect(_on_window_resized)


func _enter_tree() -> void:
	# Ensure we stretch to fill parent
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _setup_viewport() -> void:
	# Find or create the SubViewport
	_viewport = null
	for child in get_children():
		if child is SubViewport:
			_viewport = child
			break
	
	if not _viewport:
		_viewport = SubViewport.new()
		_viewport.name = "GameplayViewport"
		add_child(_viewport)
		if Engine.is_editor_hint():
			_viewport.owner = get_tree().edited_scene_root
	
	_update_viewport_settings()
	_update_viewport_size()


func _setup_post_process() -> void:
	# Load post-process shader
	var shader := load("res://addons/xtreme_level_editor/shaders/retro/retro_post_process.gdshader") as Shader
	if not shader:
		push_warning("RetroViewportContainer: Post-process shader not found")
		return
	
	_post_process_material = ShaderMaterial.new()
	_post_process_material.shader = shader
	
	# Apply material to self (SubViewportContainer)
	material = _post_process_material
	
	_update_post_process_material()


func _update_viewport_settings() -> void:
	if not _viewport:
		return
	
	# Configure viewport for retro rendering
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	
	# Set texture filtering based on setting
	if use_nearest_filtering:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	# Ensure viewport renders 3D properly
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = false
	
	# Transparent background if needed (usually not for full-screen gameplay)
	_viewport.transparent_bg = false


func _update_viewport_size() -> void:
	if not _viewport:
		return
	
	# Get base size from window or default
	if not Engine.is_editor_hint() and get_tree():
		_base_size = get_tree().root.size
	
	# Apply render scale
	var scaled_size := Vector2i(
		int(_base_size.x * render_scale),
		int(_base_size.y * render_scale)
	)
	
	# Ensure minimum size
	scaled_size = scaled_size.max(Vector2i(320, 240))
	
	_viewport.size = scaled_size
	
	# Update stretch settings
	stretch = true
	stretch_shrink = 1


func _update_post_process_material() -> void:
	if not _post_process_material:
		return
	
	# Update shader uniforms
	_post_process_material.set_shader_parameter("effects_enabled", post_process_enabled)
	_post_process_material.set_shader_parameter("effect_intensity", effect_intensity)
	_post_process_material.set_shader_parameter("color_banding_enabled", color_banding_enabled)
	_post_process_material.set_shader_parameter("band_levels", band_levels)
	_post_process_material.set_shader_parameter("use_dithering", use_dithering)
	_post_process_material.set_shader_parameter("dither_strength", dither_strength)
	_post_process_material.set_shader_parameter("saturation", saturation)
	_post_process_material.set_shader_parameter("contrast", contrast)
	_post_process_material.set_shader_parameter("brightness", brightness)
	_post_process_material.set_shader_parameter("color_tint", Vector3(color_tint.r, color_tint.g, color_tint.b))
	
	post_process_changed.emit()


func _on_window_resized() -> void:
	_update_viewport_size()


## ===== PUBLIC API =====

## Get the gameplay SubViewport
func get_gameplay_viewport() -> SubViewport:
	return _viewport


## Apply settings from a RetroSettings resource
func apply_settings(settings: Resource) -> void:
	if not settings:
		return
	
	# Check if it has the expected properties
	if settings.has_method("get") or "post_process_enabled" in settings:
		post_process_enabled = settings.get("post_process_enabled") if "post_process_enabled" in settings else true
		render_scale = settings.get("render_scale") if "render_scale" in settings else 0.75
		effect_intensity = settings.get("retro_intensity") if "retro_intensity" in settings else 0.35
		band_levels = settings.get("color_band_levels") if "color_band_levels" in settings else 64


## Disable all post-processing (for editor preview mode)
func set_editor_mode(enabled: bool) -> void:
	if enabled:
		post_process_enabled = false
		render_scale = 1.0
	else:
		# Restore defaults or last settings
		post_process_enabled = true
		render_scale = 0.75


## Take a clean screenshot (temporarily disable effects)
func capture_clean_screenshot() -> Image:
	if not _viewport:
		return null
	
	# Store current settings
	var was_enabled := post_process_enabled
	var old_scale := render_scale
	
	# Disable effects temporarily
	post_process_enabled = false
	render_scale = 1.0
	_update_viewport_size()
	
	# Wait for render
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Capture
	var image := _viewport.get_texture().get_image()
	
	# Restore settings
	post_process_enabled = was_enabled
	render_scale = old_scale
	_update_viewport_size()
	
	return image


## Take a retro screenshot (with effects)
func capture_retro_screenshot() -> Image:
	if not _viewport:
		return null
	
	# Wait for render
	await get_tree().process_frame
	
	return _viewport.get_texture().get_image()
