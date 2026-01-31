shader_type spatial;
render_mode unshaded, depth_draw_always, cull_disabled, shadows_disabled;

// =============================================================================
// BLOB SHADOW SHADER
// Simple circular shadow for PS1/Saturn-style characters
// =============================================================================

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform float shadow_softness : hint_range(0.0, 1.0) = 0.3;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	// Calculate distance from center (UV 0.5, 0.5)
	vec2 center = vec2(0.5, 0.5);
	float dist = length(UV - center) * 2.0; // 0 at center, 1 at edges
	
	// Create soft circular falloff
	float alpha = 1.0 - smoothstep(1.0 - shadow_softness, 1.0, dist);
	alpha *= shadow_strength;
	
	// Output
	ALBEDO = shadow_color.rgb;
	ALPHA = alpha * shadow_color.a;
}
