extends CharacterBody3D
class_name PlayerController

## Player Controller for 3D Platformer
## Inspired by Sonic X-treme with Sonic Adventure elements
## 
## Two-button control scheme: Jump (Space) and Action (CTRL)
## All speeds and timings are exposed for editor tuning

#region Enums
enum State {
	# Grounded states
	IDLE,
	MOVING,
	SPIN_DASH_CHARGE,
	ROLLING,
	
	# Airborne states
	AIRBORNE,
	AIR_ROLLING,
	HOMING_ATTACK,
	BUTT_BOUNCE_DESCENDING,
	BUTT_BOUNCE_REBOUNDING,
	
	# Wall states
	WALL_HUG,
	WALL_JUMP,
	
	# Special states
	LIGHT_DASH,
	HURT
}
#endregion

#region Exported Variables - Movement
@export_group("Movement - Ground")
## Maximum walking/running speed (left/right relative to camera)
@export var max_speed_horizontal: float = 14.0
## Maximum walking/running speed (forward/back relative to camera)
@export var max_speed_depth: float = 10.0
## Ground acceleration
@export var ground_acceleration: float = 40.0
## Ground deceleration (friction when no input)
@export var ground_deceleration: float = 30.0
## Ground deceleration while actively braking (opposite input)
@export var ground_brake_deceleration: float = 60.0

@export_group("Movement - Air")
## Air control acceleration (how much you can influence direction mid-air)
@export var air_acceleration: float = 20.0
## Air deceleration
@export var air_deceleration: float = 5.0
## Gravity strength
@export var gravity: float = 40.0
## Terminal velocity (max fall speed)
@export var terminal_velocity: float = 50.0

@export_group("Movement - Slopes")
## Maximum slope angle the player can climb (degrees)
@export var max_slope_angle: float = 70.0
## Slope acceleration factor (how much downhill speeds you up)
@export var slope_acceleration_factor: float = 15.0
## Slope deceleration factor (how much uphill slows you down)
@export var slope_deceleration_factor: float = 20.0
#endregion

#region Exported Variables - Jumping
@export_group("Jumping")
## Initial jump velocity
@export var jump_velocity: float = 15.0
## Double jump velocity
@export var double_jump_velocity: float = 12.0
## Jump buffer time (allows pressing jump slightly before landing)
@export var jump_buffer_time: float = 0.1
## Coyote time (allows jumping shortly after leaving ground)
@export var coyote_time: float = 0.15
#endregion

#region Exported Variables - Spin Dash & Rolling
@export_group("Spin Dash & Rolling")
## Minimum spin dash speed (tap and release)
@export var spin_dash_min_speed: float = 15.0
## Maximum spin dash speed (fully charged)
@export var spin_dash_max_speed: float = 35.0
## Time to fully charge spin dash (seconds)
@export var spin_dash_charge_time: float = 1.5
## Speed boost when initiating roll attack while moving
@export var roll_attack_boost: float = 5.0
## Rolling deceleration on flat ground
@export var roll_deceleration: float = 8.0
## Rolling minimum speed (below this, exit roll)
@export var roll_min_speed: float = 2.0
## Time before roll automatically stops (seconds)
@export var roll_auto_stop_time: float = 3.0
#endregion

#region Exported Variables - Homing Attack
@export_group("Homing Attack")
## Maximum distance to detect targets
@export var homing_range: float = 20.0
## Cone angle for target detection (degrees from camera forward)
@export var homing_cone_angle: float = 45.0
## Speed of homing attack
@export var homing_attack_speed: float = 30.0
## Maximum duration before homing attack cancels (seconds)
@export var homing_attack_timeout: float = 1.0
#endregion

#region Exported Variables - Butt Bounce
@export_group("Butt Bounce")
## Downward speed during butt bounce
@export var butt_bounce_speed: float = 25.0
## Rebound height (as velocity) for normal bounce
@export var butt_bounce_rebound_velocity: float = 15.0
## Rebound height (as velocity) for powered bounce
@export var butt_bounce_powered_rebound_velocity: float = 20.0
## Shockwave radius for powered bounce
@export var shockwave_radius: float = 5.0
## Number of bounces before powered bounce triggers
@export var powered_bounce_count: int = 3
#endregion

