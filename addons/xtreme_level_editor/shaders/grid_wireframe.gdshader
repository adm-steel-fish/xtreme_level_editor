shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Simple wireframe/grid visualization shader for the level editor

uniform vec4 line_color : source_color = vec4(0.3, 0.5, 1.0, 0.8);
uniform vec4 fill_color : source_color = vec4(0.2, 0.3, 0.5, 0.3);
uniform float line_width : hint_range(0.001, 0.1) = 0.02;

varying vec3 barycentric;

void vertex() {
	// Pass through vertex ID for barycentric calculation
	// This is a simplified approach - in practice you'd set barycentric coords per-vertex
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
	// Calculate wireframe from barycentric coordinates
	vec3 d = fwidth(barycentric);
	vec3 a3 = smoothstep(vec3(0.0), d * line_width * 100.0, barycentric);
	float edge_factor = min(min(a3.x, a3.y), a3.z);
	
	// Mix between line and fill color
	ALBEDO = mix(line_color.rgb, fill_color.rgb, edge_factor);
	ALPHA = mix(line_color.a, fill_color.a, edge_factor);
}
