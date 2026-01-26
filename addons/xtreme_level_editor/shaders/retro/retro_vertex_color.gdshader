shader_type spatial;
render_mode depth_draw_always, cull_back, diffuse_lambert, specular_disabled;

// =============================================================================
// RETRO VERTEX COLOR SHADER
// PS1/Saturn-era visual effects - Vertex Color variant (Sonic Mania Style)
// =============================================================================
// Optimized for models using vertex colors instead of textures.
// This matches Sonic Mania's special stage character rendering:
//   - Low-poly models (200-600 triangles)
//   - All color from vertex colors (no textures)
//   - Gouraud shading for smooth lighting
//   - Clean, vibrant appearance
// =============================================================================

#include "retro_common.gdshaderinc"

// ===== RETRO EFFECT SETTINGS =====
group_uniforms retro_effects;
uniform bool retro_enabled = true;
uniform float retro_intensity : hint_range(0.0, 1.0, 0.05) = 0.35;

// Individual effect overrides
uniform float vertex_jitter_override : hint_range(-1.0, 1.0, 0.05) = -1.0;
uniform float color_reduction_override : hint_range(-1.0, 1.0, 0.05) = -1.0;
uniform float dither_override : hint_range(-1.0, 1.0, 0.05) = -1.0;
uniform float jitter_resolution : hint_range(32.0, 512.0, 8.0) = 128.0;

// ===== LIGHTING SETTINGS (Sonic Mania Style) =====
group_uniforms lighting;
uniform bool lighting_enabled = true;
uniform vec3 light_direction = vec3(0.3, -0.7, -0.5);
uniform vec3 light_color : source_color = vec3(1.0, 0.98, 0.95);
uniform float light_intensity : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform vec3 ambient_color : source_color = vec3(0.35, 0.35, 0.4);
uniform float ambient_intensity : hint_range(0.0, 1.0, 0.05) = 0.5;
uniform bool use_half_lambert = true;

// ===== APPEARANCE =====
group_uniforms appearance;
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Optional tint over vertex colors
uniform float saturation_boost : hint_range(0.0, 2.0, 0.05) = 1.1; // Slight boost for Mania vibrance

// Emission for glowing parts (eyes, effects)
uniform vec3 emission_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_intensity : hint_range(0.0, 5.0, 0.1) = 0.0;

// Surface properties
uniform float roughness : hint_range(0.0, 1.0) = 0.9; // Matte look typical of PS1/Saturn
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// ===== SPECIAL EFFECTS =====
group_uniforms special_effects;
uniform bool damage_flash_enabled = false;
uniform vec3 damage_flash_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float damage_flash_intensity : hint_range(0.0, 1.0) = 0.0;

// ===== VARYINGS =====
varying vec3 vertex_light;
varying vec4 v_color;

// ===== HELPER: Saturation adjustment =====
vec3 adjust_saturation(vec3 color, float saturation) {
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(luminance), color, saturation);
}

void vertex() {
	// ===== GET EFFECT INTENSITIES =====
	float jitter_intensity = vertex_jitter_override >= 0.0 ? 
		vertex_jitter_override : get_jitter_from_intensity(retro_intensity);
	
	// ===== VERTEX JITTER =====
	if (retro_enabled && jitter_intensity > 0.0) {
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 jittered_world = apply_vertex_jitter(world_pos, jitter_resolution, jitter_intensity);
		VERTEX = (inverse(MODEL_MATRIX) * vec4(jittered_world, 1.0)).xyz;
	}
	
	// ===== GOURAUD LIGHTING =====
	if (lighting_enabled) {
		vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 norm_light_dir = normalize(light_direction);
		vec3 ambient = ambient_color * ambient_intensity;
		vec3 light = light_color * light_intensity;
		
		if (use_half_lambert) {
			vertex_light = calculate_gouraud_half_lambert(world_normal, norm_light_dir, light, ambient);
		} else {
			vertex_light = calculate_gouraud_light(world_normal, norm_light_dir, light, ambient);
		}
	} else {
		vertex_light = vec3(1.0);
	}
	
	// ===== VERTEX COLOR PASSTHROUGH =====
	v_color = COLOR;
}

void fragment() {
	// ===== GET EFFECT INTENSITIES =====
	float color_intensity = color_reduction_override >= 0.0 ?
		color_reduction_override : retro_intensity;
	float dither_intensity = dither_override >= 0.0 ?
		dither_override : get_dither_from_intensity(retro_intensity);
	float color_bits = get_color_bits_from_intensity(color_intensity);
	
	// ===== BASE COLOR FROM VERTEX COLORS =====
	vec3 base_color = v_color.rgb * color_tint.rgb;
	
	// Boost saturation for Sonic Mania vibrance
	base_color = adjust_saturation(base_color, saturation_boost);
	
	// ===== APPLY GOURAUD LIGHTING =====
	vec3 lit_color = base_color * vertex_light;
	
	// ===== DAMAGE FLASH =====
	if (damage_flash_enabled && damage_flash_intensity > 0.0) {
		lit_color = mix(lit_color, damage_flash_color, damage_flash_intensity);
	}
	
	// ===== COLOR DEPTH REDUCTION =====
	vec3 final_color = lit_color;
	
	if (retro_enabled && color_intensity > 0.0) {
		if (dither_intensity > 0.0) {
			final_color = apply_dithered_color_reduction(
				lit_color, 
				color_bits, 
				FRAGCOORD.xy, 
				dither_intensity
			);
		} else {
			final_color = reduce_color_depth_blend(lit_color, color_bits, color_intensity);
		}
	}
	
	// ===== OUTPUT =====
	ALBEDO = final_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	
	// Emission
	if (emission_intensity > 0.0) {
		EMISSION = emission_color * emission_intensity;
	}
	
	// Alpha from vertex color (for transparency if needed)
	if (v_color.a < 0.99) {
		ALPHA = v_color.a * color_tint.a;
	}
}
