shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float strength = 0.5;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.0, 0.03, 0.02);
	ALPHA = (1.0 - smoothstep(0.35, 1.0, d)) * strength;
}
