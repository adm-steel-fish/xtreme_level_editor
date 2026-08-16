@tool
class_name XtremeGridVisualizer
extends Node3D

## Renders the 3D grid level in the editor viewport.
## Handles efficient display of large grids using chunked rendering.

signal cell_selected(position: Vector3i)
signal cell_hovered(position: Vector3i)

## The level data to visualize
@export var level_data: XtremeLevelData:
	set(value):
		level_data = value
		_rebuild_visualization()

## The tile palette for looking up tile visuals
@export var tile_palette: XtremeTilePalette:
	set(value):
		tile_palette = value
		_rebuild_visualization()

## Grid settings reference
@export var grid_settings: XtremeGridSettings:
	set(value):
		# Disconnect old signal if exists
		if grid_settings and grid_settings.changed.is_connected(_on_grid_settings_changed):
			grid_settings.changed.disconnect(_on_grid_settings_changed)
		
		grid_settings = value
		
		# Connect new signal
		if grid_settings and not grid_settings.changed.is_connected(_on_grid_settings_changed):
			grid_settings.changed.connect(_on_grid_settings_changed)
		
		_rebuild_visualization()

@export_group("Visualization")
## Show the grid boundary wireframe
@export var show_grid_bounds: bool = true:
	set(value):
		show_grid_bounds = value
		_update_bounds_visibility()

## Show empty cell grid lines
@export var show_empty_grid: bool = false:
	set(value):
		show_empty_grid = value
		_rebuild_visualization()

## Grid line color
@export var grid_color: Color = Color(0.3, 0.5, 1.0, 0.3)

## Selected cell highlight color
@export var selection_color: Color = Color(1.0, 0.8, 0.2, 0.8)

## Hovered cell highlight color
@export var hover_color: Color = Color(0.5, 1.0, 0.5, 0.5)

@export_group("Curved World Preview")
## Enable curved world shader preview
@export var curved_preview_enabled: bool = false:
	set(value):
		curved_preview_enabled = value
		_update_curved_world()

## Horizontal curvature intensity (bends world left/right)
@export_range(0.0, 0.3, 0.001) var curve_horizontal: float = 0.15:
	set(value):
		curve_horizontal = value
		_update_curved_world()

## Vertical curvature intensity (bends world up/down)
@export_range(0.0, 0.3, 0.001) var curve_vertical: float = 0.08:
	set(value):
		curve_vertical = value
		_update_curved_world()

## Curvature falloff exponent (2.0 = quadratic, higher = more dramatic at edges)
@export_range(1.0, 4.0, 0.1) var curve_falloff_exponent: float = 2.0:
	set(value):
		curve_falloff_exponent = value
		_update_curved_world()

## Curvature mode (0=spherical, 1=cylindrical X, 2=cylindrical Z)
@export_range(0, 2, 1) var curve_mode: int = 0:
	set(value):
		curve_mode = value
		_update_curved_world()

## Preview center point (simulates camera/player position)
@export var curve_center: Vector3 = Vector3.ZERO:
	set(value):
		curve_center = value
		_update_curved_world()

@export_group("Distance Effects")
## Enable distance-based wireframe and dissolve effects
@export var distance_effects_enabled: bool = true:
	set(value):
		distance_effects_enabled = value
		_update_curved_world()

## Maximum distance for effects
@export var effect_max_distance: float = 150.0:
	set(value):
		effect_max_distance = value
		_update_curved_world()

## Distance ratio at which wireframe starts appearing (0-1)
@export_range(0.0, 1.0, 0.05) var wireframe_start: float = 0.3:
	set(value):
		wireframe_start = value
		_update_curved_world()

## Distance ratio at which wireframe is fully visible (0-1)
@export_range(0.0, 1.0, 0.05) var wireframe_full: float = 0.7:
	set(value):
		wireframe_full = value
		_update_curved_world()

## Distance ratio at which dissolve starts (0-1)
@export_range(0.0, 1.0, 0.05) var dissolve_start: float = 0.3:
	set(value):
		dissolve_start = value
		_update_curved_world()

