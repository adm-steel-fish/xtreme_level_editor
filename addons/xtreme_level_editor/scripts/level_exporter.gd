@tool
class_name XtremeLevelExporter
extends RefCounted

## Exports level data to a playable scene with all proper settings applied.
## This includes optionally applying the curved world shader to all materials.

## Export settings
var apply_curved_world: bool = true
var curve_intensity: float = 0.01
var curve_mode: int = 0  # 0=spherical, 1=cylindrical X, 2=cylindrical Z
var curve_max_distance: float = 200.0

var generate_collision: bool = true
var optimize_meshes: bool = true
var create_navigation: bool = false

## References
var grid_settings: XtremeGridSettings
var tile_palette: XtremeTilePalette
var level_data: XtremeLevelData

## The curved world shader resource
var _curved_shader: Shader

func _init() -> void:
	# Try to load the curved world shader
	_curved_shader = load("res://addons/xtreme_level_editor/shaders/curved_world.gdshader")

## Export level data to a complete scene
func export_level(output_path: String) -> Error:
	if not level_data:
		push_error("No level data to export")
		return ERR_INVALID_DATA
	
	if not grid_settings:
		push_error("No grid settings provided")
		return ERR_INVALID_DATA
	
	# Create root node
	var root := Node3D.new()
	root.name = level_data.level_name.replace(" ", "_")
	
	# Create geometry container
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	root.add_child(geometry)
	geometry.owner = root
	
	# Create entities container (enemies, collectibles, etc.)
	var entities := Node3D.new()
	entities.name = "Entities"
	root.add_child(entities)
	entities.owner = root
	
	# Process all tiles
	var cell_size := grid_settings.get_cell_size()
	var positions := level_data.get_all_tile_positions()
	
	for pos in positions:
		var tile_id := level_data.get_tile(pos)
		var world_pos := grid_settings.grid_to_world(pos)
		
		var tile_def: XtremeTileDefinition = null
		if tile_palette:
			tile_def = tile_palette.get_tile(tile_id)
		
		var tile_node := _create_tile_node(tile_id, tile_def, world_pos, cell_size)
		if tile_node:
			# Decide which container based on tile type
			var container := geometry
			if tile_def:
				match tile_def.tile_type:
					XtremeTileDefinition.TileType.ENEMY, \
					XtremeTileDefinition.TileType.COLLECTIBLE, \
					XtremeTileDefinition.TileType.CHECKPOINT, \
					XtremeTileDefinition.TileType.GOAL:
						container = entities
			
			container.add_child(tile_node)
			tile_node.owner = root
			
			# Set ownership for all children
			_set_owner_recursive(tile_node, root)
	
	# Add level metadata as a script/resource
	var meta_node := Node.new()
	meta_node.name = "LevelMetadata"
	meta_node.set_meta("level_name", level_data.level_name)
	meta_node.set_meta("level_author", level_data.level_author)
	meta_node.set_meta("theme", level_data.theme)
	meta_node.set_meta("size_x", level_data.size_x)
	meta_node.set_meta("size_y", level_data.size_y)
	meta_node.set_meta("size_z", level_data.size_z)
	root.add_child(meta_node)
	meta_node.owner = root
	
	# Save the scene
	var packed_scene := PackedScene.new()
	var result := packed_scene.pack(root)
	if result != OK:
		push_error("Failed to pack scene: %s" % result)
		root.queue_free()
		return result
	
	result = ResourceSaver.save(packed_scene, output_path)
	if result != OK:
		push_error("Failed to save scene to %s: %s" % [output_path, result])
	
	root.queue_free()
	return result

func _create_tile_node(tile_id: StringName, tile_def: XtremeTileDefinition, world_pos: Vector3, cell_size: Vector3) -> Node3D:
	var node: Node3D
	
	if tile_def and tile_def.tile_scene:
		# Instantiate the tile's scene
		node = tile_def.tile_scene.instantiate()
	else:
		# Create default geometry
		node = _create_default_tile(tile_id, tile_def, cell_size)
	
	if node:
		node.position = world_pos
		node.name = "Tile_%s" % tile_id
		
		# Apply curved world shader if enabled
		if apply_curved_world:
			_apply_curved_shader_recursive(node)
		
		# Add collision if needed
		if generate_collision and tile_def and tile_def.is_solid:
			_add_collision(node, cell_size)
	
	return node

