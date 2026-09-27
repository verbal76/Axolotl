shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec3 color : source_color = vec3(0.45, 1.0, 0.7);
uniform float strength = 0.6;

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	vec4 vp = VIEW_MATRIX * vec4(wp, 1.0);
	float s = length(MODEL_MATRIX[0].xyz);
	vp.xy += VERTEX.xy * s;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float g = pow(max(0.0, 1.0 - d), 2.5);
	ALBEDO = color * g * strength;
}