## Distance ratio at which fully dissolved (0-1)
@export_range(0.0, 1.0, 0.05) var dissolve_full: float = 0.9:
	set(value):
		dissolve_full = value
		_update_curved_world()

@export_group("Performance")
## Chunk size for rendering (in cells)
@export var render_chunk_size: int = 16

## Maximum visible distance (in cells)
@export var render_distance: int = 64

# Internal references
var _bounds_mesh: MeshInstance3D
var _tile_instances: Dictionary = {}  # Key: Vector3i, Value: Node3D
var _hover_indicator: MeshInstance3D
var _selection_indicator: MeshInstance3D
var _curved_world_material: ShaderMaterial

# Current state
var _current_hover: Vector3i = Vector3i(-999, -999, -999)
var _current_selection: Vector3i = Vector3i(-999, -999, -999)
var _is_ready: bool = false

func _ready() -> void:
	_setup_indicators()
	_setup_curved_world_material()
	_is_ready = true
	_rebuild_visualization()

func _setup_indicators() -> void:
	# Hover indicator
	_hover_indicator = MeshInstance3D.new()
	_hover_indicator.mesh = BoxMesh.new()
	var hover_mat := StandardMaterial3D.new()
	hover_mat.albedo_color = hover_color
	hover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hover_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_indicator.material_override = hover_mat
	_hover_indicator.visible = false
	add_child(_hover_indicator)
	
	# Selection indicator
	_selection_indicator = MeshInstance3D.new()
	_selection_indicator.mesh = BoxMesh.new()
	var select_mat := StandardMaterial3D.new()
	select_mat.albedo_color = selection_color
	select_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	select_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selection_indicator.material_override = select_mat
	_selection_indicator.visible = false
	add_child(_selection_indicator)
	
	# Bounds wireframe
	_bounds_mesh = MeshInstance3D.new()
	var bounds_mat := StandardMaterial3D.new()
	bounds_mat.albedo_color = grid_color
	bounds_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bounds_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bounds_mesh.material_override = bounds_mat
	add_child(_bounds_mesh)

func _setup_curved_world_material() -> void:
	var shader_path := "res://addons/xtreme_level_editor/shaders/curved_world.gdshader"
	if ResourceLoader.exists(shader_path):
		var shader := load(shader_path)
		if shader:
			_curved_world_material = ShaderMaterial.new()
			_curved_world_material.shader = shader

func _rebuild_visualization() -> void:
	if not _is_ready or not is_inside_tree():
		return
	
	# Clear existing tile instances
	for key in _tile_instances.keys():
		var instance: Node3D = _tile_instances[key]
		if instance and is_instance_valid(instance):
			instance.queue_free()
	_tile_instances.clear()
	
	if not level_data or not grid_settings:
		return
	
	# Update indicator sizes
	var cell_size := grid_settings.get_cell_size()
	if _hover_indicator and _hover_indicator.mesh is BoxMesh:
		(_hover_indicator.mesh as BoxMesh).size = cell_size * 1.01
	if _selection_indicator and _selection_indicator.mesh is BoxMesh:
		(_selection_indicator.mesh as BoxMesh).size = cell_size * 1.02
	
	# Rebuild bounds
	_rebuild_bounds()
	
	# Rebuild tile visuals
	var positions := level_data.get_all_tile_positions()
	for pos in positions:
		_create_tile_visual(pos)
	
	_update_curved_world()

