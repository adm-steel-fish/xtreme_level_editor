extends Node
class_name XtremeTrickSystem
## Shared trick scoring system for surfing and snowboarding.
## Processes trick inputs during air time and calculates scores.

enum TrickType { SPIN, FLIP, GRAB, SPIN_FLIP, GRAB_SPIN }

@export_group("Scoring")
## Base points per trick type.
@export var spin_base_score: int = 100
@export var flip_base_score: int = 150
@export var grab_base_score: int = 200
@export var combo_base_score: int = 400
@export var advanced_combo_score: int = 600

@export_group("Combo")
## Max combo multiplier.
@export var max_combo_multiplier: float = 5.0
## Combo multiplier increment per successive trick landing.
@export var combo_increment: float = 0.5

@export_group("Landing")
## Perfect landing bonus multiplier.
@export var perfect_landing_bonus: float = 1.25
## Sloppy landing penalty multiplier.
@export var sloppy_landing_penalty: float = 0.5
## Min air time for a valid trick (seconds).
@export var min_air_time: float = 0.3

@export_group("Input")
## How long a grab must be held to register.
@export var grab_hold_time: float = 0.3

#region State
var combo_multiplier: float = 1.0
var current_trick_score: int = 0
var tricks_in_air: int = 0
var is_tricking: bool = false
var _air_time: float = 0.0
var _spin_rotation: float = 0.0
var _flip_rotation: float = 0.0
var _grab_timer: float = 0.0
var _is_grabbing: bool = false
var _current_tricks: Array[Dictionary] = []  # [{type, score, name}]
var _controller: Node  # SurfboardController or SnowboardController
#endregion

#region Signals
signal trick_performed(trick_name: String, score: int)
signal combo_updated(multiplier: float, total_score: int)
signal trick_landed(total_score: int, was_perfect: bool)
signal trick_failed()
#endregion


func _ready() -> void:
	add_to_group("trick_system")


## Attach to a controller (surfboard or snowboard).
func attach(controller: Node) -> void:
	_controller = controller


func _process(delta: float) -> void:
	if not is_tricking:
		return

	_air_time += delta
	_process_trick_input(delta)


## Call when the player leaves the ground.
func begin_air(initial_velocity_y: float) -> void:
	is_tricking = true
	_air_time = 0.0
	_spin_rotation = 0.0
	_flip_rotation = 0.0
	_grab_timer = 0.0
	_is_grabbing = false
	_current_tricks.clear()
	tricks_in_air = 0
	current_trick_score = 0


## Call when the player lands. Returns the final score.
func end_air() -> int:
	if not is_tricking:
		return 0
	is_tricking = false

	if _air_time < min_air_time or _current_tricks.is_empty():
		trick_failed.emit()
		return 0

	# Calculate landing quality based on vertical velocity
	var was_perfect := _air_time > 0.5 and tricks_in_air >= 1
	var landing_mult := perfect_landing_bonus if was_perfect else 1.0

	var final_score := int(float(current_trick_score) * combo_multiplier * landing_mult)

	# Increment combo for next air
	combo_multiplier = minf(combo_multiplier + combo_increment, max_combo_multiplier)

	trick_landed.emit(final_score, was_perfect)
	combo_updated.emit(combo_multiplier, final_score)

	# Report to controller
	if _controller and _controller.has_method("register_trick"):
		var trick_summary := _get_trick_summary()
		_controller.register_trick(trick_summary, final_score)

	return final_score


## Call on wipeout or crash to reset combo.
func reset_combo() -> void:
	combo_multiplier = 1.0
	is_tricking = false
	_current_tricks.clear()
	combo_updated.emit(combo_multiplier, 0)


func _process_trick_input(delta: float) -> void:
	# Spin: left/right during air
	var spin_input := Input.get_axis("move_left", "move_right")
	if absf(spin_input) > 0.5:
		_spin_rotation += spin_input * delta * 360.0
		if absf(_spin_rotation) >= 360.0:
			_register_trick(TrickType.SPIN, "Spin", spin_base_score)
			_spin_rotation = fmod(_spin_rotation, 360.0)

	# Flip: up/down during air
	var flip_input := Input.get_axis("move_up", "move_down")
	if absf(flip_input) > 0.5:
		_flip_rotation += flip_input * delta * 360.0
		if absf(_flip_rotation) >= 360.0:
			_register_trick(TrickType.FLIP, "Flip", flip_base_score)
			_flip_rotation = fmod(_flip_rotation, 360.0)

	# Grab: hold modifier button
	if Input.is_action_pressed("grab"):
		_grab_timer += delta
		if _grab_timer >= grab_hold_time and not _is_grabbing:
			_is_grabbing = true
			_register_trick(TrickType.GRAB, "Grab", grab_base_score)
	else:
		_grab_timer = 0.0
		_is_grabbing = false

	# Combo tricks: spin + flip simultaneously
	if absf(spin_input) > 0.5 and absf(flip_input) > 0.5:
		if absf(_spin_rotation) >= 180.0 and absf(_flip_rotation) >= 180.0:
			_register_trick(TrickType.SPIN_FLIP, "Corkscrew", combo_base_score)
			_spin_rotation = 0.0
			_flip_rotation = 0.0

	# Advanced: grab + spin
	if _is_grabbing and absf(spin_input) > 0.5:
		if absf(_spin_rotation) >= 360.0:
			_register_trick(TrickType.GRAB_SPIN, "Method Air", advanced_combo_score)
			_spin_rotation = 0.0


func _register_trick(type: TrickType, trick_name: String, score: int) -> void:
	_current_tricks.append({
		"type": type,
		"name": trick_name,
		"score": score,
	})
	tricks_in_air += 1
	current_trick_score += score
	trick_performed.emit(trick_name, score)


func _get_trick_summary() -> String:
	if _current_tricks.is_empty():
		return "No Trick"
	if _current_tricks.size() == 1:
		return _current_tricks[0]["name"]
	# Combine trick names
	var names: PackedStringArray = []
	for t in _current_tricks:
		names.append(t["name"])
	return " + ".join(names)
