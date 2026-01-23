extends Area3D
class_name XtremeTestCurrency

## Simple test currency (ring) for light dash testing

@export var value: int = 1
@export var rotation_speed: float = 180.0

var _collected: bool = false

signal collected(currency: XtremeTestCurrency)


func _ready() -> void:
	# Add to currency group so player can light dash
	add_to_group("currency")
	
	# Connect body entered signal
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# Spin the ring
	rotate_y(deg_to_rad(rotation_speed * delta))


func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	
	# Check if it's the player
	if body is PlayerController:
		collect()


## Called by player controller during light dash
func collect() -> void:
	if _collected:
		return
	
	_collected = true
	collected.emit(self)
	
	# Simple collect effect - scale up and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 1.5, 0.15)
	
	# Find mesh and fade it
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh:
		var mat = mesh.get_surface_override_material(0)
		if mat:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	
	tween.chain().tween_callback(queue_free)
