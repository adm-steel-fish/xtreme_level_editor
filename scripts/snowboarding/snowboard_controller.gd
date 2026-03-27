extends CharacterBody3D
class_name XtremeSnowboardController
## Controls the player's snowboard in downhill snowboarding stages.
## Auto-acceleration based on slope angle, terrain effects, trick system,
## tuck/brake controls, and carving turns.

enum SnowState { RIDING, AIRBORNE, TRICKING, CRASHED }
enum TerrainType { PACKED_SNOW, POWDER, ICE, MOGULS }

#region Configuration
@export_group("Speed")
@export var base_speed: float = 20.0
@export var max_speed: float = 50.0
@export var slope_acceleration: float = 15.0
@export var flat_deceleration: float = 5.0
@export var gravity: float = 30.0
@export var jump_force: float = 10.0

@export_group("Controls")
## Speed bonus when tucking (crouching).
@export var tuck_speed_bonus: float = 0.2
## Speed penalty when braking.
@export var brake_speed_penalty: float = 0.3
## Steer responsiveness.
@export var steer_speed: float = 10.0
@export var steer_lerp: float = 6.0
## Carve turn: maintain speed through hard turns.
@export var carve_speed_retention: float = 0.95

@export_group("Terrain")
@export var powder_speed_penalty: float = 0.2
@export var ice_speed_bonus: float = 0.15
@export var ice_control_penalty: float = 0.5
@export var mogul_bounce_force: float = 4.0

@export_group("Ram Attack")
@export var ram_speed_threshold: float = 25.0
@export var ram_damage: int = 1
@export var ram_knockback: float = 8.0

@export_group("Rings & Health")
@export var starting_rings: int = 0
@export var crash_ring_loss: int = 10
@export var crash_recovery_time: float = 1.5

@export_group("Stoke")
@export var stoke_max: float = 100.0
@export var stoke_drain_turbo: float = 15.0
@export var stoke_trick_gain: float = 10.0
@export var stoke_wipeout_loss: float = 50.0
@export var turbo_min_stoke: float = 25.0
@export var turbo_multiplier: float = 1.4
#endregion

#region State
var current_state: SnowState = SnowState.RIDING
var current_speed: float = 20.0
var current_terrain: TerrainType = TerrainType.PACKED_SNOW
var stoke_meter: float = 0.0
var current_rings: int = 0
var is_tucking: bool = false
var is_braking: bool = false
var is_turbo: bool = false
var combo_multiplier: float = 1.0

var _steer_input: float = 0.0
var _slope_angle: float = 0.0
var _crash_timer: float = 0.0
var _air_time: float = 0.0
var _floor_normal: Vector3 = Vector3.UP
#endregion

#region Signals
signal state_changed(new_state: SnowState)
signal speed_changed(current: float)
signal stoke_changed(current: float)
signal rings_changed(current: int)
signal terrain_changed(terrain: TerrainType)
signal crashed()
signal combo_changed(multiplier: float)
signal finished_stage(success: bool)
#endregion


func _ready() -> void:
	add_to_group("player")
	add_to_group("snowboard")
	current_rings = starting_rings
	current_speed = base_speed


func _physics_process(delta: float) -> void:
	match current_state:
		SnowState.RIDING:
			_process_riding(delta)
		SnowState.AIRBORNE, SnowState.TRICKING:
			_process_airborne(delta)
		SnowState.CRASHED:
			_process_crashed(delta)

	_process_turbo(delta)
	move_and_slide()

	if is_on_floor():
		_floor_normal = get_floor_normal()
		_detect_terrain()


#region Riding
func _process_riding(delta: float) -> void:
	_gather_input()

	# Calculate slope angle for acceleration
	if is_on_floor():
		_slope_angle = _floor_normal.angle_to(Vector3.UP)
		var slope_factor := sin(_slope_angle)

		# Accelerate on slopes, decelerate on flats
		if slope_factor > 0.05:
			current_speed += slope_acceleration * slope_factor * delta
		else:
			current_speed -= flat_deceleration * delta

	# Apply terrain modifiers
	var speed_mod := 1.0
	var control_mod := 1.0
	match current_terrain:
		TerrainType.POWDER:
			speed_mod -= powder_speed_penalty
		TerrainType.ICE:
			speed_mod += ice_speed_bonus
			control_mod -= ice_control_penalty
		TerrainType.MOGULS:
			if is_on_floor() and randf() < 0.02:
				velocity.y += mogul_bounce_force

	# Tuck/brake modifiers
	if is_tucking:
		speed_mod += tuck_speed_bonus
		control_mod *= 0.7
	elif is_braking:
		speed_mod -= brake_speed_penalty
		control_mod *= 1.3

	# Turbo
	if is_turbo:
		speed_mod *= turbo_multiplier

	current_speed = clampf(current_speed * speed_mod, 0.0, max_speed)

	# Steer with control modifier
	var effective_steer := _steer_input * steer_speed * control_mod
	velocity.x = lerpf(velocity.x, effective_steer, steer_lerp * delta)

	# Carve: hard steer at speed retains more momentum
	if absf(_steer_input) > 0.7 and current_speed > base_speed:
		current_speed *= carve_speed_retention

	# Forward
	velocity.z = -current_speed

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
		_air_time = 0.0

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
		_change_state(SnowState.AIRBORNE)

	speed_changed.emit(current_speed)


