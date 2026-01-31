shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled, shadows_disabled;

// =============================================================================
// RETRO PARTICLE SHADER
// Simple billboard particle shader with PS1/Saturn-style color reduction
// =============================================================================

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform bool use_texture = false;

uniform bool billboard_enabled = true;
uniform bool y_billboard = false;  // Only rotate around Y axis

uniform bool retro_color_enabled = true;
uniform float color_bits : hint_range(4.0, 8.0) = 5.0;

uniform bool pulse_enabled = false;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.3;

void vertex() {
	if (billboard_enabled) {
		if (y_billboard) {
			// Y-axis billboard (keeps upright)
			MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
				vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
				vec4(0.0, 1.0, 0.0, 0.0),
				vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
				MODEL_MATRIX[3]
			);
		} else {
			// Full billboard (always faces camera)
			MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
				INV_VIEW_MATRIX[0],
				INV_VIEW_MATRIX[1],
				INV_VIEW_MATRIX[2],
				MODEL_MATRIX[3]
			);
		}
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec4 color = albedo;
	
	if (use_texture) {
		color *= texture(albedo_texture, UV);
	}
	
	// Vertex color support (for GPUParticles color over lifetime)
	color *= COLOR;
	
	// Pulse effect
	if (pulse_enabled) {
		float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
		color.rgb *= 1.0 + pulse * pulse_intensity;
	}
	
	// Retro color reduction
	if (retro_color_enabled) {
		float levels = pow(2.0, color_bits);
		color.rgb = floor(color.rgb * levels) / levels;
	}
	
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
