// =============================================================================
// XTREME CURVED WORLD — SHARED CURVE MATH
// =============================================================================
// The Sonic X-treme "reflex lens" look only works if EVERY rendered object
// curves by the same amount. If the level geometry curves but rings, rails,
// enemies and the player do not, objects visibly detach from the ground the
// further they are from the curve centre.
//
// So the curve lives here, once, and every in-world shader includes it:
//
//     #include "res://addons/xtreme_level_editor/shaders/curved_world.gdshaderinc"
//
//     void vertex() {
//         ...
//         VERTEX = xtreme_curve_vertex(VERTEX, MODEL_MATRIX);
//     }
//
// The parameters are Godot *global* shader uniforms (declared in
// project.godot under [shader_globals], driven at runtime by
// scripts/game/curve_driver.gd). That means there is exactly one source of
// truth: no per-material syncing, no walking the scene tree to find materials,
// and objects spawned at runtime curve correctly the moment they appear.
// =============================================================================

global uniform bool  xtreme_curve_enabled;
// 0 = spherical, 1 = cylindrical X (horizontal only), 2 = cylindrical Y (vertical only)
global uniform int   xtreme_curve_mode;
global uniform vec3  xtreme_curve_center;
global uniform float xtreme_curve_horizontal;
global uniform float xtreme_curve_vertical;
global uniform float xtreme_curve_max_distance;
global uniform float xtreme_curve_falloff_exponent;


// Bend a WORLD-SPACE position around the curve centre.
// Use this directly in shaders declared with `render_mode world_vertex_coords`.
vec3 xtreme_curve_world(vec3 world_position) {
	if (!xtreme_curve_enabled) {
		return world_position;
	}

	float offset_x = world_position.x - xtreme_curve_center.x;
	float offset_y = world_position.y - xtreme_curve_center.y;
	float e = xtreme_curve_falloff_exponent;

	float displacement = 0.0;
	if (xtreme_curve_mode == 0) {
		// Spherical: bend on both axes
		displacement = -(xtreme_curve_horizontal * pow(abs(offset_x), e)
		               + xtreme_curve_vertical   * pow(abs(offset_y), e));
	} else if (xtreme_curve_mode == 1) {
		displacement = -xtreme_curve_horizontal * pow(abs(offset_x), e);
	} else {
		displacement = -xtreme_curve_vertical * pow(abs(offset_y), e);
	}

	// Fall off with depth so geometry near the camera stays undistorted.
	float z_distance = abs(world_position.z - xtreme_curve_center.z);
	float distance_factor = pow(
		clamp(1.0 - z_distance / max(xtreme_curve_max_distance, 0.001), 0.0, 1.0), e);
	displacement *= distance_factor;

	vec3 result = world_position;
	result.z += displacement;
	return result;
}


// Bend a MODEL-SPACE vertex, returning model space again.
// For shaders that keep Godot's default (model-space) VERTEX.
vec3 xtreme_curve_vertex(vec3 model_vertex, mat4 model_matrix) {
	if (!xtreme_curve_enabled) {
		return model_vertex;
	}
	vec3 world_position = (model_matrix * vec4(model_vertex, 1.0)).xyz;
	vec3 curved = xtreme_curve_world(world_position);
	return (inverse(model_matrix) * vec4(curved, 1.0)).xyz;
}


// Bend a billboarded/particle quad by its ORIGIN only, so the card keeps
// facing the camera instead of shearing. Returns the world-space offset to
// add to MODELVIEW_MATRIX[3] (or to the model origin).
vec3 xtreme_curve_origin_offset(mat4 model_matrix) {
	if (!xtreme_curve_enabled) {
		return vec3(0.0);
	}
	vec3 origin = model_matrix[3].xyz;
	return xtreme_curve_world(origin) - origin;
}
