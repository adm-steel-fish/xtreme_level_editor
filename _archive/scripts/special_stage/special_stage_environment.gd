extends Node
class_name XtremeSpecialStageEnvironment
## Applies the "unfinished computer program" wireframe aesthetic to special stages.
## Overrides materials with flat-color wireframe, disables retro shader effects,
## sets ambient-only lighting, and creates a void background.

@export_group("Visual Style")
## Base wireframe color — each stage can use a unique hue.
@export var wireframe_color: Color = Color(0.0, 0.5, 1.0)
## Brightness of the wireframe lines.
@export_range(0.5, 3.0, 0.1) var wireframe_emission: float = 1.5
## Background void color.
@export var void_color: Color = Color(0.02, 0.02, 0.06)
## Accent color for collectibles and landmarks.
@export var accent_color: Color = Color(1.0, 0.8, 0.0)

@export_group("Stage Identity")
## Stage color palette index (1-8 matching crystal IDs).
@export var stage_id: int = 1

## Predefined stage palettes: blue, green, purple, orange, red, cyan, pink, gold.
const STAGE_PALETTES: Array[Dictionary] = [
	{"wire": Color(0.0, 0.4, 1.0), "void": Color(0.01, 0.01, 0.06), "accent": Color(1.0, 0.9, 0.2)},
	{"wire": Color(0.0, 0.9, 0.3), "void": Color(0.01, 0.04, 0.01), "accent": Color(0.8, 1.0, 0.3)},
	{"wire": Color(0.6, 0.2, 1.0), "void": Color(0.03, 0.01, 0.06), "accent": Color(1.0, 0.5, 0.9)},
	{"wire": Color(1.0, 0.5, 0.0), "void": Color(0.04, 0.02, 0.01), "accent": Color(1.0, 1.0, 0.4)},
	{"wire": Color(1.0, 0.15, 0.15), "void": Color(0.04, 0.01, 0.01), "accent": Color(1.0, 0.6, 0.2)},
	{"wire": Color(0.0, 0.9, 0.9), "void": Color(0.01, 0.04, 0.04), "accent": Color(0.5, 1.0, 1.0)},
	{"wire": Color(1.0, 0.3, 0.6), "void": Color(0.04, 0.01, 0.03), "accent": Color(1.0, 0.7, 0.8)},
	{"wire": Color(1.0, 0.85, 0.2), "void": Color(0.04, 0.03, 0.01), "accent": Color(1.0, 1.0, 0.6)},
]

var _original_materials: Array[Dictionary] = []  # [{mesh_instance, surface_idx, material}]
var _original_environment: Environment
var _applied: bool = false


func _ready() -> void:
	add_to_group("special_stage_environment")
	_apply_palette_from_id()


## Apply the wireframe aesthetic to the entire scene.
func apply_environment(scene_root: Node) -> void:
	if _applied:
		return
	_applied = true

	_apply_palette_from_id()
	_override_materials(scene_root)
	_override_environment(scene_root)
	_disable_retro_effects()
	_disable_shadows(scene_root)


## Restore all original materials and settings.
func restore_environment(scene_root: Node) -> void:
	if not _applied:
		return
	_applied = false

	_restore_materials()
	_restore_environment(scene_root)
	_enable_retro_effects()


func _apply_palette_from_id() -> void:
	var idx := clampi(stage_id - 1, 0, STAGE_PALETTES.size() - 1)
	var palette: Dictionary = STAGE_PALETTES[idx]
	wireframe_color = palette["wire"]
	void_color = palette["void"]
	accent_color = palette["accent"]


## Override all MeshInstance3D materials with wireframe + flat emission.
func _override_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var original := mi.get_surface_override_material(i)
			if not original:
				original = mi.mesh.surface_get_material(i) if mi.mesh else null
			_original_materials.append({
				"mesh_instance": mi,
				"surface_idx": i,
				"material": original,
			})
			mi.set_surface_override_material(i, _create_wireframe_material())

	for child in node.get_children():
		_override_materials(child)


func _create_wireframe_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = wireframe_color
	mat.emission_enabled = true
	mat.emission = wireframe_color
	mat.emission_energy_multiplier = wireframe_emission
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	# Wireframe rendering
	mat.wireframe = true
	return mat


## Override WorldEnvironment for void background.
func _override_environment(scene_root: Node) -> void:
	var world_env := _find_world_environment(scene_root)
	if not world_env:
		return

	_original_environment = world_env.environment

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = void_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = wireframe_color.lerp(Color.WHITE, 0.3)
	env.ambient_light_energy = 0.8

	# No fog in special stages — clean void look
	env.fog_enabled = false

	# No bloom, no glow — clean wireframe lines
	env.glow_enabled = false

	# No SSAO, SSR, SDFGI
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false

	world_env.environment = env


func _restore_materials() -> void:
	for entry in _original_materials:
		var mi: MeshInstance3D = entry["mesh_instance"]
		if is_instance_valid(mi):
			mi.set_surface_override_material(entry["surface_idx"], entry["material"])
	_original_materials.clear()


func _restore_environment(scene_root: Node) -> void:
	if not _original_environment:
		return
	var world_env := _find_world_environment(scene_root)
	if world_env:
		world_env.environment = _original_environment
	_original_environment = null


## Disable retro shader effects for clean wireframe look.
func _disable_retro_effects() -> void:
	var params := _get_retro_params()
	if not params:
		return
	if "retro_enabled" in params:
		params.retro_enabled = false


func _enable_retro_effects() -> void:
	var params := _get_retro_params()
	if not params:
		return
	if "retro_enabled" in params:
		params.retro_enabled = true


## Turn off all shadow casting for the flat wireframe look.
func _disable_shadows(node: Node) -> void:
	if node is Light3D:
		(node as Light3D).shadow_enabled = false
	if node is MeshInstance3D:
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)


func _find_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node as WorldEnvironment
	for child in node.get_children():
		var found := _find_world_environment(child)
		if found:
			return found
	return null


func _get_retro_params() -> Node:
	if Engine.has_singleton("RetroShaderParams"):
		return Engine.get_singleton("RetroShaderParams")
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("RetroShaderParams")
	return null
