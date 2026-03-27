extends CharacterBody3D
class_name XtremeSurfboardController
## Controls the player's surfboard in surfing stages.
## Auto-forward movement on waves, steer left/right, jump for tricks,
## shuvit dodge, ram attack, and stoke-powered turbo.

enum SurfState { RIDING, AIRBORNE, TRICKING, BARREL, WIPED_OUT }

#region Configuration
@export_group("Movement")
@export var base_speed: float = 15.0
@export var max_speed: float = 35.0
@export var steer_speed: float = 8.0
@export var steer_lerp: float = 8.0
@export var gravity: float = 30.0
@export var jump_force: float = 12.0

@export_group("Turbo")
@export var turbo_multiplier: float = 1.5
@export var turbo_min_stoke: float = 25.0

@export_group("Shuvit")
## Lateral dodge distance.
@export var shuvit_distance: float = 3.0
## Duration of the shuvit dodge.
@export var shuvit_duration: float = 0.3

@export_group("Stoke Meter")
@export var stoke_max: float = 100.0
@export var stoke_drain_turbo: float = 15.0
@export var stoke_trick_gain: float = 10.0
@export var stoke_barrel_gain: float = 2.0
@export var stoke_ring_gain: float = 1.0
@export var stoke_near_miss_gain: float = 3.0
@export var stoke_wipeout_loss: float = 50.0

@export_group("Rings & Health")
@export var starting_rings: int = 0
@export var wipeout_recovery_time: float = 1.5

@export_group("Audio")
@export var ride_sfx: AudioStream
@export var jump_sfx: AudioStream
@export var wipeout_sfx: AudioStream
@export var turbo_sfx: AudioStream
#endregion

#region State
var current_state: SurfState = SurfState.RIDING
var current_speed: float = 15.0
var stoke_meter: float = 0.0
var current_rings: int = 0
var is_turbo: bool = false
var combo_multiplier: float = 1.0

var _steer_input: float = 0.0
var _forward_dir: Vector3 = Vector3.FORWARD
var _wipeout_timer: float = 0.0
var _shuvit_timer: float = 0.0
var _shuvit_dir: float = 0.0
var _is_shuvit: bool = false
var _air_time: float = 0.0
var _on_wave: bool = false
#endregion

#region Signals
signal state_changed(new_state: SurfState)
signal stoke_changed(current: float)
signal rings_changed(current: int)
signal speed_changed(current: float)
signal tricked(trick_name: String, score: int)
signal wiped_out()
signal combo_changed(multiplier: float)
signal finished_stage(success: bool)
#endregion


func _ready() -> void:
	add_to_group("player")
	add_to_group("surfboard")
	current_rings = starting_rings
	current_speed = base_speed


func _physics_process(delta: float) -> void:
	match current_state:
		SurfState.RIDING:
			_process_riding(delta)
		SurfState.AIRBORNE, SurfState.TRICKING:
			_process_airborne(delta)
		SurfState.BARREL:
			_process_barrel(delta)
		SurfState.WIPED_OUT:
			_process_wipeout(delta)

	_process_shuvit(delta)
	_process_turbo(delta)
	move_and_slide()


#region Riding
func _process_riding(delta: float) -> void:
	_gather_input()

	# Auto-forward
	var target_speed := base_speed
	if is_turbo:
		target_speed = minf(max_speed, base_speed * turbo_multiplier)
	current_speed = lerpf(current_speed, target_speed, 2.0 * delta)

	# Steer
	velocity.x = lerpf(velocity.x, _steer_input * steer_speed, steer_lerp * delta)

	# Forward movement
	velocity.z = -current_speed

	# Gravity (stick to wave surface)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
		_air_time = 0.0

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
		_change_state(SurfState.AIRBORNE)

	speed_changed.emit(current_speed)


func _process_airborne(delta: float) -> void:
	_gather_input()
	_air_time += delta

	# Reduced air steer
	velocity.x = lerpf(velocity.x, _steer_input * steer_speed * 0.5, steer_lerp * delta)
	velocity.z = -current_speed

	# Gravity
	velocity.y -= gravity * delta

	# Land
	if is_on_floor() and velocity.y <= 0.0:
		_on_landing()