func _process_airborne(delta: float) -> void:
	_gather_input()
	_air_time += delta

	velocity.x = lerpf(velocity.x, _steer_input * steer_speed * 0.4, steer_lerp * delta)
	velocity.z = -current_speed
	velocity.y -= gravity * delta

	if is_on_floor() and velocity.y <= 0.0:
		_on_landing()
#endregion


#region Crash
func _process_crashed(delta: float) -> void:
	velocity = velocity.lerp(Vector3.ZERO, 4.0 * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta

	_crash_timer -= delta
	if _crash_timer <= 0.0:
		_change_state(SnowState.RIDING)
		current_speed = base_speed


func crash() -> void:
	if current_state == SnowState.CRASHED:
		return

	current_rings = maxi(current_rings - crash_ring_loss, 0)
	rings_changed.emit(current_rings)

	stoke_meter = maxf(stoke_meter - stoke_wipeout_loss, 0.0)
	stoke_changed.emit(stoke_meter)

	combo_multiplier = 1.0
	combo_changed.emit(combo_multiplier)
	is_turbo = false
	is_tucking = false
	is_braking = false

	_crash_timer = crash_recovery_time
	_change_state(SnowState.CRASHED)
	crashed.emit()
#endregion


#region Turbo & Stoke
func _process_turbo(delta: float) -> void:
	if not is_turbo:
		return
	stoke_meter -= stoke_drain_turbo * delta
	stoke_changed.emit(stoke_meter)
	if stoke_meter <= 0.0:
		stoke_meter = 0.0
		is_turbo = false


func start_turbo() -> void:
	if stoke_meter < turbo_min_stoke or current_state == SnowState.CRASHED:
		return
	is_turbo = true


func stop_turbo() -> void:
	is_turbo = false


func add_stoke(amount: float) -> void:
	stoke_meter = clampf(stoke_meter + amount, 0.0, stoke_max)
	stoke_changed.emit(stoke_meter)
#endregion


#region Terrain Detection
func _detect_terrain() -> void:
	# Check floor body for terrain groups
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if not collider:
			continue

		var new_terrain := TerrainType.PACKED_SNOW
		if collider.is_in_group("terrain_powder"):
			new_terrain = TerrainType.POWDER
		elif collider.is_in_group("terrain_ice"):
			new_terrain = TerrainType.ICE
		elif collider.is_in_group("terrain_moguls"):
			new_terrain = TerrainType.MOGULS

		if new_terrain != current_terrain:
			current_terrain = new_terrain
			terrain_changed.emit(current_terrain)
		break
#endregion


#region Rings
func add_rings(amount: int) -> void:
	current_rings += amount
	rings_changed.emit(current_rings)


func take_damage(_source: Node3D = null) -> void:
	if current_rings > 0:
		current_rings = maxi(current_rings - crash_ring_loss, 0)
		rings_changed.emit(current_rings)
	else:
		crash()
#endregion


#region Ram Attack
## Check if the player can ram (high speed contact damage).
func can_ram() -> bool:
	return current_speed >= ram_speed_threshold and current_state == SnowState.RIDING


func get_ram_damage() -> int:
	return ram_damage


func get_ram_knockback() -> Vector3:
	return velocity.normalized() * ram_knockback
#endregion


#region Landing
func _on_landing() -> void:
	_air_time = 0.0
	_change_state(SnowState.RIDING)


func register_trick(trick_name: String, score: int) -> void:
	add_stoke(stoke_trick_gain)
	if current_state == SnowState.AIRBORNE:
		_change_state(SnowState.TRICKING)
#endregion


#region Input
func _gather_input() -> void:
	_steer_input = Input.get_axis("move_left", "move_right")
	is_tucking = Input.is_action_pressed("move_up")
	is_braking = Input.is_action_pressed("move_down")

	if Input.is_action_just_pressed("boost"):
		start_turbo()
	elif Input.is_action_just_released("boost"):
		stop_turbo()
#endregion


func _change_state(new_state: SnowState) -> void:
	current_state = new_state
	state_changed.emit(new_state)
