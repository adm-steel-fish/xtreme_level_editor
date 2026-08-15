shader_type spatial;
render_mode depth_draw_always, cull_back, diffuse_lambert, specular_disabled;

// =============================================================================
// RETRO STANDARD SHADER
// PS1/Saturn-era visual effects - Standard variant (texture + vertex color)
// =============================================================================
// This is the primary retro shader supporting both textures and vertex colors.
// Designed to work ALONGSIDE (not merged with) the curved world shader.
// 
// Usage:
//   - General purpose geometry with retro aesthetic
//   - Supports albedo texture, vertex colors, or both
//   - Full suite of PS1/Saturn effects with adjustable intensity
// =============================================================================

#include "retro_common.gdshaderinc"
#include "res://addons/xtreme_level_editor/shaders/curved_world.gdshaderinc"

// ===== RETRO EFFECT SETTINGS =====
group_uniforms retro_effects;
uniform bool retro_enabled = true;
uniform float retro_intensity : hint_range(0.0, 1.0, 0.05) = 0.35; // Default: Light retro (35%)

// Individual effect overrides (use -1.0 to derive from retro_intensity)
uniform float vertex_jitter_override : hint_range(-1.0, 1.0, 0.05) = -1.0;
uniform float affine_warp_override : hint_range(-1.0, 1.0, 0.05) = -1.0;
uniform float color_reduction_override : hint_range(-1.0, 1.0, 0.05) = -1.0;
uniform float dither_override : hint_range(-1.0, 1.0, 0.05) = -1.0;

// Jitter resolution (lower = more wobble)
uniform float jitter_resolution : hint_range(32.0, 512.0, 8.0) = 128.0;

// ===== LIGHTING SETTINGS (Sonic Mania Style) =====
group_uniforms lighting;
uniform bool lighting_enabled = true;
uniform vec3 light_direction = vec3(0.3, -0.7, -0.5);
uniform vec3 light_color : source_color = vec3(1.0, 0.98, 0.95);
uniform float light_intensity : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform vec3 ambient_color : source_color = vec3(0.3, 0.3, 0.35);
uniform float ambient_intensity : hint_range(0.0, 1.0, 0.05) = 0.4;
uniform bool use_half_lambert = true; // Softer shading like Sonic Mania

// ===== FOG SETTINGS =====
group_uniforms fog;
uniform bool fog_enabled = false;
uniform vec3 fog_color : source_color = vec3(0.1, 0.1, 0.15);
uniform float fog_start : hint_range(0.0, 500.0) = 50.0;
uniform float fog_end : hint_range(10.0, 1000.0) = 150.0;
uniform bool height_fog_enabled = false;
uniform float height_fog_bottom : hint_range(-100.0, 100.0) = -10.0;
uniform float height_fog_top : hint_range(-100.0, 200.0) = 30.0;
uniform float height_fog_density : hint_range(0.0, 1.0) = 0.5;

// ===== APPEARANCE =====
group_uniforms appearance;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform bool use_texture = true;
uniform bool use_vertex_color = false; // Enable for vertex-colored models
uniform float vertex_color_intensity : hint_range(0.0, 1.0) = 1.0;

// Emission for glowing objects
uniform vec3 emission_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_intensity : hint_range(0.0, 5.0, 0.1) = 0.0;

// Surface properties
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// ===== VARYINGS =====
varying vec3 vertex_light;       // Gouraud lighting result
varying vec2 affine_uv;          // UV * depth for affine mapping
varying float inv_depth;          // 1/depth for affine reconstruction
varying vec4 v_color;            // Vertex color passthrough
varying float fog_factor;        // Distance fog factor
varying vec3 world_position;     // World position for height fog

void vertex() {
	// ===== GET EFFECT INTENSITIES =====
	float jitter_intensity = vertex_jitter_override >= 0.0 ? 
		vertex_jitter_override : get_jitter_from_intensity(retro_intensity);
	
	// ===== VERTEX JITTER (PS1 Fixed-Point Wobble) =====
	if (retro_enabled && jitter_intensity > 0.0) {
		// Apply jitter in clip space for view-dependent wobble
		vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		clip_pos = apply_vertex_jitter_clip(clip_pos, jitter_resolution, jitter_intensity);
		
		// Convert back to model space (approximation for visual effect)
		// This creates the characteristic PS1 vertex swimming
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 jittered_world = apply_vertex_jitter(world_pos, jitter_resolution, jitter_intensity * 0.5);
		VERTEX = (inverse(MODEL_MATRIX) * vec4(jittered_world, 1.0)).xyz;
	}
	
	// ===== AFFINE TEXTURE MAPPING PREP =====
	// Calculate depth for affine UV warping
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float depth = -view_pos.z; // Positive depth into screen
	depth = max(depth, 0.001); // Prevent division by zero
	
	// Store UV * depth for affine mapping
	affine_uv = UV * depth;
	inv_depth = 1.0 / depth;
	
	// ===== GOURAUD LIGHTING (Per-Vertex) =====
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
	
	// ===== FOG CALCULATION =====
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float distance_from_camera = length(view_pos.xyz);
	fog_factor = clamp((distance_from_camera - fog_start) / (fog_end - fog_start), 0.0, 1.0);

	// ===== CURVED WORLD =====
	// Applied last, so lighting/fog/UV varyings above are computed from the
	// true (uncurved) position and only the final geometry is bent.
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
	
	// ===== TEXTURE SAMPLING =====
	vec2 final_uv = UV;
	
	// Apply affine texture warping
	if (retro_enabled && affine_intensity > 0.0) {
		final_uv = apply_affine_mapping(affine_uv, inv_depth, UV, affine_intensity);
	}
	
	// Sample texture or use solid color
	vec3 base_color = albedo.rgb;
	if (use_texture) {
		vec4 tex_color = texture(albedo_texture, final_uv);
		base_color *= tex_color.rgb;
	}
	
	// ===== VERTEX COLOR BLENDING =====
	if (use_vertex_color) {
		base_color = mix(base_color, base_color * v_color.rgb, vertex_color_intensity);
	}
	
	// ===== APPLY GOURAUD LIGHTING =====
	vec3 lit_color = base_color * vertex_light;
	
	// ===== COLOR DEPTH REDUCTION =====
	vec3 final_color = lit_color;
	
	if (retro_enabled && color_intensity > 0.0) {
		if (dither_intensity > 0.0) {
			// Dithered color reduction (smoother gradients)
			final_color = apply_dithered_color_reduction(
				lit_color, 
				color_bits, 
				FRAGCOORD.xy, 
				dither_intensity
			);
		} else {
			// Simple color reduction (harsher banding)
			final_color = reduce_color_depth_blend(lit_color, color_bits, color_intensity);
		}
	}
	
	// ===== OUTPUT =====
	vec3 output_color = final_color;
	
	// Apply distance fog
	if (fog_enabled) {
		float final_fog = fog_factor;
		
		// Add height fog if enabled
		if (height_fog_enabled) {
			float height_factor = clamp((world_position.y - height_fog_bottom) / (height_fog_top - height_fog_bottom), 0.0, 1.0);
			height_factor = 1.0 - height_factor; // Invert so fog is denser at bottom
			final_fog = max(final_fog, height_factor * height_fog_density);
		}
		
		output_color = mix(output_color, fog_color, final_fog);
	}
	
	ALBEDO = output_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	
	// Emission
	if (emission_intensity > 0.0) {
		EMISSION = emission_color * emission_intensity;
	}
}