func _rebuild_bounds() -> void:
	if not _bounds_mesh or not level_data or not grid_settings:
		return
	
	var cell_size := grid_settings.get_cell_size()
	var level_size := Vector3(level_data.size_x, level_data.size_y, level_data.size_z) * cell_size

	# The box is built from the origin corner outward, so shift the whole mesh
	# by the level origin rather than rewriting every vertex. Levels with a
	# negative origin.y then show their bounds below y=0 where they belong.
	_bounds_mesh.position = Vector3(level_data.origin) * cell_size

	# Create wireframe box for bounds
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Bottom face
	im.surface_add_vertex(Vector3(0, 0, 0))
	im.surface_add_vertex(Vector3(level_size.x, 0, 0))
	im.surface_add_vertex(Vector3(level_size.x, 0, 0))
	im.surface_add_vertex(Vector3(level_size.x, 0, level_size.z))
	im.surface_add_vertex(Vector3(level_size.x, 0, level_size.z))
	im.surface_add_vertex(Vector3(0, 0, level_size.z))
	im.surface_add_vertex(Vector3(0, 0, level_size.z))
	im.surface_add_vertex(Vector3(0, 0, 0))
	
	# Top face
	im.surface_add_vertex(Vector3(0, level_size.y, 0))
	im.surface_add_vertex(Vector3(level_size.x, level_size.y, 0))
	im.surface_add_vertex(Vector3(level_size.x, level_size.y, 0))
	im.surface_add_vertex(Vector3(level_size.x, level_size.y, level_size.z))
	im.surface_add_vertex(Vector3(level_size.x, level_size.y, level_size.z))
	im.surface_add_vertex(Vector3(0, level_size.y, level_size.z))
	im.surface_add_vertex(Vector3(0, level_size.y, level_size.z))
	im.surface_add_vertex(Vector3(0, level_size.y, 0))
	
	# Vertical edges
	im.surface_add_vertex(Vector3(0, 0, 0))
	im.surface_add_vertex(Vector3(0, level_size.y, 0))
	im.surface_add_vertex(Vector3(level_size.x, 0, 0))
	im.surface_add_vertex(Vector3(level_size.x, level_size.y, 0))
	im.surface_add_vertex(Vector3(level_size.x, 0, level_size.z))
	im.surface_add_vertex(Vector3(level_size.x, level_size.y, level_size.z))
	im.surface_add_vertex(Vector3(0, 0, level_size.z))
	im.surface_add_vertex(Vector3(0, level_size.y, level_size.z))
	
	im.surface_end()
	_bounds_mesh.mesh = im

func _create_tile_visual(pos: Vector3i) -> void:
	if not level_data or not grid_settings:
		return
	
	var tile_id := level_data.get_tile(pos)
	if tile_id == &"":
		return
	
	# Skip multi-cell part markers
	if tile_id == &"_multicell_part":
		return
	
	var cell_size := grid_settings.get_cell_size()
	var world_pos := grid_settings.grid_to_world(pos)
	
	# Try to get tile definition from palette
	var tile_def: XtremeTileDefinition = null
	if tile_palette:
		tile_def = tile_palette.get_tile(tile_id)
	
	# Get rotation for proper size calculation
	var tile_rotation := level_data.get_tile_rotation(pos)
	
	# Calculate visual size based on tile definition cell_size and rotation
	var tile_cell_count := Vector3i(1, 1, 1)
	if tile_def:
		tile_cell_count = tile_def.cell_size
	
	# Get rotated size
	var rotated_cell_count := tile_cell_count
	if tile_rotation != Vector3i.ZERO and tile_def:
		rotated_cell_count = tile_def.get_rotated_size(tile_rotation)
	
	# Calculate actual visual size
	var visual_size := Vector3(
		cell_size.x * rotated_cell_count.x,
		cell_size.y * rotated_cell_count.y,
		cell_size.z * rotated_cell_count.z
	) * 0.95  # Slightly smaller to show grid
	
	# Offset position for multi-cell objects (center them on their footprint)
	var offset := Vector3(
		(rotated_cell_count.x - 1) * cell_size.x * 0.5,
		(rotated_cell_count.y - 1) * cell_size.y * 0.5,
		(rotated_cell_count.z - 1) * cell_size.z * 0.5
	)
	
	var visual: Node3D
	
	if tile_def and tile_def.tile_scene:
		# Use the tile's scene
		visual = tile_def.tile_scene.instantiate()
	elif tile_def and tile_def.has_custom_mesh():
		# Custom mesh tile. Wrap in a holder so the mesh's own offset/rotation/
		# scale survive the position and grid-rotation applied below — this
		# mirrors the exporter's Transform3D(rot_basis, world_pos) * mesh_local,
		# so what you see here is what gets baked.
		var holder := Node3D.new()
		var custom_instance := MeshInstance3D.new()
		custom_instance.name = "Mesh"
		custom_instance.mesh = tile_def.mesh
		custom_instance.transform = tile_def.get_mesh_local_transform()
		holder.add_child(custom_instance)
		visual = holder
	elif tile_def and tile_def.preview_mesh:
		# Use preview mesh
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = tile_def.preview_mesh
		visual = mesh_instance
	else:
		# Default: colored box based on tile type
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = visual_size
		mesh_instance.mesh = box
		
		var mat := StandardMaterial3D.new()
		if tile_def:
			mat.albedo_color = tile_def.editor_color
		else:
			mat.albedo_color = _get_default_color_for_id(tile_id)
		mesh_instance.material_override = mat
		visual = mesh_instance
	
	visual.position = world_pos + offset
	visual.name = "Tile_%d_%d_%d" % [pos.x, pos.y, pos.z]
	
	# Apply rotation if the level data has rotation for this tile
	if tile_rotation != Vector3i.ZERO:
		visual.rotation_degrees = Vector3(
			tile_rotation.x * 90.0,
			tile_rotation.y * 90.0,
			tile_rotation.z * 90.0
		)
	
	add_child(visual)
	_tile_instances[pos] = visual
	
	# Apply curved world material if preview is enabled.
	# Recurses, so custom-mesh holders and scene-based tiles get it too — a
	# plain `visual is MeshInstance3D` check missed both.
	if curved_preview_enabled or distance_effects_enabled:
		_apply_curved_material_recursive(visual)