func _create_default_tile(tile_id: StringName, tile_def: XtremeTileDefinition, cell_size: Vector3) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	
	var box := BoxMesh.new()
	box.size = cell_size
	mesh_instance.mesh = box
	
	var mat := StandardMaterial3D.new()
	if tile_def:
		mat.albedo_color = tile_def.editor_color
	else:
		mat.albedo_color = Color.GRAY
	mesh_instance.material_override = mat
	
	return mesh_instance

func _apply_curved_shader_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_curved_shader_to_mesh(node as MeshInstance3D)
	
	for child in node.get_children():
		_apply_curved_shader_recursive(child)

func _apply_curved_shader_to_mesh(mesh_instance: MeshInstance3D) -> void:
	if not _curved_shader:
		return
	
	# Get the current material
	var original_mat: Material
	if mesh_instance.material_override:
		original_mat = mesh_instance.material_override
	elif mesh_instance.mesh and mesh_instance.mesh.get_surface_count() > 0:
		original_mat = mesh_instance.mesh.surface_get_material(0)
	
	# Create curved world shader material
	var curved_mat := ShaderMaterial.new()
	curved_mat.shader = _curved_shader
	
	# Transfer properties from original material
	if original_mat is StandardMaterial3D:
		var std_mat := original_mat as StandardMaterial3D
		curved_mat.set_shader_parameter("albedo", std_mat.albedo_color)
		curved_mat.set_shader_parameter("roughness", std_mat.roughness)
		curved_mat.set_shader_parameter("metallic", std_mat.metallic)
		if std_mat.albedo_texture:
			curved_mat.set_shader_parameter("albedo_texture", std_mat.albedo_texture)
	
	# Set curve parameters
	curved_mat.set_shader_parameter("curve_enabled", true)
	curved_mat.set_shader_parameter("curve_intensity", curve_intensity)
	curved_mat.set_shader_parameter("curve_mode", curve_mode)
	curved_mat.set_shader_parameter("curve_max_distance", curve_max_distance)
	# Note: curve_center will be set at runtime by the camera system
	curved_mat.set_shader_parameter("curve_center", Vector3.ZERO)
	
	mesh_instance.material_override = curved_mat

func _add_collision(node: Node3D, cell_size: Vector3) -> void:
	# Check if collision already exists
	for child in node.get_children():
		if child is CollisionShape3D or child is StaticBody3D:
			return
	
	var static_body := StaticBody3D.new()
	static_body.name = "Collision"
	
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = cell_size
	collision_shape.shape = box_shape
	
	static_body.add_child(collision_shape)
	node.add_child(static_body)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)

## Export only the geometry as a single merged mesh (for optimization)
func export_merged_geometry(output_path: String) -> Error:
	# TODO: Implement mesh merging for large levels
	push_warning("Merged geometry export not yet implemented")
	return export_level(output_path)

## Generate a curved world material with current settings
func create_curved_material(base_material: StandardMaterial3D = null) -> ShaderMaterial:
	if not _curved_shader:
		push_error("Curved world shader not loaded")
		return null
	
	var mat := ShaderMaterial.new()
	mat.shader = _curved_shader
	
	if base_material:
		mat.set_shader_parameter("albedo", base_material.albedo_color)
		mat.set_shader_parameter("roughness", base_material.roughness)
		mat.set_shader_parameter("metallic", base_material.metallic)
		if base_material.albedo_texture:
			mat.set_shader_parameter("albedo_texture", base_material.albedo_texture)
	else:
		mat.set_shader_parameter("albedo", Color.WHITE)
		mat.set_shader_parameter("roughness", 0.5)
		mat.set_shader_parameter("metallic", 0.0)
	
	mat.set_shader_parameter("curve_enabled", true)
	mat.set_shader_parameter("curve_intensity", curve_intensity)
	mat.set_shader_parameter("curve_mode", curve_mode)
	mat.set_shader_parameter("curve_max_distance", curve_max_distance)
	mat.set_shader_parameter("curve_center", Vector3.ZERO)
	
	return mat
