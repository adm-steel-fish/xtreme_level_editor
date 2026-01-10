extends CanvasLayer
class_name XtremeTransitionManager
## Manages screen transitions between chunk sets (iris wipe, fade, etc.)

## Emitted when transition starts
signal transition_started(transition_type: int)

## Emitted at the midpoint (when screen is fully covered)
signal transition_midpoint

## Emitted when transition completes
signal transition_finished

## Transition types (matching XtremePipeConnection.TransitionType)
enum TransitionType {
	IRIS_CLOSE,
	FADE_BLACK,
	WIPE_LEFT,
	WIPE_RIGHT,
	WIPE_UP,
	WIPE_DOWN,
	INSTANT,
	CUSTOM
}

## Current transition state
enum State {
	IDLE,
	CLOSING,
	HOLD,
	OPENING
}

@export var transition_color: Color = Color.BLACK

var _state: State = State.IDLE
var _current_type: TransitionType = TransitionType.IRIS_CLOSE
var _progress: float = 0.0
var _duration: float = 0.5
var _hold_duration: float = 0.1
var _hold_timer: float = 0.0

var _transition_rect: ColorRect
var _shader_material: ShaderMaterial

func _ready() -> void:
	layer = 100  # Above everything
	_setup_transition_rect()

func _setup_transition_rect() -> void:
	_transition_rect = ColorRect.new()
	_transition_rect.name = "TransitionRect"
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.visible = false
	
	# Create shader for iris effect
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int transition_type = 0;
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 uv = UV;
	float alpha = 0.0;
	
	if (transition_type == 0) {
		// Iris close/open
		float dist = distance(uv, center);
		float radius = (1.0 - progress) * 1.5;
		alpha = smoothstep(radius - 0.05, radius, dist);
	} else if (transition_type == 1) {
		// Fade
		alpha = progress;
	} else if (transition_type == 2) {
		// Wipe left
		alpha = step(uv.x, progress);
	} else if (transition_type == 3) {
		// Wipe right
		alpha = step(1.0 - uv.x, progress);
	} else if (transition_type == 4) {
		// Wipe up
		alpha = step(1.0 - uv.y, progress);
	} else if (transition_type == 5) {
		// Wipe down
		alpha = step(uv.y, progress);
	} else {
		// Instant
		alpha = progress > 0.5 ? 1.0 : 0.0;
	}
	
	COLOR = vec4(transition_color.rgb, alpha * transition_color.a);
}
"""
	
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("transition_color", transition_color)
	_shader_material.set_shader_parameter("progress", 0.0)
	_shader_material.set_shader_parameter("transition_type", 0)
	
	_transition_rect.material = _shader_material
	add_child(_transition_rect)

func _process(delta: float) -> void:
	match _state:
		State.CLOSING:
			_progress += delta / _duration
			if _progress >= 1.0:
				_progress = 1.0
				_state = State.HOLD
				_hold_timer = 0.0
				transition_midpoint.emit()
			_update_shader()
		
		State.HOLD:
			_hold_timer += delta
			if _hold_timer >= _hold_duration:
				_state = State.OPENING
		
		State.OPENING:
			_progress -= delta / _duration
			if _progress <= 0.0:
				_progress = 0.0
				_state = State.IDLE
				_transition_rect.visible = false
				transition_finished.emit()
			_update_shader()

func _update_shader() -> void:
	_shader_material.set_shader_parameter("progress", _progress)

## Start a transition
func start_transition(type: TransitionType = TransitionType.IRIS_CLOSE, duration: float = 0.5, hold: float = 0.1) -> void:
	if _state != State.IDLE:
		return
	
	_current_type = type
	_duration = duration
	_hold_duration = hold
	_progress = 0.0
	_state = State.CLOSING
	
	_shader_material.set_shader_parameter("transition_type", int(type))
	_shader_material.set_shader_parameter("transition_color", transition_color)
	_transition_rect.visible = true
	
	transition_started.emit(int(type))

## Start transition and call a callback at midpoint
func transition_to(callback: Callable, type: TransitionType = TransitionType.IRIS_CLOSE, duration: float = 0.5) -> void:
	if _state != State.IDLE:
		return
	
	start_transition(type, duration, 0.1)
	
	# Connect to midpoint signal for one-shot
	var connection: Callable
	connection = func():
		callback.call()
		transition_midpoint.disconnect(connection)
	transition_midpoint.connect(connection)

## Set the iris center point (normalized 0-1)
func set_iris_center(center: Vector2) -> void:
	_shader_material.set_shader_parameter("center", center)

## Check if currently transitioning
func is_transitioning() -> bool:
	return _state != State.IDLE

## Force complete transition immediately
func force_complete() -> void:
	_state = State.IDLE
	_progress = 0.0
	_transition_rect.visible = false
	transition_finished.emit()

## Quick iris transition helper
func iris_transition(callback: Callable, duration: float = 0.4) -> void:
	transition_to(callback, TransitionType.IRIS_CLOSE, duration)

## Quick fade transition helper
func fade_transition(callback: Callable, duration: float = 0.3) -> void:
	transition_to(callback, TransitionType.FADE_BLACK, duration)
