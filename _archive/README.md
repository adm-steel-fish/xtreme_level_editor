# Archive

Scripts moved out of the live project during the 2026-11 demo cleanup.
Godot ignores this folder (`.gdignore`), so nothing here is loaded, compiled or exported.

Nothing was deleted. To restore a file, move it back to the same path
(the folder layout here mirrors the project), e.g.:

    git mv _archive/scripts/flying/flying_controller.gd scripts/flying/flying_controller.gd

Everything here was unreferenced by any scene or live script at archive time.
The full pre-cleanup project is also tagged in git as `pre-cleanup`.

| Archived | Why |
|---|---|
| scripts/flying/ | Flying-stage prototype, never used by a scene |
| scripts/special_stage/ | Special-stage prototype, never used by a scene |
| scripts/powerups/ | Monitors/power-ups, never placed in a level (revisit for the demo if wanted) |
| scripts/transitions/section_transition.gd | Unused; transition_manager.gd kept for level transitions |
| nodes/xtreme_camera_fixed.gd | Superseded by xtreme_camera.gd |
| nodes/chunk_loader.gd | Runtime chunk streaming, never used |
| editor/retro_editor_preview.gd | EditorPlugin that was never registered |
| scripts/player.gd, scripts/test_camera.gd, scenes/camera_3d.gd | Stubs, unreferenced |