#region Exported Variables - Wall Mechanics
@export_group("Wall Mechanics")
## How long player can hug wall before falling (seconds)
@export var wall_hug_duration: float = 3.0
## Wall jump horizontal velocity (away from wall)
@export var wall_jump_horizontal_velocity: float = 10.0
## Wall jump vertical velocity
@export var wall_jump_vertical_velocity: float = 12.0
## Delay after wall jump before air jump is available (seconds)
@export var wall_jump_air_jump_delay: float = 3.0
## Max angle deviation from perfectly vertical for wall hug (degrees)
@export var wall_vertical_tolerance: float = 5.0
#endregion

#region Exported Variables - Light Dash
@export_group("Light Dash")
## Detection range for currency trail
@export var light_dash_detection_range: float = 5.0
## Speed during light dash
@export var light_dash_speed: float = 40.0
#endregion

#region Exported Variables - Hurt State
@export_group("Hurt State")
## Knockback velocity
@export var hurt_knockback_velocity: float = 8.0
## Invincibility frame duration (seconds)
@export var invincibility_duration: float = 2.0
#endregion

#region Exported Variables - References
@export_group("Node References")
## Reference to the camera (needed for input direction relative to camera view)
@export var camera: Camera3D
## Reference to the homing reticle UI element
@export var homing_reticle: Control
## Reference to the player's visual mesh/model
@export var player_model: Node3D
#endregion

#region State Variables
var current_state: State = State.IDLE
var previous_state: State = State.IDLE

# Grounded tracking
var is_grounded: bool = false
var was_grounded: bool = false
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Air jump
var air_jump_available: bool = false
var wall_jump_air_jump_timer: float = 0.0

# Spin dash
var spin_dash_charge_timer: float = 0.0
var spin_dash_direction: Vector3 = Vector3.ZERO

# Rolling
var roll_timer: float = 0.0

# Homing attack
var homing_target: Node3D = null
var homing_attack_timer: float = 0.0

# Butt bounce
var consecutive_bounces: int = 0
var is_at_bounce_apex: bool = false
var bounce_apex_velocity_threshold: float = 1.0

# Wall mechanics
var wall_hug_timer: float = 0.0
var wall_normal: Vector3 = Vector3.ZERO
var is_wall_hugging: bool = false

# Light dash
var light_dash_path: Array[Node3D] = []
var light_dash_index: int = 0

# Hurt state
var invincibility_timer: float = 0.0
var is_invincible: bool = false

# Input
var input_direction: Vector2 = Vector2.ZERO
var world_input_direction: Vector3 = Vector3.ZERO
var jump_pressed: bool = false
var jump_just_pressed: bool = false
var action_pressed: bool = false
var action_just_pressed: bool = false
var action_just_released: bool = false

# Slope
var floor_normal: Vector3 = Vector3.UP
var floor_angle: float = 0.0
#endregion

#region Signals
signal state_changed(new_state: State, old_state: State)
signal jumped()
signal double_jumped()
signal homing_attack_started(target: Node3D)
signal homing_attack_hit(target: Node3D)
signal butt_bounce_landed(is_powered: bool)
signal shockwave_triggered(position: Vector3, radius: float)
signal wall_hug_started()
signal wall_jump_performed()
signal light_dash_started()
signal light_dash_ended()
signal hurt(damage_source: Node3D)
signal rings_lost(amount: int)
#endregion


func _ready() -> void:
	# Set up floor detection
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_snap_length = 0.5
	
	# Initialize state
	_change_state(State.IDLE)
	
	# Hide reticle initially
	if homing_reticle:
		homing_reticle.visible = false


func _physics_process(delta: float) -> void:
	_gather_input()
	_update_grounded_status()
	_update_timers(delta)
	_update_invincibility(delta)
	
	# Process current state
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.MOVING:
			_process_moving(delta)
		State.SPIN_DASH_CHARGE:
			_process_spin_dash_charge(delta)
		State.ROLLING:
			_process_rolling(delta)
		State.AIRBORNE:
			_process_airborne(delta)
		State.AIR_ROLLING:
			_process_air_rolling(delta)
		State.HOMING_ATTACK:
			_process_homing_attack(delta)
		State.BUTT_BOUNCE_DESCENDING:
			_process_butt_bounce_descending(delta)
		State.BUTT_BOUNCE_REBOUNDING:
			_process_butt_bounce_rebounding(delta)
		State.WALL_HUG:
			_process_wall_hug(delta)
		State.WALL_JUMP:
			_process_wall_jump(delta)
		State.LIGHT_DASH:
			_process_light_dash(delta)
		State.HURT:
			_process_hurt(delta)
	
	# Update homing reticle
	_update_homing_reticle()
	
	# Apply movement
	move_and_slide()


