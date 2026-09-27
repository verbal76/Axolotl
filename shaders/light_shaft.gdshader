shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float strength = 0.1;
uniform vec3 color : source_color = vec3(0.8, 0.95, 0.85);

void fragment() {
	float edge = pow(max(0.0, dot(NORMAL, VIEW)), 2.0);
	float fall = smoothstep(0.0, 0.35, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float shimmer = 0.75 + 0.25 * sin(TIME * 0.7 + UV.x * 12.0);
	ALBEDO = color * edge * fall * strength * shimmer;
}