func _apply_curved_material_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_curved_material(node as MeshInstance3D)
	for child in node.get_children():
		_apply_curved_material_recursive(child)

func _remove_tile_visual(pos: Vector3i) -> void:
	if pos in _tile_instances:
		var visual: Node3D = _tile_instances[pos]
		if visual and is_instance_valid(visual):
			visual.queue_free()
		_tile_instances.erase(pos)

func _get_default_color_for_id(tile_id: StringName) -> Color:
	# Generate a consistent color based on tile ID hash
	var hash_val := tile_id.hash()
	return Color.from_hsv(
		fmod(float(hash_val) / 1000.0, 1.0),
		0.6,
		0.8
	)

func _update_bounds_visibility() -> void:
	if _bounds_mesh:
		_bounds_mesh.visible = show_grid_bounds

func _update_curved_world() -> void:
	if not _curved_world_material:
		return
	
	# Curvature settings
	_curved_world_material.set_shader_parameter("curve_enabled", curved_preview_enabled)
	_curved_world_material.set_shader_parameter("curve_horizontal", curve_horizontal)
	_curved_world_material.set_shader_parameter("curve_vertical", curve_vertical)
	_curved_world_material.set_shader_parameter("curve_falloff_exponent", curve_falloff_exponent)
	_curved_world_material.set_shader_parameter("curve_intensity", 0.0)  # Deprecated, use new params
	_curved_world_material.set_shader_parameter("curve_mode", curve_mode)
	_curved_world_material.set_shader_parameter("curve_center", curve_center)
	
	# Distance effect settings
	_curved_world_material.set_shader_parameter("distance_effects_enabled", distance_effects_enabled)
	_curved_world_material.set_shader_parameter("effect_max_distance", effect_max_distance)
	_curved_world_material.set_shader_parameter("wireframe_start", wireframe_start)
	_curved_world_material.set_shader_parameter("wireframe_full", wireframe_full)
	_curved_world_material.set_shader_parameter("dissolve_start", dissolve_start)
	_curved_world_material.set_shader_parameter("dissolve_full", dissolve_full)
	
	# Update all tile visuals
	for pos in _tile_instances.keys():
		var visual: Node3D = _tile_instances[pos]
		if visual is MeshInstance3D:
			if curved_preview_enabled or distance_effects_enabled:
				_apply_curved_material(visual as MeshInstance3D)
			else:
				_remove_curved_material(visual as MeshInstance3D)