#region Input Handling
func _gather_input() -> void:
	# Get raw input
	input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Convert to world direction based on camera
	world_input_direction = _get_world_input_direction(input_direction)
	
	# Button states
	jump_just_pressed = Input.is_action_just_pressed("jump")
	jump_pressed = Input.is_action_pressed("jump")
	action_just_pressed = Input.is_action_just_pressed("action")
	action_pressed = Input.is_action_pressed("action")
	action_just_released = Input.is_action_just_released("action")
	
	# Jump buffer
	if jump_just_pressed:
		jump_buffer_timer = jump_buffer_time


func _get_world_input_direction(input: Vector2) -> Vector3:
	if not camera:
		# Fallback if no camera assigned
		return Vector3(input.x, 0, input.y).normalized()
	
	# Get camera's forward and right vectors (flattened to horizontal plane)
	var cam_forward = -camera.global_transform.basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()
	
	var cam_right = camera.global_transform.basis.x
	cam_right.y = 0
	cam_right = cam_right.normalized()
	
	# Combine based on input
	var direction = (cam_right * input.x + cam_forward * -input.y).normalized()
	return direction if direction.length() > 0.1 else Vector3.ZERO
#endregion


#region Grounded & Floor Detection
func _update_grounded_status() -> void:
	was_grounded = is_grounded
	is_grounded = is_on_floor()
	
	if is_grounded:
		floor_normal = get_floor_normal()
		floor_angle = rad_to_deg(acos(floor_normal.dot(Vector3.UP)))
		coyote_timer = coyote_time
		
		# Reset air jump when landing
		air_jump_available = true
		wall_jump_air_jump_timer = 0.0
	else:
		floor_normal = Vector3.UP
		floor_angle = 0.0
		
		# Coyote time - allow air jump briefly after leaving ground
		if was_grounded and coyote_timer > 0:
			air_jump_available = true


func _update_timers(delta: float) -> void:
	# Coyote time
	if coyote_timer > 0:
		coyote_timer -= delta
	
	# Jump buffer
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	# Wall jump air jump delay
	if wall_jump_air_jump_timer > 0:
		wall_jump_air_jump_timer -= delta
		if wall_jump_air_jump_timer <= 0:
			air_jump_available = true


func _update_invincibility(delta: float) -> void:
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			# Could add visual feedback here (stop flashing, etc.)
#endregion


#region State Management
func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return
	
	previous_state = current_state
	
	# Exit current state
	_exit_state(current_state)
	
	# Enter new state
	current_state = new_state
	_enter_state(new_state)
	
	state_changed.emit(new_state, previous_state)


func _exit_state(state: State) -> void:
	match state:
		State.SPIN_DASH_CHARGE:
			spin_dash_charge_timer = 0.0
		State.ROLLING:
			roll_timer = 0.0
		State.HOMING_ATTACK:
			homing_attack_timer = 0.0
		State.WALL_HUG:
			wall_hug_timer = 0.0
			is_wall_hugging = false
		State.BUTT_BOUNCE_REBOUNDING:
			# Don't reset bounces here - only reset when landing normally
			pass


func _enter_state(state: State) -> void:
	match state:
		State.IDLE:
			consecutive_bounces = 0
		State.MOVING:
			consecutive_bounces = 0
		State.SPIN_DASH_CHARGE:
			spin_dash_charge_timer = 0.0
		State.ROLLING:
			roll_timer = 0.0
		State.AIRBORNE:
			pass
		State.HOMING_ATTACK:
			homing_attack_timer = 0.0
			homing_attack_started.emit(homing_target)
		State.BUTT_BOUNCE_DESCENDING:
			velocity.y = -butt_bounce_speed
			velocity.x = 0
			velocity.z = 0
		State.WALL_HUG:
			wall_hug_timer = wall_hug_duration
			velocity = Vector3.ZERO
			is_wall_hugging = true
			wall_hug_started.emit()
		State.WALL_JUMP:
			wall_jump_air_jump_timer = wall_jump_air_jump_delay
			air_jump_available = false
			wall_jump_performed.emit()
		State.LIGHT_DASH:
			light_dash_started.emit()
#endregion


