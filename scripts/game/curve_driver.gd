extends Node
class_name XtremeCurveDriver
## Single source of truth for the curved-world "reflex lens".
##
## Pushes the curve parameters into Godot's global shader uniforms once per
## frame. Every shader that includes curved_world.gdshaderinc reads them, so
## level geometry, rings, rails, enemies, props and the player all bend by
## exactly the same amount — including anything spawned at runtime.
##
## This replaces the old approach in xtreme_camera.gd, which walked the scene
## tree hunting for ShaderMaterials with a `curve_center` parameter and pushed
## the value into each one. That could only ever reach materials already using
## the curved-world shader, which is why everything else stayed flat.

## Master switch. Turning this off flattens the whole world (useful for boss
## arenas, which the GDD specifies as non-curved Sonic Adventure-style stages).
@export var curve_enabled: bool = true:
	set(value):
		curve_enabled = value
		_push_static_params()

## 0 = spherical, 1 = cylindrical X, 2 = cylindrical Y
@export_enum("Spherical:0", "Cylindrical X:1", "Cylindrical Y:2")
var curve_mode: int = 0:
	set(value):
		curve_mode = value
		_push_static_params()

@export_group("Curve Strength")
@export_range(0.0, 0.3, 0.001) var curve_horizontal: float = 0.15:
	set(value):
		curve_horizontal = value
		_push_static_params()

@export_range(0.0, 0.3, 0.001) var curve_vertical: float = 0.08:
	set(value):
		curve_vertical = value
		_push_static_params()

@export_range(10.0, 1000.0) var curve_max_distance: float = 200.0:
	set(value):
		curve_max_distance = value
		_push_static_params()

@export_range(1.0, 4.0, 0.1) var curve_falloff_exponent: float = 2.0:
	set(value):
		curve_falloff_exponent = value
		_push_static_params()

@export_group("Curve Centre")
## Node the curve bends around. Leave empty to auto-find the player.
@export var target_path: NodePath

## Smoothing applied to the curve centre. 0 = snap instantly. A little
## smoothing stops the whole world from jittering when the player's position
## changes abruptly (respawn, rail exit).
@export_range(0.0, 30.0, 0.5) var follow_speed: float = 0.0

var _target: Node3D
var _center: Vector3 = Vector3.ZERO
var _has_center: bool = false


func _ready() -> void:
	# Run after the level's own _ready pass so the player exists.
	call_deferred("_resolve_target")
	_push_static_params()


func _resolve_target() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		var tree := get_tree()
		if tree:
			for node in tree.get_nodes_in_group("player"):
				if node is Node3D:
					_target = node as Node3D
					break
	if _target:
		_center = _target.global_position
		_has_center = true
		_push_center()


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var goal := _target.global_position
	if follow_speed > 0.0 and _has_center:
		_center = _center.lerp(goal, clampf(follow_speed * delta, 0.0, 1.0))
	else:
		_center = goal
	_has_center = true
	_push_center()


func _push_center() -> void:
	RenderingServer.global_shader_parameter_set(&"xtreme_curve_center", _center)


## Tuning values change rarely, so they are only pushed when they actually change.
func _push_static_params() -> void:
	RenderingServer.global_shader_parameter_set(&"xtreme_curve_enabled", curve_enabled)
	RenderingServer.global_shader_parameter_set(&"xtreme_curve_mode", curve_mode)
	RenderingServer.global_shader_parameter_set(&"xtreme_curve_horizontal", curve_horizontal)
	RenderingServer.global_shader_parameter_set(&"xtreme_curve_vertical", curve_vertical)
	RenderingServer.global_shader_parameter_set(&"xtreme_curve_max_distance", curve_max_distance)
	RenderingServer.global_shader_parameter_set(&"xtreme_curve_falloff_exponent", curve_falloff_exponent)


## Flatten the world (boss arenas, 2D sections, cutscenes).
func set_curve_enabled(enabled: bool) -> void:
	curve_enabled = enabled
