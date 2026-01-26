shader_type spatial;
render_mode depth_draw_always, cull_back, diffuse_lambert, specular_disabled;

// =============================================================================
// RETRO TEXTURED SHADER
// PS1/Saturn-era visual effects - Texture-focused variant
// =============================================================================
// Optimized for environment geometry with low-resolution textures.
// Features strong affine texture warping for authentic PS1 look.
// 
// Texture Guidelines:
//   - Resolution: 32x32 to 128x128 pixels max
//   - Filtering: Nearest-neighbor (point sampling)
//   - Style: Hand-pixeled, simple patterns, grid-aligned UVs
// =============================================================================

#include "retro_common.gdshaderinc"

// ===== RETRO EFFECT SETTINGS =====
group_uniforms retro_effects;
uniform bool retro_enabled = true;
uniform float retro_intensity : hint_range(0.0, 1.0, 0.05) = 0.35;

// Individual effect overrides
uniform float vertex_jitter_override : hint_range(-1.0, 1.0, 0.05) = -1.0;
uniform float affine_warp_override : hint_range(-1.0, 1.0, 0.05) = -1.0;
uniform float color_reduction_override : hint_range(-1.0, 1.0, 0.05) = -1.0;
uniform float dither_override : hint_range(-1.0, 1.0, 0.05) = -1.0;
uniform float jitter_resolution : hint_range(32.0, 512.0, 8.0) = 128.0;

// ===== LIGHTING SETTINGS =====
group_uniforms lighting;
uniform bool lighting_enabled = true;
uniform vec3 light_direction = vec3(0.3, -0.7, -0.5);
uniform vec3 light_color : source_color = vec3(1.0, 0.98, 0.95);
uniform float light_intensity : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform vec3 ambient_color : source_color = vec3(0.25, 0.25, 0.3);
uniform float ambient_intensity : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform bool use_half_lambert = true;

// ===== TEXTURE SETTINGS =====
group_uniforms textures;
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

// Optional detail/second texture
uniform bool use_detail_texture = false;
uniform sampler2D detail_texture : filter_nearest, repeat_enable;
uniform float detail_blend : hint_range(0.0, 1.0) = 0.5;
uniform vec2 detail_uv_scale = vec2(4.0, 4.0);

// ===== VERTEX COLOR TINTING =====
group_uniforms vertex_tint;
uniform bool use_vertex_color_tint = false; // Multiply texture by vertex colors
uniform float vertex_tint_intensity : hint_range(0.0, 1.0) = 0.5;

// ===== SURFACE PROPERTIES =====
group_uniforms surface;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// Emission for glowing environment parts
uniform vec3 emission_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_intensity : hint_range(0.0, 5.0, 0.1) = 0.0;

// ===== VARYINGS =====
varying vec3 vertex_light;
varying vec2 affine_uv;
varying vec2 affine_detail_uv;
varying float inv_depth;
varying vec4 v_color;

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
	
	// ===== AFFINE TEXTURE MAPPING PREP =====
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float depth = max(-view_pos.z, 0.001);
	
	// Calculate transformed UVs
	vec2 transformed_uv = UV * uv_scale + uv_offset;
	vec2 detail_transformed_uv = UV * detail_uv_scale;
	
	// Store affine UVs
	affine_uv = transformed_uv * depth;
	affine_detail_uv = detail_transformed_uv * depth;
	inv_depth = 1.0 / depth;
	
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
	float affine_intensity = affine_warp_override >= 0.0 ?
		affine_warp_override : get_affine_from_intensity(retro_intensity);
	float color_intensity = color_reduction_override >= 0.0 ?
		color_reduction_override : retro_intensity;
	float dither_intensity = dither_override >= 0.0 ?
		dither_override : get_dither_from_intensity(retro_intensity);
	float color_bits = get_color_bits_from_intensity(color_intensity);
	
	// ===== CALCULATE FINAL UVs =====
	vec2 correct_uv = UV * uv_scale + uv_offset;
	vec2 final_uv = correct_uv;
	vec2 final_detail_uv = UV * detail_uv_scale;
	
	if (retro_enabled && affine_intensity > 0.0) {
		final_uv = apply_affine_mapping(affine_uv, inv_depth, correct_uv, affine_intensity);
		final_detail_uv = apply_affine_mapping(affine_detail_uv, inv_depth, UV * detail_uv_scale, affine_intensity);
	}
	
	// ===== TEXTURE SAMPLING =====
	vec4 tex_color = texture(albedo_texture, final_uv);
	vec3 base_color = tex_color.rgb * albedo_tint.rgb;
	
	// Blend detail texture if enabled
	if (use_detail_texture) {
		vec4 detail_color = texture(detail_texture, final_detail_uv);
		base_color = mix(base_color, base_color * detail_color.rgb * 2.0, detail_blend);
	}
	
	// ===== VERTEX COLOR TINTING =====
	if (use_vertex_color_tint) {
		base_color = mix(base_color, base_color * v_color.rgb, vertex_tint_intensity);
	}
	
	// ===== APPLY GOURAUD LIGHTING =====
	vec3 lit_color = base_color * vertex_light;
	
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
	
	// Alpha from texture
	if (tex_color.a < 0.99) {
		ALPHA = tex_color.a * albedo_tint.a;
	}
}
