extends Area3D
class_name XtremeTestWaterVolume

@export var surface_offset: float = 0.0


func _ready() -> void:
	add_to_group("water_zone")
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _get_surface_y() -> float:
	var surface_y := global_position.y + surface_offset
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision and collision.shape is BoxShape3D:
		var box := collision.shape as BoxShape3D
		surface_y = collision.global_position.y + box.size.y * 0.5 + surface_offset
	return surface_y


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		var player := body as PlayerController
		player.enter_water(self, _get_surface_y())


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		var player := body as PlayerController
		player.exit_water(self)