#region State Processing - Grounded States
func _process_idle(delta: float) -> void:
	# Apply gravity if not grounded (shouldn't happen often in idle)
	if not is_grounded:
		_change_state(State.AIRBORNE)
		return
	
	# Check for Light Dash (highest priority)
	if action_just_pressed and _check_light_dash():
		return
	
	# Check for Spin Dash charge
	if action_pressed and world_input_direction.length() > 0.1:
		spin_dash_direction = world_input_direction
		_change_state(State.SPIN_DASH_CHARGE)
		return
	
	# Check for jump (including jump buffer)
	if jump_just_pressed or jump_buffer_timer > 0:
		_perform_jump()
		return
	
	# Check for movement
	if world_input_direction.length() > 0.1:
		_change_state(State.MOVING)
		return
	
	# Apply deceleration
	_apply_ground_friction(delta)


func _process_moving(delta: float) -> void:
	if not is_grounded:
		_change_state(State.AIRBORNE)
		return
	
	# Check for Light Dash (highest priority)
	if action_just_pressed and _check_light_dash():
		return
	
	# Check for Roll Attack
	if action_just_pressed:
		_start_roll_attack()
		return
	
	# Check for jump
	if jump_just_pressed or jump_buffer_timer > 0:
		_perform_jump()
		return
	
	# Check for return to idle
	if world_input_direction.length() < 0.1:
		_change_state(State.IDLE)
		return
	
	# Apply movement
	_apply_ground_movement(delta)


func _process_spin_dash_charge(delta: float) -> void:
	if not is_grounded:
		_change_state(State.AIRBORNE)
		return
	
	# Update charge timer
	spin_dash_charge_timer += delta
	spin_dash_charge_timer = minf(spin_dash_charge_timer, spin_dash_charge_time)
	
	# Update direction while charging
	if world_input_direction.length() > 0.1:
		spin_dash_direction = world_input_direction
	
	# Release to dash
	if action_just_released:
		_release_spin_dash()
		return
	
	# Cancel if no direction held
	if world_input_direction.length() < 0.1 and not action_pressed:
		_change_state(State.IDLE)
		return
	
	# Stay still while charging
	_apply_ground_friction(delta)


func _process_rolling(delta: float) -> void:
	roll_timer += delta
	
	# Check if we left the ground
	if not is_grounded:
		_change_state(State.AIR_ROLLING)
		return
	
	# Check for Light Dash (highest priority)
	if action_just_pressed and _check_light_dash():
		return
	
	# Check for jump while rolling
	if jump_just_pressed:
		_perform_jump()
		_change_state(State.AIRBORNE)
		return
	
	# Exit roll if holding forward direction (same direction as roll)
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	if horizontal_velocity.length() > 0.1 and world_input_direction.length() > 0.1:
		var velocity_dir = horizontal_velocity.normalized()
		var input_dot = velocity_dir.dot(world_input_direction)
		if input_dot > 0.7:  # Holding roughly forward
			_change_state(State.MOVING)
			return
	
	# Auto-stop after time limit
	if roll_timer >= roll_auto_stop_time:
		_change_state(State.IDLE if horizontal_velocity.length() < roll_min_speed else State.MOVING)
		return
	
	# Exit roll if too slow
	if horizontal_velocity.length() < roll_min_speed:
		_change_state(State.IDLE)
		return
	
	# Apply rolling physics
	_apply_rolling_movement(delta)
#endregion


#region State Processing - Airborne States
func _process_airborne(delta: float) -> void:
	# Check for landing
	if is_grounded:
		_on_land()
		return
	
	# Check for Light Dash (highest priority)
	if action_just_pressed and _check_light_dash():
		return
	
	# Check for wall hug
	if _check_wall_hug():
		return
	
	# Check for Butt Bounce
	if action_just_pressed:
		_change_state(State.BUTT_BOUNCE_DESCENDING)
		return
	
	# Check for Homing Attack or Double Jump
	if jump_just_pressed:
		if homing_target and _is_valid_homing_target(homing_target):
			_change_state(State.HOMING_ATTACK)
			return
		elif air_jump_available and wall_jump_air_jump_timer <= 0:
			_perform_double_jump()
			return
	
	# Apply air movement
	_apply_air_movement(delta)
	_apply_gravity(delta)


