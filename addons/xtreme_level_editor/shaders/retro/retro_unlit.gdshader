shader_type spatial;
render_mode depth_draw_always, cull_back, unshaded;

// =============================================================================
// RETRO UNLIT SHADER
// PS1/Saturn-era visual effects - Unlit/Emissive variant
// =============================================================================
// For objects that should be self-illuminated and not affected by lighting:
//   - Rings (gold, glowing)
//   - Blue/Red Spheres
//   - Power-up items
//   - UI elements in 3D space
//   - Particle effects
// 
// These objects maintain consistent appearance regardless of scene lighting,
// matching how collectibles appeared in Sonic Mania's special stages.
// =============================================================================

#include "retro_common.gdshaderinc"
#include "res://addons/xtreme_level_editor/shaders/curved_world.gdshaderinc"

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

// ===== COLOR SETTINGS =====
group_uniforms appearance;
uniform vec4 albedo : source_color = vec4(1.0, 0.85, 0.0, 1.0); // Gold ring default
uniform bool use_texture = false;
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform bool use_vertex_color = true; // Most collectibles use vertex colors
uniform float brightness : hint_range(0.5, 2.0, 0.05) = 1.2; // Slight glow boost

// ===== PULSING/ANIMATION =====
group_uniforms animation;
uniform bool pulse_enabled = false;
uniform float pulse_speed : hint_range(0.1, 10.0) = 3.0;
uniform float pulse_intensity : hint_range(0.0, 0.5) = 0.15;
uniform vec3 pulse_color : source_color = vec3(1.0, 1.0, 1.0); // Additive pulse color

// ===== FRESNEL RIM =====
group_uniforms rim_effect;
uniform bool rim_enabled = true; // Subtle rim lighting for depth
uniform vec3 rim_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.3;
uniform float rim_power : hint_range(0.5, 8.0) = 2.0;

// ===== SPECIAL STATES =====
group_uniforms special_states;
uniform bool flash_enabled = false;
uniform vec3 flash_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;

// Fade out (for collection animation)
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

// ===== VARYINGS =====
varying vec2 affine_uv;
varying float inv_depth;
varying vec4 v_color;
varying vec3 world_normal;
varying vec3 view_dir;

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
	affine_uv = UV * depth;
	inv_depth = 1.0 / depth;
	
	// ===== RIM LIGHTING PREP =====
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 camera_pos = (inverse(VIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	view_dir = normalize(camera_pos - world_pos);
	
	// ===== VERTEX COLOR PASSTHROUGH =====
	v_color = COLOR;

	// ===== CURVED WORLD =====
	// Applied last, so rim/affine varyings above use the true (uncurved)
	// position and only the final geometry is bent.
	VERTEX = xtreme_curve_vertex(VERTEX, MODEL_MATRIX);
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
	
	// ===== BASE COLOR =====
	vec3 base_color = albedo.rgb;
	
	// Texture sampling with affine warping
	if (use_texture) {
		vec2 final_uv = UV;
		if (retro_enabled && affine_intensity > 0.0) {
			final_uv = apply_affine_mapping(affine_uv, inv_depth, UV, affine_intensity);
		}
		vec4 tex_color = texture(albedo_texture, final_uv);
		base_color *= tex_color.rgb;
	}
	
	// Vertex color
	if (use_vertex_color) {
		base_color *= v_color.rgb;
	}
	
	// Apply brightness boost
	base_color *= brightness;
	
	// ===== RIM LIGHTING =====
	if (rim_enabled) {
		float rim = 1.0 - max(dot(world_normal, view_dir), 0.0);
		rim = pow(rim, rim_power);
		base_color += rim_color * rim * rim_intensity;
	}
	
	// ===== PULSE ANIMATION =====
	if (pulse_enabled) {
		float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
		base_color += pulse_color * pulse * pulse_intensity;
	}
	
	// ===== FLASH EFFECT =====
	if (flash_enabled && flash_intensity > 0.0) {
		base_color = mix(base_color, flash_color, flash_intensity);
	}
	
	// ===== COLOR DEPTH REDUCTION =====
	vec3 final_color = base_color;
	
	if (retro_enabled && color_intensity > 0.0) {
		if (dither_intensity > 0.0) {
			final_color = apply_dithered_color_reduction(
				base_color, 
				color_bits, 
				FRAGCOORD.xy, 
				dither_intensity
			);
		} else {
			final_color = reduce_color_depth_blend(base_color, color_bits, color_intensity);
		}
	}
	
	// ===== OUTPUT =====
	ALBEDO = final_color;
	
	// Alpha handling for fade effects
	float final_alpha = albedo.a * fade_alpha;
	if (use_vertex_color) {
		final_alpha *= v_color.a;
	}
	
	if (final_alpha < 0.99) {
		ALPHA = final_alpha;
	}
}
