@tool
class_name XtremeEditorMode
extends RefCounted

## Base class for all editor modes in the Xtreme Level Editor.
## Each mode provides its own UI panel and handles 3D viewport input.

# Shared references set by the plugin when activating this mode
var plugin: EditorPlugin
var level_data: XtremeLevelData
var grid_settings: XtremeGridSettings
var palette: XtremeTilePalette
var grid_visualizer: XtremeGridVisualizer

# Whether this mode is currently active
var _active: bool = false


## Called when this mode becomes the active mode.
## Override to set up mode-specific state.
func activate() -> void:
	_active = true


## Called when this mode is deactivated (another mode selected).
## Override to clean up mode-specific state and 3D scene objects.
func deactivate() -> void:
	_active = false


## Create and return the UI panel for this mode's dock tab.
## Override to build mode-specific controls.
func create_ui() -> Control:
	return null


## Handle 3D viewport input events (mouse clicks, motion, etc.).
## Return EditorPlugin.AFTER_GUI_INPUT_STOP to consume the event,
## or EditorPlugin.AFTER_GUI_INPUT_PASS to let it through.
func handle_3d_input(camera: Camera3D, event: InputEvent) -> int:
	return EditorPlugin.AFTER_GUI_INPUT_PASS


## Handle keyboard input events.
## Return true if the event was consumed, false to let it through.
func handle_key_input(event: InputEventKey) -> bool:
	return false


## Handle mouse button release globally (called from _input).
## Some modes need to finalize actions when the mouse is released
## outside the 3D viewport.
func handle_global_mouse_release(event: InputEventMouseButton) -> void:
	pass


## Called each editor frame while this mode is active.
func process(delta: float) -> void:
	pass


## Convenience: set the status label text in the dock.
func set_status(text: String) -> void:
	if not plugin:
		return
	var dock = plugin.get("_main_dock")
	if dock and is_instance_valid(dock):
		var status := dock.find_child("Status", true, false) as Label
		if status:
			status.text = text
	print("[XtremeEditor] %s" % text)


## Convenience: get the edited scene root.
func get_scene_root() -> Node:
	return EditorInterface.get_edited_scene_root()


## Convenience: add a temporary node to the scene.
func add_temp_node(node: Node, parent: Node = null) -> void:
	if not parent:
		parent = get_scene_root()
	if parent and is_instance_valid(parent):
		parent.add_child(node)
		node.owner = null  # Don't save with scene


## Convenience: create a styled label.
func make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
