extends Area3D
class_name XtremePowerUp
## Collectible power-up item.  Applies its effect to the player on contact.

enum PowerUpType {
	FLAME_SHIELD,      ## Fire immunity + fireball dash
	ELECTRIC_SHIELD,   ## Electric immunity + magnet double jump + ring attract
	AQUA_SHIELD,       ## Underwater breathing + bounce
	SPEED_SHOES,       ## 1.5x speed for 15 seconds
	INVINCIBILITY      ## Invincible for 15 seconds, defeat enemies on contact
}

@export var powerup_type: PowerUpType = PowerUpType.FLAME_SHIELD
## Duration for timed power-ups (Speed Shoes / Invincibility).  0 = permanent.
@export var duration: float = 15.0
## Rotation speed in degrees per second.
@export var rotation_speed: float = 120.0
## Vertical bob amplitude.
@export var bob_amplitude: float = 0.3
## Vertical bob speed.
@export var bob_speed: float = 2.0

var _origin_y: float = 0.0
var _collected: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = false
	_origin_y = global_position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _collected:
		return
	rotation.y += deg_to_rad(rotation_speed) * delta
	global_position.y = _origin_y + sin(Time.get_ticks_msec() * 0.001 * bob_speed * TAU) * bob_amplitude


func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if not (body is PlayerController):
		return

	_collected = true
	var player := body as PlayerController
	_apply_to_player(player)
	queue_free()


func _apply_to_player(player: PlayerController) -> void:
	match powerup_type:
		PowerUpType.FLAME_SHIELD:
			player.apply_shield(PlayerController.ShieldType.FLAME)
		PowerUpType.ELECTRIC_SHIELD:
			player.apply_shield(PlayerController.ShieldType.ELECTRIC)
		PowerUpType.AQUA_SHIELD:
			player.apply_shield(PlayerController.ShieldType.AQUA)
		PowerUpType.SPEED_SHOES:
			player.apply_speed_shoes(duration)
		PowerUpType.INVINCIBILITY:
			player.apply_invincibility_powerup(duration)
