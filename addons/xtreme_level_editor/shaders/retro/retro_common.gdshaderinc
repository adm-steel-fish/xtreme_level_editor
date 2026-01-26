// =============================================================================
// RETRO SHADER COMMON FUNCTIONS
// PS1/Saturn-era visual effects for Xtreme Level Editor
// =============================================================================
// This include file provides shared functions for all retro shader variants.
// Effects can be applied independently or combined based on material needs.
// 
// Design Philosophy: "Nostalgic interpretation" - capturing the aesthetic
// charm of PS1/Saturn era without slavishly replicating hardware limitations.
// Default intensity: 25-50% for playable but retro feel.
// =============================================================================

// ===== 4x4 BAYER DITHER MATRIX =====
// Used for ordered dithering (color reduction, transparency simulation)
const mat4 BAYER_MATRIX_4X4 = mat4(
	vec4( 0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0),
	vec4(12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0),
	vec4( 3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0),
	vec4(15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0)
);

// ===== 8x8 BAYER DITHER MATRIX =====
// Higher quality dithering for subtle color banding
const float BAYER_MATRIX_8X8[64] = float[64](
	 0.0/64.0, 32.0/64.0,  8.0/64.0, 40.0/64.0,  2.0/64.0, 34.0/64.0, 10.0/64.0, 42.0/64.0,
	48.0/64.0, 16.0/64.0, 56.0/64.0, 24.0/64.0, 50.0/64.0, 18.0/64.0, 58.0/64.0, 26.0/64.0,
	12.0/64.0, 44.0/64.0,  4.0/64.0, 36.0/64.0, 14.0/64.0, 46.0/64.0,  6.0/64.0, 38.0/64.0,
	60.0/64.0, 28.0/64.0, 52.0/64.0, 20.0/64.0, 62.0/64.0, 30.0/64.0, 54.0/64.0, 22.0/64.0,
	 3.0/64.0, 35.0/64.0, 11.0/64.0, 43.0/64.0,  1.0/64.0, 33.0/64.0,  9.0/64.0, 41.0/64.0,
	51.0/64.0, 19.0/64.0, 59.0/64.0, 27.0/64.0, 49.0/64.0, 17.0/64.0, 57.0/64.0, 25.0/64.0,
	15.0/64.0, 47.0/64.0,  7.0/64.0, 39.0/64.0, 13.0/64.0, 45.0/64.0,  5.0/64.0, 37.0/64.0,
	63.0/64.0, 31.0/64.0, 55.0/64.0, 23.0/64.0, 61.0/64.0, 29.0/64.0, 53.0/64.0, 21.0/64.0
);

// =============================================================================
// VERTEX JITTER (PS1 Fixed-Point Vertex Snapping)
// =============================================================================
// PS1 used fixed-point math which caused vertices to snap to a low-resolution
// grid, creating the characteristic "wobble" effect on geometry.

// Snap a vertex position to a virtual low-resolution grid
// resolution: virtual grid resolution (lower = more jitter, typical: 64-256)
// intensity: blend between original and snapped position (0.0-1.0)
vec3 apply_vertex_jitter(vec3 vertex_pos, float resolution, float intensity) {
	if (intensity <= 0.0) return vertex_pos;
	
	// Snap to grid
	vec3 snapped = floor(vertex_pos * resolution + 0.5) / resolution;
	
	// Blend between original and snapped based on intensity
	return mix(vertex_pos, snapped, intensity);
}

// Snap clip-space position for screen-space jitter effect
// This creates more authentic PS1-style jitter that's view-dependent
vec4 apply_vertex_jitter_clip(vec4 clip_pos, float resolution, float intensity) {
	if (intensity <= 0.0) return clip_pos;
	
	// Convert to NDC
	vec2 ndc = clip_pos.xy / clip_pos.w;
	
	// Snap to screen grid
	vec2 snapped_ndc = floor(ndc * resolution + 0.5) / resolution;
	
	// Blend and convert back
	vec2 final_ndc = mix(ndc, snapped_ndc, intensity);
	
	return vec4(final_ndc * clip_pos.w, clip_pos.zw);
}

// =============================================================================
// AFFINE TEXTURE MAPPING (PS1 Texture Warping)
// =============================================================================
// PS1 didn't have perspective-correct texture mapping, causing textures to
// "swim" and warp on angled surfaces.

// Calculate affine UV coordinates (removes perspective correction)
// This should be called in the vertex shader and passed as a varying
vec2 calculate_affine_uv(vec2 uv, float vertex_depth) {
	// Multiply by depth to remove perspective division later
	return uv * vertex_depth;
}

// Reconstruct UV from affine coordinates in fragment shader
// affine_uv: UV * depth from vertex shader
// inv_depth: 1.0 / depth from vertex shader
// intensity: blend between perspective-correct and affine (0.0-1.0)
vec2 apply_affine_mapping(vec2 affine_uv, float inv_depth, vec2 correct_uv, float intensity) {
	if (intensity <= 0.0) return correct_uv;
	
	// Reconstruct affine UV
	vec2 affine = affine_uv * inv_depth;
	
	// Blend between correct and affine
	return mix(correct_uv, affine, intensity);
}

// =============================================================================
// COLOR DEPTH REDUCTION (15/16-bit Color)
// =============================================================================
// PS1/Saturn used 15-bit (5-5-5) or 16-bit (5-6-5) color, creating visible
// color banding in gradients.

// Reduce color to specified bit depth per channel
// bits_per_channel: typically 5 for 15-bit, or 5-6-5 for 16-bit
vec3 reduce_color_depth(vec3 color, float bits_per_channel) {
	float levels = pow(2.0, bits_per_channel);
	return floor(color * levels + 0.5) / levels;
}

