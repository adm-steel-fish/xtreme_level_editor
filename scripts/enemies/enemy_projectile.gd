extends Area3D
class_name XtremeEnemyProjectile
## Simple projectile fired by enemies.  Moves in a straight line and damages
## the player on contact.  Destroys itself after a timeout or on hit.

@export var speed: float = 12.0
@export var damage: int = 1
@export var lifetime: float = 5.0

var direction: Vector3 = Vector3.FORWARD
var _timer: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		var player := body as PlayerController
		if player.has_method("take_damage"):
			player.take_damage(self, damage)
	queue_free()