func _process_air_rolling(delta: float) -> void:
	# Check for landing
	if is_grounded:
		_on_land()
		return
	
	# Check for Light Dash (highest priority)
	if action_just_pressed and _check_light_dash():
		return
	
	# Check for jump while air rolling (exits roll)
	if jump_just_pressed and air_jump_available and wall_jump_air_jump_timer <= 0:
		_perform_double_jump()
		_change_state(State.AIRBORNE)
		return
	
	# Apply air movement (reduced control while rolling)
	_apply_air_movement(delta, 0.5)  # 50% air control while rolling
	_apply_gravity(delta)


func _process_homing_attack(delta: float) -> void:
	homing_attack_timer += delta
	
	# Timeout check
	if homing_attack_timer >= homing_attack_timeout:
		_change_state(State.AIRBORNE)
		return
	
	# Check if target is still valid
	if not homing_target or not is_instance_valid(homing_target):
		_change_state(State.AIRBORNE)
		return
	
	# Move toward target
	var direction = (homing_target.global_position - global_position).normalized()
	velocity = direction * homing_attack_speed
	
	# Check if we've reached the target (collision handled by signal from hitbox)
	var distance = global_position.distance_to(homing_target.global_position)
	if distance < 1.0:
		_on_homing_attack_hit()


func _process_butt_bounce_descending(delta: float) -> void:
	# Check for ground contact
	if is_grounded:
		_on_butt_bounce_land()
		return
	
	# Keep moving straight down
	velocity.x = 0
	velocity.z = 0
	velocity.y = -butt_bounce_speed


func _process_butt_bounce_rebounding(delta: float) -> void:
	# Check if we've reached apex
	if velocity.y <= bounce_apex_velocity_threshold:
		is_at_bounce_apex = true
	
	# At apex, allow actions
	if is_at_bounce_apex:
		# Check for Homing Attack
		if jump_just_pressed and homing_target and _is_valid_homing_target(homing_target):
			_change_state(State.HOMING_ATTACK)
			return
		# Check for Double Jump
		elif jump_just_pressed and air_jump_available:
			_perform_double_jump()
			_change_state(State.AIRBORNE)
			return
		# Check for another Butt Bounce
		elif action_just_pressed:
			_change_state(State.BUTT_BOUNCE_DESCENDING)
			return
	
	# Check for landing (shouldn't happen during rebound usually)
	if is_grounded:
		_on_land()
		return
	
	# Apply gravity during rebound
	_apply_gravity(delta)
	
	# Transition to airborne if we start falling
	if velocity.y < 0 and is_at_bounce_apex:
		_change_state(State.AIRBORNE)
#endregion


#region State Processing - Wall States
func _process_wall_hug(delta: float) -> void:
	wall_hug_timer -= delta
	
	# Fall off after duration
	if wall_hug_timer <= 0:
		_change_state(State.AIRBORNE)
		return
	
	# Check if still holding toward wall
	if world_input_direction.length() > 0.1:
		var toward_wall = -wall_normal
		var input_dot = world_input_direction.dot(toward_wall)
		if input_dot < 0.3:  # Not holding toward wall anymore
			_change_state(State.AIRBORNE)
			return
	else:
		# No input, fall off
		_change_state(State.AIRBORNE)
		return
	
	# Wall jump
	if jump_just_pressed:
		_perform_wall_jump()
		return
	
	# Stay in place
	velocity = Vector3.ZERO


func _process_wall_jump(delta: float) -> void:
	# Transition to airborne after initial wall jump velocity is applied
	# (Wall jump state is brief, just for the initial kick)
	
	# Check for wall hug on opposite wall
	if _check_wall_hug():
		return
	
	# Check for landing
	if is_grounded:
		_on_land()
		return
	
	# Apply air movement and gravity
	_apply_air_movement(delta)
	_apply_gravity(delta)
	
	# After a short time, transition to regular airborne
	# (The wall_jump_air_jump_timer handles the delay for air jump availability)
	if velocity.y < 0:
		_change_state(State.AIRBORNE)
#endregion


#region State Processing - Special States
func _process_light_dash(delta: float) -> void:
	if light_dash_path.is_empty() or light_dash_index >= light_dash_path.size():
		_end_light_dash()
		return
	
	var target = light_dash_path[light_dash_index]
	if not is_instance_valid(target):
		_end_light_dash()
		return
	
	var direction = (target.global_position - global_position).normalized()
	velocity = direction * light_dash_speed
	
	# Check if we've reached current target
	if global_position.distance_to(target.global_position) < 1.0:
		# Collect the currency (emit signal or call method on target)
		if target.has_method("collect"):
			target.collect()
		
		light_dash_index += 1
		
		# Check if path complete
		if light_dash_index >= light_dash_path.size():
			_end_light_dash()