func _apply_curved_material(mesh_instance: MeshInstance3D) -> void:
	if not _curved_world_material:
		return
	
	# Clone the material and apply curved world shader
	var current_mat := mesh_instance.material_override
	if current_mat is StandardMaterial3D:
		var curved_mat := _curved_world_material.duplicate() as ShaderMaterial
		
		# Appearance from original material
		curved_mat.set_shader_parameter("albedo", current_mat.albedo_color)
		curved_mat.set_shader_parameter("roughness", current_mat.roughness)
		curved_mat.set_shader_parameter("metallic", current_mat.metallic)
		
		# Curvature settings
		curved_mat.set_shader_parameter("curve_enabled", curved_preview_enabled)
		curved_mat.set_shader_parameter("curve_horizontal", curve_horizontal)
		curved_mat.set_shader_parameter("curve_vertical", curve_vertical)
		curved_mat.set_shader_parameter("curve_falloff_exponent", curve_falloff_exponent)
		curved_mat.set_shader_parameter("curve_intensity", 0.0)  # Deprecated
		curved_mat.set_shader_parameter("curve_mode", curve_mode)
		curved_mat.set_shader_parameter("curve_center", curve_center)
		
		# Distance effect settings
		curved_mat.set_shader_parameter("distance_effects_enabled", distance_effects_enabled)
		curved_mat.set_shader_parameter("effect_max_distance", effect_max_distance)
		curved_mat.set_shader_parameter("wireframe_start", wireframe_start)
		curved_mat.set_shader_parameter("wireframe_full", wireframe_full)
		curved_mat.set_shader_parameter("dissolve_start", dissolve_start)
		curved_mat.set_shader_parameter("dissolve_full", dissolve_full)
		
		mesh_instance.set_meta("original_material", current_mat)
		mesh_instance.material_override = curved_mat

func _remove_curved_material(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.has_meta("original_material"):
		mesh_instance.material_override = mesh_instance.get_meta("original_material")
		mesh_instance.remove_meta("original_material")

func _on_grid_settings_changed() -> void:
	_rebuild_visualization()

# ============ Public API ============

## Set the hovered cell position
func set_hover_position(pos: Vector3i) -> void:
	if pos == _current_hover:
		return
	
	_current_hover = pos
	
	if not grid_settings or pos.x < 0:
		_hover_indicator.visible = false
		return
	
	_hover_indicator.visible = true
	_hover_indicator.position = grid_settings.grid_to_world(pos)
	cell_hovered.emit(pos)

## Set the selected cell position
func set_selection_position(pos: Vector3i) -> void:
	if pos == _current_selection:
		return
	
	_current_selection = pos
	
	if not grid_settings or pos.x < 0:
		_selection_indicator.visible = false
		return
	
	_selection_indicator.visible = true
	_selection_indicator.position = grid_settings.grid_to_world(pos)
	cell_selected.emit(pos)

## Clear selection
func clear_selection() -> void:
	_current_selection = Vector3i(-999, -999, -999)
	_selection_indicator.visible = false

## Update a single tile's visual (more efficient than full rebuild)
func update_tile(pos: Vector3i) -> void:
	_remove_tile_visual(pos)
	if level_data and level_data.has_tile(pos):
		_create_tile_visual(pos)

## Force rebuild of all visuals
func rebuild() -> void:
	_rebuild_visualization()

## Get world position from grid position
func grid_to_world(grid_pos: Vector3i) -> Vector3:
	if grid_settings:
		return grid_settings.grid_to_world(grid_pos)
	return Vector3(grid_pos)

## Get grid position from world position
func world_to_grid(world_pos: Vector3) -> Vector3i:
	if grid_settings:
		return grid_settings.world_to_grid(world_pos)
	return Vector3i(world_pos.floor())

func _exit_tree() -> void:
	# Clean up signal connection
	if grid_settings and grid_settings.changed.is_connected(_on_grid_settings_changed):
		grid_settings.changed.disconnect(_on_grid_settings_changed)
