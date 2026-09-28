shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform float progress = 0.0;
uniform float side = 1.0;

void fragment() {
	float a = side > 0.0 ? UV.x : 1.0 - UV.x;
	float head = progress * 1.15;
	float trail = smoothstep(head - 0.55, head, a) * (1.0 - smoothstep(head, head + 0.05, a));
	float radial = sin(UV.y * 3.14159);
	float fade = 1.0 - smoothstep(0.7, 1.0, progress);
	float alpha = trail * radial * fade * 0.55;
	ALBEDO = vec3(0.6, 0.95, 1.0) * alpha;
	ALPHA = alpha;
}
