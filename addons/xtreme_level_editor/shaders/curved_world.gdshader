shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// Curved World Shader for Sonic Xtreme-style effect
// Applies vertex displacement to curve the world around a center point

group_uniforms curvature;
// The center point of the curvature (usually player/camera position)
uniform vec3 curve_center = vec3(0.0, 0.0, 0.0);

// Curvature intensity - higher values = more pronounced curve
uniform float curve_intensity : hint_range(0.0, 0.1, 0.001) = 0.01;

// Curvature mode
// 0 = Spherical (curves in all horizontal directions)
// 1 = Cylindrical X (curves along X axis only)
// 2 = Cylindrical Z (curves along Z axis only)
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
		// Calculate horizontal distance from curve center
		vec2 horizontal_offset = world_position.xz - curve_center.xz;
		float distance_sq = 0.0;
		
		if (curve_mode == 0) {
			// Spherical - use full horizontal distance
			distance_sq = dot(horizontal_offset, horizontal_offset);
		} else if (curve_mode == 1) {
			// Cylindrical X - only curve based on X distance
			distance_sq = horizontal_offset.x * horizontal_offset.x;
		} else {
			// Cylindrical Z - only curve based on Z distance
			distance_sq = horizontal_offset.y * horizontal_offset.y;
		}
		
		// Calculate vertical displacement (parabolic falloff)
		// The further from center, the more the vertex drops
		float displacement = -curve_intensity * distance_sq;
		
		// Apply distance falloff to prevent extreme curvature at far distances
		float distance_factor = clamp(1.0 - sqrt(distance_sq) / curve_max_distance, 0.0, 1.0);
		displacement *= distance_factor;
		
		// Apply the displacement in world space, then convert back to local
		vec3 displaced_world = world_position;
		displaced_world.y += displacement;
		
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