// Reduce to 15-bit color (5-5-5 RGB)
vec3 reduce_color_15bit(vec3 color) {
	float levels = 32.0; // 2^5
	return floor(color * levels + 0.5) / levels;
}

// Reduce to 16-bit color (5-6-5 RGB) - slightly more green precision
vec3 reduce_color_16bit(vec3 color) {
	vec3 levels = vec3(32.0, 64.0, 32.0); // 5-6-5
	return floor(color * levels + 0.5) / levels;
}

// Reduce with adjustable intensity (blend with original)
vec3 reduce_color_depth_blend(vec3 color, float bits_per_channel, float intensity) {
	if (intensity <= 0.0) return color;
	vec3 reduced = reduce_color_depth(color, bits_per_channel);
	return mix(color, reduced, intensity);
}

// =============================================================================
// ORDERED DITHERING
// =============================================================================
// Dithering was used to simulate more colors with limited palettes.
// Can be applied to color reduction or transparency effects.

// Get 4x4 Bayer dither threshold for current fragment
float get_dither_threshold_4x4(vec2 frag_coord) {
	ivec2 pos = ivec2(frag_coord) % 4;
	return BAYER_MATRIX_4X4[pos.y][pos.x];
}

// Get 8x8 Bayer dither threshold for current fragment
float get_dither_threshold_8x8(vec2 frag_coord) {
	ivec2 pos = ivec2(frag_coord) % 8;
	return BAYER_MATRIX_8X8[pos.y * 8 + pos.x];
}

// Apply dithered color reduction
// This adds dithering noise before quantization for smoother gradients
vec3 apply_dithered_color_reduction(vec3 color, float bits_per_channel, vec2 frag_coord, float dither_strength) {
	float threshold = get_dither_threshold_8x8(frag_coord);
	
	// Offset color by dither threshold before quantization
	float levels = pow(2.0, bits_per_channel);
	vec3 dither_offset = vec3((threshold - 0.5) * dither_strength / levels);
	
	return reduce_color_depth(color + dither_offset, bits_per_channel);
}

// =============================================================================
// GOURAUD SHADING (Per-Vertex Lighting)
// =============================================================================
// PS1/Saturn calculated lighting per-vertex and interpolated across faces,
// creating smooth but faceted shading without per-pixel calculations.

// Calculate simple directional light contribution (call in vertex shader)
// normal: vertex normal in world space
// light_dir: normalized light direction (pointing FROM light)
// light_color: light color and intensity
// ambient: ambient light color
vec3 calculate_gouraud_light(vec3 normal, vec3 light_dir, vec3 light_color, vec3 ambient) {
	float ndotl = max(dot(normal, -light_dir), 0.0);
	return ambient + light_color * ndotl;
}

// Calculate Gouraud with half-lambert for softer shadows
vec3 calculate_gouraud_half_lambert(vec3 normal, vec3 light_dir, vec3 light_color, vec3 ambient) {
	float ndotl = dot(normal, -light_dir) * 0.5 + 0.5;
	return ambient + light_color * ndotl;
}

// =============================================================================
// TEXTURE FILTERING (Point/Nearest-Neighbor)
// =============================================================================
// PS1/Saturn used point filtering, creating crisp pixelated textures.
// In Godot, this is typically set via sampler hints, but these functions
// can help with manual implementations.

// Manual point sampling with explicit texel snapping
vec4 sample_texture_point(sampler2D tex, vec2 uv, vec2 tex_size) {
	vec2 texel = floor(uv * tex_size) + 0.5;
	return texture(tex, texel / tex_size);
}

// =============================================================================
// RETRO INTENSITY PRESETS
// =============================================================================
// Helper functions to map a single "retro intensity" value (0.0-1.0)
// to individual effect parameters for easy global control.

// Get vertex jitter intensity from global retro intensity
float get_jitter_from_intensity(float retro_intensity) {
	// Jitter starts subtle and increases
	// 0% = 0.0, 25% = 0.15, 50% = 0.4, 75% = 0.6, 100% = 0.85
	return retro_intensity * retro_intensity * 0.85;
}

// Get jitter resolution from global retro intensity
float get_jitter_resolution_from_intensity(float retro_intensity) {
	// Higher intensity = lower resolution = more visible jitter
	// 0% = 256, 50% = 128, 100% = 64
	return mix(256.0, 64.0, retro_intensity);
}

// Get affine warp intensity from global retro intensity
float get_affine_from_intensity(float retro_intensity) {
	// Affine warping follows similar curve
	// 0% = 0.0, 25% = 0.2, 50% = 0.5, 75% = 0.7, 100% = 0.9
	return retro_intensity * 0.9;
}

// Get color depth bits from global retro intensity
float get_color_bits_from_intensity(float retro_intensity) {
	// 0% = 8 bits (24-bit color), 50% = 6 bits, 100% = 5 bits (15-bit)
	return mix(8.0, 5.0, retro_intensity);
}

// Get dither strength from global retro intensity
float get_dither_from_intensity(float retro_intensity) {
	// Dithering increases with intensity
	// 0% = 0.0, 50% = 0.5, 100% = 1.0
	return retro_intensity;
}

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

// Remap value from one range to another
float remap(float value, float from_min, float from_max, float to_min, float to_max) {
	return to_min + (value - from_min) * (to_max - to_min) / (from_max - from_min);
}

// Smooth cubic interpolation (alternative to smoothstep)
float smooth_cubic(float t) {
	return t * t * (3.0 - 2.0 * t);
}

// Quintic interpolation (smoother than cubic)
float smooth_quintic(float t) {
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}