func _process_barrel(delta: float) -> void:
	_gather_input()

	# Same as riding but gain stoke
	velocity.x = lerpf(velocity.x, _steer_input * steer_speed * 0.7, steer_lerp * delta)
	velocity.z = -current_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	add_stoke(stoke_barrel_gain * delta)

	# Jump out of barrel
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
		_change_state(SurfState.AIRBORNE)
#endregion


#region Wipeout
func _process_wipeout(delta: float) -> void:
	# Slow to a stop
	velocity = velocity.lerp(Vector3.ZERO, 3.0 * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta

	_wipeout_timer -= delta
	if _wipeout_timer <= 0.0:
		_change_state(SurfState.RIDING)
		current_speed = base_speed


func wipeout() -> void:
	if current_state == SurfState.WIPED_OUT:
		return

	# Lose all rings (not recoverable in surfing)
	current_rings = 0
	rings_changed.emit(current_rings)

	stoke_meter = maxf(stoke_meter - stoke_wipeout_loss, 0.0)
	stoke_changed.emit(stoke_meter)

	_wipeout_timer = wipeout_recovery_time
	combo_multiplier = 1.0
	combo_changed.emit(combo_multiplier)
	is_turbo = false

	_change_state(SurfState.WIPED_OUT)
	wiped_out.emit()
#endregion


#region Shuvit
func _process_shuvit(delta: float) -> void:
	if not _is_shuvit:
		return
	_shuvit_timer -= delta
	# Quick lateral slide
	velocity.x = _shuvit_dir * (shuvit_distance / shuvit_duration)
	if _shuvit_timer <= 0.0:
		_is_shuvit = false


func shuvit(direction: float) -> void:
	if _is_shuvit or current_state == SurfState.WIPED_OUT:
		return
	_is_shuvit = true
	_shuvit_dir = signf(direction)
	_shuvit_timer = shuvit_duration
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
	if stoke_meter < turbo_min_stoke or current_state == SurfState.WIPED_OUT:
		return
	is_turbo = true


func stop_turbo() -> void:
	is_turbo = false


func add_stoke(amount: float) -> void:
	stoke_meter = clampf(stoke_meter + amount, 0.0, stoke_max)
	stoke_changed.emit(stoke_meter)
#endregion


#region Rings
func add_rings(amount: int) -> void:
	current_rings += amount
	rings_changed.emit(current_rings)
	add_stoke(stoke_ring_gain * float(amount))


func take_damage() -> void:
	if current_rings > 0:
		current_rings = 0
		rings_changed.emit(current_rings)
	else:
		wipeout()
#endregion


#region Landing & Tricks
func _on_landing() -> void:
	if current_state == SurfState.TRICKING:
		# Trick system handles scoring via signal
		_air_time = 0.0
		_change_state(SurfState.RIDING)
	elif current_state == SurfState.AIRBORNE:
		_air_time = 0.0
		_change_state(SurfState.RIDING)


## Called by trick system when a trick is completed in air.
func register_trick(trick_name: String, score: int) -> void:
	var final_score := int(float(score) * combo_multiplier)
	add_stoke(stoke_trick_gain)
	tricked.emit(trick_name, final_score)
	if current_state == SurfState.AIRBORNE:
		_change_state(SurfState.TRICKING)
#endregion


#region Barrel
func enter_barrel() -> void:
	if current_state == SurfState.WIPED_OUT:
		return
	_on_wave = true
	if current_state == SurfState.RIDING:
		_change_state(SurfState.BARREL)


func exit_barrel() -> void:
	_on_wave = false
	if current_state == SurfState.BARREL:
		_change_state(SurfState.RIDING)
#endregion


#region Input
func _gather_input() -> void:
	_steer_input = Input.get_axis("move_left", "move_right")

	# Shuvit on dodge input
	if Input.is_action_just_pressed("move_left") and Input.is_action_pressed("move_left"):
		if absf(_steer_input) > 0.8:
			shuvit(_steer_input)

	# Turbo toggle
	if Input.is_action_just_pressed("boost"):
		start_turbo()
	elif Input.is_action_just_released("boost"):
		stop_turbo()
#endregion


func _change_state(new_state: SurfState) -> void:
	current_state = new_state
	state_changed.emit(new_state)
