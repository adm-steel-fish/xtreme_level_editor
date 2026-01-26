extends Area3D
class_name XtremeTestCurrency

## Simple test currency (ring) for light dash testing
## Each ring is collected individually

@export var value: int = 1
@export var rotation_speed: float = 180.0

var _collected: bool = false
var _unique_material: StandardMaterial3D  # Each instance gets its own material

signal collected(currency: XtremeTestCurrency)


func _ready() -> void:
	# Add to currency group so player can light dash
	add_to_group("currency")
	
	# Connect body entered signal
	body_entered.connect(_on_body_entered)
	
	# IMPORTANT: Create a unique material for this ring instance
	# This prevents all rings from fading when one is collected
	_create_unique_material()


func _create_unique_material() -> void:
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh and mesh is MeshInstance3D:
		var original_mat = mesh.get_surface_override_material(0)
		if original_mat and original_mat is StandardMaterial3D:
			# Duplicate the material so each ring has its own
			_unique_material = original_mat.duplicate()
			mesh.set_surface_override_material(0, _unique_material)
		elif not original_mat:
			# Create a default gold material if none exists
			_unique_material = StandardMaterial3D.new()
			_unique_material.albedo_color = Color(1.0, 0.85, 0.1, 1.0)
			_unique_material.metallic = 0.8
			_unique_material.roughness = 0.2
			_unique_material.emission_enabled = true
			_unique_material.emission = Color(1.0, 0.85, 0.1, 1.0)
			_unique_material.emission_energy_multiplier = 0.2
			mesh.set_surface_override_material(0, _unique_material)


func _process(delta: float) -> void:
	if _collected:
		return
	# Spin the ring
	rotate_y(deg_to_rad(rotation_speed * delta))


func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	
	# Check if it's the player
	if body is PlayerController:
		collect()


## Called by player controller during light dash or by collision
func collect() -> void:
	if _collected:
		return
	
	_collected = true
	collected.emit(self)
	
	# Disable collision immediately to prevent double-collection
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Simple collect effect - scale up and fade using our unique material
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 1.5, 0.15)
	
	# Fade out using our unique material
	if _unique_material:
		_unique_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tween.tween_property(_unique_material, "albedo_color:a", 0.0, 0.15)
	
	tween.chain().tween_callback(queue_free)
