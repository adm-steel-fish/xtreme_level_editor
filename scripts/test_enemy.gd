extends Area3D
class_name XtremeTestEnemy

## Simple test enemy that can be targeted and destroyed by homing attack

@export var health: int = 1
@export var bounce_velocity: float = 15.0

var _is_destroyed: bool = false


func _ready() -> void:
	# Add to targetable group so player can lock on
	add_to_group("enemies")
	add_to_group("targetable")
	
	# Connect body entered signal
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _is_destroyed:
		return
	
	# Check if it's the player
	if body is PlayerController:
		var player = body as PlayerController
		
		# Check if player is in homing attack or butt bounce
		if player.current_state == PlayerController.State.HOMING_ATTACK or \
		   player.current_state == PlayerController.State.BUTT_BOUNCE_DESCENDING:
			take_damage(1)


func take_damage(amount: int) -> void:
	health -= amount
	
	if health <= 0:
		destroy()
	else:
		# Flash red
		_flash()


func _flash() -> void:
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh and mesh is MeshInstance3D:
		var mat = mesh.get_surface_override_material(0)
		if mat:
			var original_color = mat.albedo_color
			mat.albedo_color = Color.WHITE
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(mesh):
				mat.albedo_color = original_color


func destroy() -> void:
	_is_destroyed = true
	
	# Simple destroy effect - scale down and remove
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(queue_free)
