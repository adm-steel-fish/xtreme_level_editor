@tool
class_name RetroEditorPreview
extends EditorPlugin

## =============================================================================
## RETRO EDITOR PREVIEW
## =============================================================================
## Editor plugin that adds retro effect preview controls to the editor.
## Allows toggling retro effects on/off while editing levels.
##
## Note: This is designed to be used as part of the main XtremeLevelEditor plugin,
## but can also be registered separately if needed.
## =============================================================================

var _toolbar_button: Button
var _settings_popup: PopupPanel
var _preview_enabled: bool = false

# Settings controls
var _intensity_slider: HSlider
var _fog_toggle: CheckBox
var _jitter_toggle: CheckBox


func _enter_tree() -> void:
	_setup_toolbar()


func _exit_tree() -> void:
	_cleanup_toolbar()


func _setup_toolbar() -> void:
	# Create toolbar button
	_toolbar_button = Button.new()
	_toolbar_button.text = "Retro Preview"
	_toolbar_button.toggle_mode = true
	_toolbar_button.tooltip_text = "Toggle PS1/Saturn retro effects preview"
	_toolbar_button.pressed.connect(_on_toolbar_pressed)
	
	# Add to toolbar
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar_button)
	
	# Create settings popup
	_create_settings_popup()


func _cleanup_toolbar() -> void:
	if _toolbar_button:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _toolbar_button)
		_toolbar_button.queue_free()
		_toolbar_button = null
	
	if _settings_popup:
		_settings_popup.queue_free()
		_settings_popup = null


func _create_settings_popup() -> void:
	_settings_popup = PopupPanel.new()
	_settings_popup.title = "Retro Preview Settings"
	
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(250, 150)
	_settings_popup.add_child(container)
	
	# Title
	var title := Label.new()
	title.text = "Retro Preview Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)
	
	container.add_child(HSeparator.new())
	
	# Intensity slider
	var intensity_row := HBoxContainer.new()
	container.add_child(intensity_row)
	
	var intensity_label := Label.new()
	intensity_label.text = "Intensity:"
	intensity_label.custom_minimum_size.x = 80
	intensity_row.add_child(intensity_label)
	
	_intensity_slider = HSlider.new()
	_intensity_slider.min_value = 0.0
	_intensity_slider.max_value = 1.0
	_intensity_slider.step = 0.05
	_intensity_slider.value = 0.35
	_intensity_slider.custom_minimum_size.x = 120
	_intensity_slider.value_changed.connect(_on_intensity_changed)
	intensity_row.add_child(_intensity_slider)
	
	var intensity_value := Label.new()
	intensity_value.name = "IntensityValue"
	intensity_value.text = "35%"
	intensity_value.custom_minimum_size.x = 40
	intensity_row.add_child(intensity_value)
	
	# Toggles
	_jitter_toggle = CheckBox.new()
	_jitter_toggle.text = "Vertex Jitter"
	_jitter_toggle.button_pressed = true
	_jitter_toggle.toggled.connect(_on_jitter_toggled)
	container.add_child(_jitter_toggle)
	
	_fog_toggle = CheckBox.new()
	_fog_toggle.text = "Distance Fog"
	_fog_toggle.button_pressed = true
	_fog_toggle.toggled.connect(_on_fog_toggled)
	container.add_child(_fog_toggle)
	
	container.add_child(HSeparator.new())
	
	# Preset buttons
	var preset_label := Label.new()
	preset_label.text = "Presets:"
	container.add_child(preset_label)
	
	var preset_row := HBoxContainer.new()
	container.add_child(preset_row)
	
	var btn_modern := Button.new()
	btn_modern.text = "Modern"
	btn_modern.pressed.connect(func(): _set_preset(0.0))
	preset_row.add_child(btn_modern)
	
	var btn_light := Button.new()
	btn_light.text = "Light"
	btn_light.pressed.connect(func(): _set_preset(0.35))
	preset_row.add_child(btn_light)
	
	var btn_balanced := Button.new()
	btn_balanced.text = "Balanced"
	btn_balanced.pressed.connect(func(): _set_preset(0.5))
	preset_row.add_child(btn_balanced)
	
	var btn_authentic := Button.new()
	btn_authentic.text = "Authentic"
	btn_authentic.pressed.connect(func(): _set_preset(0.75))
	preset_row.add_child(btn_authentic)
	
	# Add to editor
	EditorInterface.get_base_control().add_child(_settings_popup)


func _on_toolbar_pressed() -> void:
	_preview_enabled = _toolbar_button.button_pressed
	
	if _preview_enabled:
		_enable_preview()
		# Show settings popup near button
		var btn_rect := _toolbar_button.get_global_rect()
		_settings_popup.position = Vector2i(int(btn_rect.position.x), int(btn_rect.end.y + 5))
		_settings_popup.popup()
	else:
		_disable_preview()
		_settings_popup.hide()


func _enable_preview() -> void:
	_apply_retro_settings(true)


func _disable_preview() -> void:
	_apply_retro_settings(false)


func _apply_retro_settings(enabled: bool) -> void:
	# Find all retro shader materials in the edited scene
	var edited_root := EditorInterface.get_edited_scene_root()
	if not edited_root:
		return
	
	var intensity: float = _intensity_slider.value if enabled else 0.0
	_apply_to_node(edited_root, enabled, intensity)


func _apply_to_node(node: Node, enabled: bool, intensity: float) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var mat := mesh_inst.material_override
		if mat and mat is ShaderMaterial:
			_apply_to_material(mat as ShaderMaterial, enabled, intensity)
		
		if mesh_inst.mesh:
			for i in mesh_inst.mesh.get_surface_count():
				var surface_mat := mesh_inst.get_surface_override_material(i)
				if surface_mat and surface_mat is ShaderMaterial:
					_apply_to_material(surface_mat as ShaderMaterial, enabled, intensity)
	
	for child in node.get_children():
		_apply_to_node(child, enabled, intensity)


func _apply_to_material(mat: ShaderMaterial, enabled: bool, intensity: float) -> void:
	if not mat.shader:
		return
	
	# Check if it's a retro shader
	var has_retro := false
	for uniform in mat.shader.get_shader_uniform_list():
		if uniform["name"] == "retro_enabled" or uniform["name"] == "retro_intensity":
			has_retro = true
			break
	
	if not has_retro:
		return
	
	mat.set_shader_parameter("retro_enabled", enabled)
	mat.set_shader_parameter("retro_intensity", intensity)
	
	# Apply individual toggles
	if _jitter_toggle:
		var jitter_val: float = intensity if _jitter_toggle.button_pressed else 0.0
		mat.set_shader_parameter("vertex_jitter_override", jitter_val if enabled else -1.0)
	
	if _fog_toggle:
		mat.set_shader_parameter("fog_enabled", enabled and _fog_toggle.button_pressed)


func _on_intensity_changed(value: float) -> void:
	# Update label
	var intensity_value := _settings_popup.get_node_or_null("VBoxContainer/HBoxContainer/IntensityValue")
	if intensity_value:
		intensity_value.text = "%d%%" % int(value * 100)
	
	if _preview_enabled:
		_apply_retro_settings(true)


func _on_jitter_toggled(pressed: bool) -> void:
	if _preview_enabled:
		_apply_retro_settings(true)


func _on_fog_toggled(pressed: bool) -> void:
	if _preview_enabled:
		_apply_retro_settings(true)


func _set_preset(intensity: float) -> void:
	_intensity_slider.value = intensity
	_on_intensity_changed(intensity)
