@tool
class_name XtremeBuildMode
extends XtremeEditorMode

## Build Mode - Tile placement, selection, and path editing.
## This is a thin delegation wrapper around the existing plugin methods.
## The actual implementation remains in plugin.gd for stability.
## Future refactoring can gradually move logic into this class.

# Reference back to the typed plugin for method calls
var _plugin_ref: EditorPlugin


func activate() -> void:
	super.activate()
	_plugin_ref = plugin
	# Ensure build-mode UI elements are visible
	if _plugin_ref and _plugin_ref.has_method("_update_tool_buttons"):
		_plugin_ref.call("_update_tool_buttons")


func deactivate() -> void:
	super.deactivate()


func handle_3d_input(camera: Camera3D, event: InputEvent) -> int:
	# Delegate to plugin's existing _forward_3d_gui_input logic
	if _plugin_ref and _plugin_ref.has_method("_handle_build_3d_input"):
		return _plugin_ref.call("_handle_build_3d_input", camera, event)
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func handle_key_input(event: InputEventKey) -> bool:
	# Delegate to plugin's existing keyboard handling
	if _plugin_ref and _plugin_ref.has_method("_handle_build_key_input"):
		return _plugin_ref.call("_handle_build_key_input", event)
	return false


func handle_global_mouse_release(event: InputEventMouseButton) -> void:
	if _plugin_ref and _plugin_ref.has_method("_handle_build_mouse_release"):
		_plugin_ref.call("_handle_build_mouse_release", event)
