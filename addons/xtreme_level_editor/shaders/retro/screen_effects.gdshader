shader_type canvas_item;

// =============================================================================
// RETRO SCREEN EFFECTS SHADER
// Screen-space effects for transitions, flashes, and speed blur
// =============================================================================

// ===== EFFECT SELECTION =====
uniform int effect_type : hint_range(0, 5) = 0;
// 0 = None
// 1 = Flash (fade to color)
// 2 = Iris wipe (circle in/out)
// 3 = Horizontal wipe
// 4 = Vertical wipe
// 5 = Pixelate transition

// ===== COMMON PARAMETERS =====
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 effect_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool invert = false;  // Reverse the effect direction

// ===== IRIS WIPE =====
uniform vec2 iris_center = vec2(0.5, 0.5);
uniform float iris_softness : hint_range(0.0, 0.5) = 0.05;

// ===== PIXELATE =====
uniform float pixel_size : hint_range(1.0, 128.0) = 8.0;

// ===== SPEED BLUR (motion lines) =====
uniform bool speed_blur_enabled = false;
uniform float speed_blur_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float speed_blur_angle : hint_range(0.0, 6.28) = 0.0;  // Radians
uniform int speed_blur_samples : hint_range(2, 16) = 8;

void fragment() {
	vec4 screen_color = texture(TEXTURE, UV);
	vec4 final_color = screen_color;
	
	float p = invert ? 1.0 - progress : progress;
	
	// ===== EFFECT PROCESSING =====
	
	if (effect_type == 1) {
		// FLASH - Simple fade to color
		final_color = mix(screen_color, effect_color, p);
	}
	else if (effect_type == 2) {
		// IRIS WIPE - Circle transition
		float dist = distance(UV, iris_center);
		float max_dist = distance(vec2(0.0, 0.0), vec2(1.0, 1.0)) * 0.5;
		float radius = (1.0 - p) * max_dist * 1.5;
		
		float mask = smoothstep(radius - iris_softness, radius + iris_softness, dist);
		final_color = mix(screen_color, effect_color, mask);
	}
	else if (effect_type == 3) {
		// HORIZONTAL WIPE
		float mask = step(p, UV.x);
		if (invert) mask = 1.0 - mask;
		final_color = mix(effect_color, screen_color, mask);
	}
	else if (effect_type == 4) {
		// VERTICAL WIPE
		float mask = step(p, UV.y);
		if (invert) mask = 1.0 - mask;
		final_color = mix(effect_color, screen_color, mask);
	}
	else if (effect_type == 5) {
		// PIXELATE TRANSITION
		float pix = mix(1.0, pixel_size, p);
		vec2 pixelated_uv = floor(UV * vec2(textureSize(TEXTURE, 0)) / pix) * pix / vec2(textureSize(TEXTURE, 0));
		vec4 pixelated = texture(TEXTURE, pixelated_uv);
		
		// Also fade to black as pixelation increases
		final_color = mix(pixelated, effect_color, p * 0.5);
	}
	
	// ===== SPEED BLUR OVERLAY =====
	if (speed_blur_enabled && speed_blur_intensity > 0.0) {
		vec2 blur_dir = vec2(cos(speed_blur_angle), sin(speed_blur_angle));
		vec4 blur_color = vec4(0.0);
		
		float sample_step = speed_blur_intensity * 0.1 / float(speed_blur_samples);
		
		for (int i = 0; i < speed_blur_samples; i++) {
			float offset = float(i) * sample_step;
			blur_color += texture(TEXTURE, UV + blur_dir * offset);
		}
		blur_color /= float(speed_blur_samples);
		
		final_color = mix(final_color, blur_color, speed_blur_intensity * 0.5);
	}
	
	COLOR = final_color;
}
