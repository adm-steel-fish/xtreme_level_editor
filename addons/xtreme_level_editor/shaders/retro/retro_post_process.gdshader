shader_type canvas_item;

// =============================================================================
// RETRO POST-PROCESS SHADER
// Screen-space effects for PS1/Saturn aesthetic
// =============================================================================
// Applied to gameplay viewport ONLY (UI/HUD are exempt).
// This shader handles:
//   - Color banding (posterization)
//   - Optional resolution-based effects
//   - Screen-wide color adjustments
//
// Note: Resolution downscaling is handled by the viewport, not this shader.
// =============================================================================

// ===== EFFECT TOGGLES =====
group_uniforms effects;
uniform bool effects_enabled = true;
uniform float effect_intensity : hint_range(0.0, 1.0, 0.05) = 0.35;

// ===== COLOR BANDING =====
group_uniforms color_banding;
uniform bool color_banding_enabled = true;
uniform int band_levels : hint_range(8, 256, 8) = 64; // Number of color levels per channel
uniform bool use_dithering = true;
uniform float dither_strength : hint_range(0.0, 1.0, 0.05) = 0.5;

// ===== COLOR ADJUSTMENTS =====
group_uniforms color_adjustments;
uniform float saturation : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform float contrast : hint_range(0.5, 2.0, 0.05) = 1.0;
uniform float brightness : hint_range(0.5, 1.5, 0.05) = 1.0;
uniform vec3 color_tint : source_color = vec3(1.0, 1.0, 1.0);

// ===== 8x8 BAYER DITHER MATRIX =====
const float BAYER_8X8[64] = float[64](
	 0.0/64.0, 32.0/64.0,  8.0/64.0, 40.0/64.0,  2.0/64.0, 34.0/64.0, 10.0/64.0, 42.0/64.0,
	48.0/64.0, 16.0/64.0, 56.0/64.0, 24.0/64.0, 50.0/64.0, 18.0/64.0, 58.0/64.0, 26.0/64.0,
	12.0/64.0, 44.0/64.0,  4.0/64.0, 36.0/64.0, 14.0/64.0, 46.0/64.0,  6.0/64.0, 38.0/64.0,
	60.0/64.0, 28.0/64.0, 52.0/64.0, 20.0/64.0, 62.0/64.0, 30.0/64.0, 54.0/64.0, 22.0/64.0,
	 3.0/64.0, 35.0/64.0, 11.0/64.0, 43.0/64.0,  1.0/64.0, 33.0/64.0,  9.0/64.0, 41.0/64.0,
	51.0/64.0, 19.0/64.0, 59.0/64.0, 27.0/64.0, 49.0/64.0, 17.0/64.0, 57.0/64.0, 25.0/64.0,
	15.0/64.0, 47.0/64.0,  7.0/64.0, 39.0/64.0, 13.0/64.0, 45.0/64.0,  5.0/64.0, 37.0/64.0,
	63.0/64.0, 31.0/64.0, 55.0/64.0, 23.0/64.0, 61.0/64.0, 29.0/64.0, 53.0/64.0, 21.0/64.0
);


// Get dither threshold for current pixel
float get_dither_threshold(vec2 screen_pos) {
	ivec2 pos = ivec2(screen_pos) % 8;
	return BAYER_8X8[pos.y * 8 + pos.x];
}


// Apply color banding with optional dithering
vec3 apply_color_banding(vec3 color, vec2 screen_pos, int levels, bool dither, float dither_amount) {
	float flevels = float(levels);
	
	if (dither && dither_amount > 0.0) {
		// Dithered quantization - adds noise before rounding for smoother gradients
		float threshold = get_dither_threshold(screen_pos);
		vec3 dither_offset = vec3((threshold - 0.5) * dither_amount / flevels);
		color += dither_offset;
	}
	
	// Quantize to specified number of levels
	return floor(color * flevels + 0.5) / flevels;
}


// Adjust saturation
vec3 adjust_saturation(vec3 color, float sat) {
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(luminance), color, sat);
}


// Adjust contrast around middle gray
vec3 adjust_contrast(vec3 color, float cont) {
	return (color - 0.5) * cont + 0.5;
}


void fragment() {
	// Sample the screen texture
	vec4 screen_color = texture(TEXTURE, UV);
	vec3 color = screen_color.rgb;
	
	if (effects_enabled && effect_intensity > 0.0) {
		// ===== COLOR ADJUSTMENTS =====
		// Apply brightness
		color *= brightness;
		
		// Apply contrast
		if (abs(contrast - 1.0) > 0.001) {
			color = adjust_contrast(color, contrast);
		}
		
		// Apply saturation
		if (abs(saturation - 1.0) > 0.001) {
			color = adjust_saturation(color, saturation);
		}
		
		// Apply color tint
		color *= color_tint;
		
		// ===== COLOR BANDING =====
		if (color_banding_enabled) {
			// Scale band levels based on effect intensity
			int effective_levels = int(mix(256.0, float(band_levels), effect_intensity));
			float effective_dither = dither_strength * effect_intensity;
			
			color = apply_color_banding(
				color,
				FRAGCOORD.xy,
				effective_levels,
				use_dithering,
				effective_dither
			);
		}
		
		// Clamp to valid range
		color = clamp(color, vec3(0.0), vec3(1.0));
	}
	
	COLOR = vec4(color, screen_color.a);
}