func _process_hurt(delta: float) -> void:
	# Apply knockback deceleration
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	horizontal = horizontal.move_toward(Vector3.ZERO, ground_deceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	
	# Apply gravity
	_apply_gravity(delta)
	
	# Transition out of hurt state when grounded and velocity is low
	if is_grounded and horizontal.length() < 1.0:
		_change_state(State.IDLE)
#endregion


#region Movement Helpers
func _apply_ground_movement(delta: float) -> void:
	var target_velocity = Vector3.ZERO
	
	if world_input_direction.length() > 0.1:
		# Calculate target velocity with separate horizontal/depth speeds
		var input_horizontal = Vector3(world_input_direction.x, 0, 0)
		var input_depth = Vector3(0, 0, world_input_direction.z)
		
		target_velocity = input_horizontal.normalized() * max_speed_horizontal * abs(world_input_direction.x)
		target_velocity += input_depth.normalized() * max_speed_depth * abs(world_input_direction.z)
	
	# Apply slope influence
	if floor_angle > 1.0:
		var slope_direction = _get_slope_direction()
		var movement_dot = Vector3(velocity.x, 0, velocity.z).normalized().dot(slope_direction)
		
		if movement_dot > 0.1:  # Moving downhill
			target_velocity += slope_direction * slope_acceleration_factor
		elif movement_dot < -0.1:  # Moving uphill
			target_velocity -= slope_direction * slope_deceleration_factor
	
	# Smoothly accelerate toward target
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	horizontal = horizontal.move_toward(target_velocity, ground_acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _apply_ground_friction(delta: float) -> void:
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	horizontal = horizontal.move_toward(Vector3.ZERO, ground_deceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _apply_rolling_movement(delta: float) -> void:
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	
	# Apply slope influence (stronger while rolling)
	if floor_angle > 1.0:
		var slope_direction = _get_slope_direction()
		var movement_dot = horizontal.normalized().dot(slope_direction)
		
		if movement_dot > 0.1:  # Rolling downhill - accelerate
			horizontal += slope_direction * slope_acceleration_factor * 1.5 * delta
		elif movement_dot < -0.1:  # Rolling uphill - decelerate faster
			horizontal = horizontal.move_toward(Vector3.ZERO, slope_deceleration_factor * 2.0 * delta)
	
	# Apply rolling friction (less than walking friction)
	horizontal = horizontal.move_toward(Vector3.ZERO, roll_deceleration * delta)
	
	# Allow slight directional influence
	if world_input_direction.length() > 0.1:
		var influence = world_input_direction * ground_acceleration * 0.3 * delta
		horizontal += Vector3(influence.x, 0, influence.z)
	
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _apply_air_movement(delta: float, control_multiplier: float = 1.0) -> void:
	if world_input_direction.length() > 0.1:
		var horizontal = Vector3(velocity.x, 0, velocity.z)
		var target_direction = world_input_direction * air_acceleration * control_multiplier * delta
		horizontal += Vector3(target_direction.x, 0, target_direction.z)
		
		# Clamp to max air speed
		var max_air_speed = maxf(max_speed_horizontal, max_speed_depth)
		if horizontal.length() > max_air_speed:
			horizontal = horizontal.normalized() * max_air_speed
		
		velocity.x = horizontal.x
		velocity.z = horizontal.z


func _apply_gravity(delta: float) -> void:
	velocity.y -= gravity * delta
	velocity.y = maxf(velocity.y, -terminal_velocity)


func _get_slope_direction() -> Vector3:
	# Get the downhill direction on the current slope
	var slope_direction = Vector3(floor_normal.x, 0, floor_normal.z).normalized()
	return slope_direction
#endregion


#region Action Helpers
func _perform_jump() -> void:
	velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	jumped.emit()
	_change_state(State.AIRBORNE)


func _perform_double_jump() -> void:
	velocity.y = double_jump_velocity
	air_jump_available = false
	double_jumped.emit()


func _start_roll_attack() -> void:
	# Boost current velocity
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	if horizontal.length() > 0.1:
		horizontal = horizontal.normalized() * (horizontal.length() + roll_attack_boost)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	
	_change_state(State.ROLLING)


func _release_spin_dash() -> void:
	# Calculate dash speed based on charge time
	var charge_ratio = spin_dash_charge_timer / spin_dash_charge_time
	var dash_speed = lerpf(spin_dash_min_speed, spin_dash_max_speed, charge_ratio)
	
	velocity = spin_dash_direction * dash_speed
	_change_state(State.ROLLING)


func _perform_wall_jump() -> void:
	# Jump away from wall
	velocity = wall_normal * wall_jump_horizontal_velocity
	velocity.y = wall_jump_vertical_velocity
	_change_state(State.WALL_JUMP)


func _on_land() -> void:
	# Determine landing state based on velocity
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	
	if horizontal.length() > roll_min_speed and previous_state == State.AIR_ROLLING:
		_change_state(State.ROLLING)
	elif horizontal.length() > 0.5:
		_change_state(State.MOVING)
	else:
		_change_state(State.IDLE)


func _on_butt_bounce_land() -> void:
	consecutive_bounces += 1
	
	var is_powered = consecutive_bounces >= powered_bounce_count
	butt_bounce_landed.emit(is_powered)
	
	if is_powered:
		# Trigger shockwave
		shockwave_triggered.emit(global_position, shockwave_radius)
		velocity.y = butt_bounce_powered_rebound_velocity
		consecutive_bounces = 0  # Reset after powered bounce
	else:
		velocity.y = butt_bounce_rebound_velocity
	
	is_at_bounce_apex = false
	_change_state(State.BUTT_BOUNCE_REBOUNDING)


func _on_homing_attack_hit() -> void:
	homing_attack_hit.emit(homing_target)
	
	# Check if target is enemy (triggers powered bounce behavior)
	if homing_target.is_in_group("enemies") or homing_target.is_in_group("targetable"):
		# Bounce upward
		velocity.y = butt_bounce_powered_rebound_velocity
		
		# Trigger shockwave if it was an enemy
		if homing_target.is_in_group("enemies"):
			shockwave_triggered.emit(homing_target.global_position, shockwave_radius)
		
		is_at_bounce_apex = false
		_change_state(State.BUTT_BOUNCE_REBOUNDING)
	else:
		_change_state(State.AIRBORNE)
	
	homing_target = null
#endregion


#region Homing Attack Targeting
func _update_homing_reticle() -> void:
	# Only search for targets when airborne
	if not _is_airborne_state():
		homing_target = null
		if homing_reticle:
			homing_reticle.visible = false
		return
	
	# Find best target
	homing_target = _find_best_homing_target()
	
	# Update reticle
	if homing_reticle:
		if homing_target and is_instance_valid(homing_target):
			homing_reticle.visible = true
			# Position reticle over target (screen space)
			if camera:
				var screen_pos = camera.unproject_position(homing_target.global_position)
				homing_reticle.position = screen_pos - homing_reticle.size / 2
		else:
			homing_reticle.visible = false


func _find_best_homing_target() -> Node3D:
	if not camera:
		return null
	
	var targets = get_tree().get_nodes_in_group("targetable") + get_tree().get_nodes_in_group("enemies")
	var best_target: Node3D = null
	var best_score: float = -1.0
	
	var camera_forward = -camera.global_transform.basis.z
	camera_forward.y = 0
	camera_forward = camera_forward.normalized()
	
	for target in targets:
		if not is_instance_valid(target) or not target is Node3D:
			continue
		
		var to_target = target.global_position - global_position
		var distance = to_target.length()
		
		# Range check
		if distance > homing_range:
			continue
		
		# Cone check (based on camera forward)
		var to_target_flat = Vector3(to_target.x, 0, to_target.z).normalized()
		var angle = rad_to_deg(acos(camera_forward.dot(to_target_flat)))
		
		if angle > homing_cone_angle:
			continue
		
		# Score: prefer closer targets that are more centered
		var distance_score = 1.0 - (distance / homing_range)
		var angle_score = 1.0 - (angle / homing_cone_angle)
		var score = distance_score * 0.6 + angle_score * 0.4
		
		if score > best_score:
			best_score = score
			best_target = target
	
	return best_target


func _is_valid_homing_target(target: Node3D) -> bool:
	if not target or not is_instance_valid(target):
		return false
	
	var distance = global_position.distance_to(target.global_position)
	return distance <= homing_range


func _is_airborne_state() -> bool:
	return current_state in [
		State.AIRBORNE,
		State.AIR_ROLLING,
		State.BUTT_BOUNCE_DESCENDING,
		State.BUTT_BOUNCE_REBOUNDING,
		State.WALL_JUMP
	]
#endregion


#region Wall Detection
func _check_wall_hug() -> bool:
	if not world_input_direction.length() > 0.1:
		return false
	
	# Cast ray in input direction
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + world_input_direction * 1.0,
		collision_mask
	)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var normal = result.normal
		
		# Check if wall is vertical enough
		var wall_angle = rad_to_deg(acos(normal.dot(Vector3.UP)))
		if absf(wall_angle - 90.0) <= wall_vertical_tolerance:
			wall_normal = normal
			_change_state(State.WALL_HUG)
			return true
	
	return false
#endregion


#region Light Dash
func _check_light_dash() -> bool:
	var currencies = get_tree().get_nodes_in_group("currency")
	var nearest_currency: Node3D = null
	var nearest_distance: float = light_dash_detection_range
	
	for currency in currencies:
		if not is_instance_valid(currency) or not currency is Node3D:
			continue
		
		var distance = global_position.distance_to(currency.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_currency = currency
	
	if nearest_currency:
		# Build path from this currency
		light_dash_path = _build_light_dash_path(nearest_currency)
		if light_dash_path.size() > 0:
			light_dash_index = 0
			_change_state(State.LIGHT_DASH)
			return true
	
	return false


func _build_light_dash_path(start: Node3D) -> Array[Node3D]:
	var path: Array[Node3D] = []
	var currencies = get_tree().get_nodes_in_group("currency")
	
	# Get player facing direction (use camera forward as fallback)
	var facing = Vector3(velocity.x, 0, velocity.z).normalized()
	if facing.length() < 0.1 and camera:
		facing = -camera.global_transform.basis.z
		facing.y = 0
		facing = facing.normalized()
	
	# Start building path
	var current = start
	var visited: Array[Node3D] = []
	
	while current:
		path.append(current)
		visited.append(current)
		
		# Find next currency in roughly the same direction
		var best_next: Node3D = null
		var best_score: float = -1.0
		
		for currency in currencies:
			if currency in visited:
				continue
			if not is_instance_valid(currency) or not currency is Node3D:
				continue
			
			var to_currency = currency.global_position - current.global_position
			var distance = to_currency.length()
			
			# Must be within reasonable chaining distance
			if distance > light_dash_detection_range * 2:
				continue
			
			# Prefer currencies in the facing direction
			var direction = to_currency.normalized()
			var dot = facing.dot(Vector3(direction.x, 0, direction.z).normalized())
			
			if dot > 0.3:  # Roughly forward
				var score = dot / (1.0 + distance * 0.1)
				if score > best_score:
					best_score = score
					best_next = currency
		
		current = best_next
	
	return path


func _end_light_dash() -> void:
	light_dash_path.clear()
	light_dash_index = 0
	light_dash_ended.emit()
	
	# Transition based on grounded state
	if is_grounded:
		velocity = Vector3.ZERO
		_change_state(State.IDLE)
	else:
		_change_state(State.AIRBORNE)
#endregion


#region Damage Handling
## Call this method when the player takes damage
func take_damage(damage_source: Node3D = null, ring_loss: int = 10) -> void:
	if is_invincible:
		return
	
	# Enter hurt state
	hurt.emit(damage_source)
	rings_lost.emit(ring_loss)
	
	# Apply knockback
	var knockback_direction = -global_transform.basis.z  # Default: backward
	if damage_source:
		knockback_direction = (global_position - damage_source.global_position).normalized()
		knockback_direction.y = 0
	
	velocity = knockback_direction * hurt_knockback_velocity
	velocity.y = jump_velocity * 0.5  # Small upward bounce
	
	# Start invincibility
	is_invincible = true
	invincibility_timer = invincibility_duration
	
	_change_state(State.HURT)


## Call this when hitting an enemy with butt bounce
func on_enemy_bounce_hit(enemy: Node3D) -> void:
	consecutive_bounces = powered_bounce_count  # Force powered bounce
	shockwave_triggered.emit(enemy.global_position, shockwave_radius)
	velocity.y = butt_bounce_powered_rebound_velocity
	is_at_bounce_apex = false
	_change_state(State.BUTT_BOUNCE_REBOUNDING)
#endregion
