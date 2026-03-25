shader_type spatial;
render_mode depth_draw_always, cull_back, diffuse_lambert, specular_schlick_ggx;

// =============================================================================
// XTREME CURVED WORLD SHADER
// Combined: Curved World + Distance Wireframe + Ordered Dithering Dissolve
// =============================================================================
// Visual Pipeline:
//   Near (0-30%):     Full solid textured geometry
//   Mid (30-70%):     Solid + wireframe appearing + slight dithering
//   Far (70-90%):     Heavy dithering + prominent wireframe only
//   Very Far (90-100%): Wireframe fades out completely
// =============================================================================

// ===== CURVATURE SETTINGS =====
group_uniforms curvature;
uniform vec3 curve_center = vec3(0.0, 0.0, 0.0);
uniform float curve_horizontal : hint_range(0.0, 0.3, 0.001) = 0.15;
uniform float curve_vertical : hint_range(0.0, 0.3, 0.001) = 0.08;
// Deprecated: kept for backward compatibility with saved materials.
// If set to non-zero while curve_horizontal/curve_vertical are at defaults, this overrides both.
uniform float curve_intensity : hint_range(0.0, 0.1, 0.001) = 0.0;
uniform int curve_mode : hint_range(0, 2, 1) = 0; // 0=spherical, 1=cylindrical X, 2=cylindrical Y
uniform float curve_max_distance : hint_range(10.0, 1000.0) = 200.0;
uniform float curve_falloff_exponent : hint_range(1.0, 4.0, 0.1) = 2.0;
uniform bool curve_enabled = true;

// ===== DISTANCE EFFECT SETTINGS =====
group_uniforms distance_effects;
uniform bool distance_effects_enabled = true;
uniform float effect_max_distance : hint_range(10.0, 500.0) = 150.0;

// Wireframe settings
uniform float wireframe_start : hint_range(0.0, 1.0) = 0.3;
uniform float wireframe_full : hint_range(0.0, 1.0) = 0.7;
uniform float wireframe_thickness : hint_range(0.5, 5.0) = 1.5;
uniform bool wireframe_use_albedo_color = true;
uniform vec4 wireframe_color_override : source_color = vec4(0.0, 1.0, 1.0, 1.0);

// Wireframe fade control
uniform float wireframe_fade_sharpness : hint_range(0.1, 5.0) = 1.0;

// Dissolve settings
uniform float dissolve_start : hint_range(0.0, 1.0) = 0.3;
uniform float dissolve_full : hint_range(0.0, 1.0) = 0.9;
// Use screen-space noise to break up dither pattern (0 = pure Bayer, 1 = full noise)
uniform float dissolve_noise_mix : hint_range(0.0, 1.0) = 0.25;

// ===== APPEARANCE =====
group_uniforms appearance;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// ===== VARYINGS =====
varying vec3 world_position;
varying float distance_ratio;
varying vec3 barycentric;

// ===== 4x4 BAYER DITHER MATRIX =====
const mat4 BAYER_4X4 = mat4(
	vec4( 0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0),
	vec4(12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0),
	vec4( 3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0),
	vec4(15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0)
);

// ===== 8x8 BAYER DITHER (encoded as two 4x4 lookups) =====
// Returns an 8x8 Bayer threshold for screen coordinate (x, y)
float bayer_8x8(ivec2 pos) {
	int x = pos.x % 8;
	int y = pos.y % 8;
	// Recursive Bayer: M8(x,y) = (4 * M4(x%4, y%4) + M2(x/4, y/4)) / 64
	int x4 = x % 4;
	int y4 = y % 4;
	float base = BAYER_4X4[y4][x4]; // 0..15/16
	// Sub-matrix offset based on which quadrant of the 8x8 we're in
	int qx = x / 4;
	int qy = y / 4;
	float sub = float(qy * 2 + qx); // 0, 1, 2, or 3
	return (base * 4.0 + sub) / 4.0; // Normalized 0..1 with 64 levels
}

