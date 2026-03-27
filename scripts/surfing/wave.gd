extends Node3D
class_name XtremeWave
## A wave surface that moves through the surfing level.
## Players ride the wave face; wave type affects gameplay.

enum WaveType { SWELL, BARREL, MEGA }

@export_group("Wave")
@export var wave_type: WaveType = WaveType.SWELL
## How fast the wave moves forward (matches or slightly slower than player).
@export var wave_speed: float = 12.0
## Wave height at peak.
@export var wave_height: float = 4.0
## Wave width (lateral span).
@export var wave_width: float = 20.0
## How long the wave persists before despawning (seconds).
@export var lifetime: float = 30.0

@export_group("Barrel")
## Only for BARREL type: score multiplier while inside.
@export var barrel_score_multiplier: float = 2.0
## Barrel entry/exit detection area size.
@export var barrel_radius: float = 3.0

@export_group("Mega Wave")
## Only for MEGA type: extra height for set-piece jumps.
@export var mega_extra_height: float = 6.0
## Mega wave launch velocity bonus.
@export var mega_launch_bonus: float = 8.0

var _age: float = 0.0
var _barrel_area: Area3D
var _active: bool = true


func _ready() -> void:
	add_to_group("waves")

	if wave_type == WaveType.BARREL:
		_create_barrel_zone()
	elif wave_type == WaveType.MEGA:
		wave_height += mega_extra_height


func _process(delta: float) -> void:
	if not _active:
		return

	_age += delta

	# Move wave forward
	global_position.z -= wave_speed * delta

	# Despawn after lifetime
	if _age >= lifetime:
		_active = false
		queue_free()


## Get the wave height at a given lateral (X) position.
func get_height_at(x_pos: float) -> float:
	var local_x := x_pos - global_position.x
	var half_width := wave_width * 0.5

	if absf(local_x) > half_width:
		return 0.0

	# Cosine curve for wave shape
	var t := local_x / half_width
	return wave_height * cos(t * PI * 0.5) + global_position.y


## Get the wave's forward velocity for speed matching.
func get_wave_velocity() -> Vector3:
	return Vector3(0, 0, -wave_speed)


func _create_barrel_zone() -> void:
	_barrel_area = Area3D.new()
	_barrel_area.name = "BarrelZone"
	_barrel_area.monitoring = true
	_barrel_area.monitorable = false

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(barrel_radius * 2.0, barrel_radius * 2.0, barrel_radius * 2.0)
	shape.shape = box
	_barrel_area.add_child(shape)

	# Position barrel zone at the curl of the wave
	_barrel_area.position = Vector3(wave_width * 0.3, wave_height * 0.6, 0)

	_barrel_area.body_entered.connect(_on_barrel_entered)
	_barrel_area.body_exited.connect(_on_barrel_exited)
	add_child(_barrel_area)


func _on_barrel_entered(body: Node3D) -> void:
	if body is XtremeSurfboardController:
		(body as XtremeSurfboardController).enter_barrel()


func _on_barrel_exited(body: Node3D) -> void:
	if body is XtremeSurfboardController:
		(body as XtremeSurfboardController).exit_barrel()
