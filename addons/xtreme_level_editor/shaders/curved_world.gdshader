shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Curved World Shader for Sonic Xtreme-style effect
// Displaces vertices TOWARD the camera (negative Z) based on distance from screen center
// Creates a spherical effect where left, right, top, and bottom edges curve toward viewer

group_uniforms curvature;
// The center point of the curvature (usually player/camera position)
uniform vec3 curve_center = vec3(0.0, 0.0, 0.0);

// Curvature intensity - higher values = more pronounced curve
uniform float curve_intensity : hint_range(0.0, 0.1, 0.001) = 0.01;

// Curvature mode
// 0 = Spherical (curves in all directions - left, right, top, bottom)
// 1 = Cylindrical X (curves left/right only)
// 2 = Cylindrical Y (curves top/bottom only)
uniform int curve_mode : hint_range(0, 2, 1) = 0;

// Maximum distance at which curvature is applied
uniform float curve_max_distance : hint_range(10.0, 1000.0) = 200.0;

// Whether to apply curvature (for toggling in editor)
uniform bool curve_enabled = true;

group_uniforms appearance;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_position;
varying float curve_amount;

void vertex() {
	// Get world position of vertex
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	if (curve_enabled) {
		// Calculate offset from curve center
		// X = left/right distance from center
		// Y = up/down distance from center (height difference)
		float offset_x = world_position.x - curve_center.x;
		float offset_y = world_position.y - curve_center.y;
		
		float distance_sq = 0.0;
		
		if (curve_mode == 0) {
			// Spherical - use both X and Y distance (curves all edges)
			distance_sq = offset_x * offset_x + offset_y * offset_y;
		} else if (curve_mode == 1) {
			// Cylindrical X - only curve based on X distance (left/right)
			distance_sq = offset_x * offset_x;
		} else {
			// Cylindrical Y - only curve based on Y distance (top/bottom)
			distance_sq = offset_y * offset_y;
		}
		
		// Calculate Z displacement (pull vertices TOWARD camera)
		// NEGATIVE Z displacement pulls geometry closer to camera at edges
		float displacement = -curve_intensity * distance_sq;
		
		// Apply distance falloff based on Z distance to prevent extreme curvature
		float z_distance = abs(world_position.z - curve_center.z);
		float distance_factor = clamp(1.0 - z_distance / curve_max_distance, 0.0, 1.0);
		displacement *= distance_factor;
		
		// Apply the displacement in world space (pull toward camera in Z)
		vec3 displaced_world = world_position;
		displaced_world.z += displacement;
		
		// Convert back to local space
		VERTEX = (inverse(MODEL_MATRIX) * vec4(displaced_world, 1.0)).xyz;
		
		// Store curve amount for potential use in fragment shader
		curve_amount = abs(displacement);
	} else {
		curve_amount = 0.0;
	}
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb * tex_color.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	ALPHA = albedo.a * tex_color.a;
}