// Simple screen-space hash for noise-based dissolve variation
float screen_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Calculate distance from curve center for effects
	float dist_from_center = length(world_position.xz - curve_center.xz);
	distance_ratio = clamp(dist_from_center / effect_max_distance, 0.0, 1.0);

	// Apply curved world effect
	if (curve_enabled) {
		float offset_x = world_position.x - curve_center.x;
		float offset_y = world_position.y - curve_center.y;

		// Resolve curve values: use deprecated curve_intensity if set, otherwise new params
		float h_curve = curve_horizontal;
		float v_curve = curve_vertical;
		if (curve_intensity > 0.0) {
			h_curve = curve_intensity;
			v_curve = curve_intensity;
		}

		// Compute displacement with configurable falloff exponent per axis
		float displacement = 0.0;

		if (curve_mode == 0) {
			// Spherical: both horizontal and vertical curvature
			float h_dist = pow(abs(offset_x), curve_falloff_exponent);
			float v_dist = pow(abs(offset_y), curve_falloff_exponent);
			displacement = -(h_curve * h_dist + v_curve * v_dist);
		} else if (curve_mode == 1) {
			// Cylindrical X: horizontal curvature only
			float h_dist = pow(abs(offset_x), curve_falloff_exponent);
			displacement = -h_curve * h_dist;
		} else {
			// Cylindrical Y: vertical curvature only
			float v_dist = pow(abs(offset_y), curve_falloff_exponent);
			displacement = -v_curve * v_dist;
		}

		// Exponential distance falloff from camera depth
		float z_distance = abs(world_position.z - curve_center.z);
		float distance_factor = pow(clamp(1.0 - z_distance / curve_max_distance, 0.0, 1.0), curve_falloff_exponent);
		displacement *= distance_factor;

		vec3 displaced_world = world_position;
		displaced_world.z += displacement;

		VERTEX = (inverse(MODEL_MATRIX) * vec4(displaced_world, 1.0)).xyz;
	}

	// Generate barycentric coordinates for wireframe
	int vertex_id = VERTEX_ID % 3;
	if (vertex_id == 0) {
		barycentric = vec3(1.0, 0.0, 0.0);
	} else if (vertex_id == 1) {
		barycentric = vec3(0.0, 1.0, 0.0);
	} else {
		barycentric = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	// Sample base texture
	vec4 tex_color = texture(albedo_texture, UV);
	vec3 base_color = albedo.rgb * tex_color.rgb;

	// Default output - fully opaque
	vec3 final_color = base_color;

	if (distance_effects_enabled) {
		// ===== ORDERED DITHERING DISSOLVE =====
		ivec2 screen_pos = ivec2(FRAGCOORD.xy);

		// Use 8x8 Bayer matrix for higher quality dissolve pattern
		float bayer_threshold = bayer_8x8(screen_pos);

		// Mix in screen-space noise for a less patterned look
		float noise = screen_hash(FRAGCOORD.xy);
		float dither_threshold = mix(bayer_threshold, noise, dissolve_noise_mix);

		// Calculate dissolve amount (0 = solid, 1 = fully dissolved)
		float dissolve_amount = 0.0;
		if (distance_ratio > dissolve_start) {
			dissolve_amount = smoothstep(dissolve_start, dissolve_full, distance_ratio);
		}

		// ===== WIREFRAME =====
		float wireframe_amount = 0.0;
		if (distance_ratio > wireframe_start) {
			wireframe_amount = smoothstep(wireframe_start, wireframe_full, distance_ratio);
		}

		// Calculate edge detection using barycentric coordinates
		float min_bary = min(min(barycentric.x, barycentric.y), barycentric.z);
		float edge_width = wireframe_thickness * fwidth(min_bary);
		float edge = 1.0 - smoothstep(0.0, edge_width, min_bary);

		// Wireframe color
		vec3 wire_color = wireframe_use_albedo_color ? base_color : wireframe_color_override.rgb;
		wire_color = mix(wire_color, vec3(1.0), 0.3); // Brighten slightly

		// ===== COMBINE EFFECTS =====
		// Check if this pixel should be dissolved (using dither pattern)
		bool is_dissolved = (dissolve_amount > 0.0) && (dither_threshold < dissolve_amount);
		bool is_on_edge = edge > 0.5;

		if (is_dissolved) {
			// Dissolved pixel
			if (is_on_edge && wireframe_amount > 0.0) {
				// Show wireframe on edges of dissolved geometry
				final_color = wire_color;
				// At extreme distance, fade out wireframe entirely with configurable sharpness
				float fade_range = max(1.0 - wireframe_full, 0.01);
				float wireframe_fade = 1.0 - smoothstep(wireframe_full, wireframe_full + fade_range / wireframe_fade_sharpness, distance_ratio);
				if (wireframe_fade < 0.1) {
					discard; // Fully faded out
				}
			} else {
				// Dissolved and not on edge - discard this pixel
				discard;
			}
		} else {
			// Solid pixel - blend wireframe on top based on distance
			final_color = mix(base_color, wire_color, edge * wireframe_amount * 0.5);
		}
	}

	// Output - always fully opaque (depth writes correctly)
	ALBEDO = final_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	// No ALPHA output - shader is fully opaque, uses discard for transparency
}
